#!/usr/bin/env bash
set -Eeuo pipefail

run_dir="$1"
phase="$2"
runs="${3:-}"
cba="$run_dir/cba-build/ClangBuildAnalyzer"
table="$run_dir/measurements.tsv"
if [[ "$phase" == initial ]]; then
    mkdir -p "$run_dir/runs"
    printf 'scenario\tvariant\trun\tclang_s\tfrontend_s\tbackend_s\tfiles_count\tfiles\n' > "$table"
elif [[ "$phase" != optimized ]]; then
    echo 'Usage: measure.sh RUN_DIR initial|optimized RUNS' >&2
    exit 2
fi
if [[ ! "$runs" =~ ^[1-9][0-9]*$ ]]; then
    echo 'RUNS must be a positive integer' >&2
    exit 2
fi

# CMake may leave traces from earlier builds. Keep only JSON files produced by
# the build we are about to measure.
clear_traces() {
    local build="$1"
    find "$build/CMakeFiles" -type f \( -name '*.cpp.json' -o -name '*.cc.json' \) -delete
}

# Read Clang's three summary events from the new JSON traces. jq reports
# microseconds; division by 1,000,000 gives seconds. The raw JSON is saved too.
collect_traces() {
    local build="$1" destination="$2"
    local -a traces
    mkdir -p "$destination"
    mapfile -d '' traces < <(find "$build/CMakeFiles" -type f \
        \( -name '*.cpp.json' -o -name '*.cc.json' \) -print0)
    ((${#traces[@]} > 0)) || { echo "No Clang traces in $build" >&2; return 1; }
    cp -- "${traces[@]}" "$destination/"

    files_count="${#traces[@]}"
    files="$(printf '%s\n' "${traces[@]##*/}" | sed 's/\.json$//' | sort | paste -sd, -)"
    clang_s="$(jq -s '([.[].traceEvents[] | select(.name == "Total ExecuteCompiler") | .dur] | add) / 1000000' "${traces[@]}")"
    frontend_s="$(jq -s '([.[].traceEvents[] | select(.name == "Total Frontend") | .dur] | add) / 1000000' "${traces[@]}")"
    backend_s="$(jq -s '([.[].traceEvents[] | select(.name == "Total Backend") | .dur] | add) / 1000000' "${traces[@]}")"
}

measure_one() {
    local scenario="$1" variant="$2" number="$3"
    local source="$run_dir/$variant/service_template"
    local build="$run_dir/build-$variant"
    local folder="$run_dir/runs/$scenario-$variant-$number"
    local target=service_template
    local -a changed_files=()
    mkdir -p "$folder"

    case "$scenario" in
        clean)
            if [[ "$variant" == optimized || "$number" != 1 ]]; then
                cmake --build "$build" --target clean > "$folder/prepare.log" 2>&1
            fi
            ;;
        proto)
            changed_files+=("$source/proto/handlers/hello.proto")
            ;;
        handler)
            target=service_template_objs
            changed_files+=("$source/src/hello_grpc.cpp")
            ;;
        greeting)
            target=service_template_objs
            changed_files+=("$source/src/greeting.cpp")
            ;;
        behavior)
            target=service_template_objs
            changed_files+=("$source/src/hello_grpc.cpp" "$source/src/greeting.cpp")
            ;;
        header)
            changed_files+=("$source/src/hello_grpc.hpp")
            ;;
    esac
    local i
    for i in "${!changed_files[@]}"; do
        cp "${changed_files[$i]}" "$folder/original-source-$i"
    done
    if [[ "$target" == service_template_objs ]]; then
        cmake --build "$build" -j4 --target "$target" > "$folder/prepare.log" 2>&1
    fi

    clear_traces "$build"
    "$cba" --start "$build" > "$folder/cba-control.log" 2>&1
    if [[ "$scenario" == proto ]]; then
        # A real protobuf contract change, compatible with existing code.
        sed -i '/string text = 1;/a\    string note = 2;' "${changed_files[0]}"
    elif [[ "$scenario" == handler || "$scenario" == behavior ]]; then
        sed -i 's/UserType::kFirstTime/UserType::kKnown/' "${changed_files[0]}"
    fi
    if [[ "$scenario" == greeting ]]; then
        sed -i 's/Hello, {}!/Greetings, {}!/' "${changed_files[0]}"
    elif [[ "$scenario" == behavior ]]; then
        sed -i 's/Hi again, {}!/Welcome back, {}!/' "${changed_files[1]}"
    elif [[ "$scenario" == header ]]; then
        sed -i '/static constexpr std::string_view kName = /a\    static constexpr bool kStudyMarker = true;' "${changed_files[0]}"
    fi

    cmake --build "$build" -j4 --target "$target" --verbose > "$folder/build.log" 2>&1
    "$cba" --stop "$build" "$folder/cba.bin" >> "$folder/cba-control.log" 2>&1
    "$cba" --analyze "$folder/cba.bin" > "$folder/cba.txt"
    collect_traces "$build" "$folder/traces"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$scenario" "$variant" "$number" "$clang_s" "$frontend_s" \
        "$backend_s" "$files_count" "$files" >> "$table"
    printf '%s %s #%s: %.3f s Clang, %s files\n' \
        "$scenario" "$variant" "$number" "$clang_s" "$files_count"

    if ((${#changed_files[@]} > 0)); then
        for i in "${!changed_files[@]}"; do
            cp "$folder/original-source-$i" "${changed_files[$i]}"
        done
        cmake --build "$build" -j4 --target "$target" > "$folder/restore.log" 2>&1
    fi
}

if [[ "$phase" == initial ]]; then
    for scenario in clean proto handler greeting behavior header; do
        scenario_runs=1
        [[ "$scenario" == proto ]] && scenario_runs="$runs"
        for ((number=1; number<=scenario_runs; number++)); do
            measure_one "$scenario" baseline "$number"
        done
    done
    exit 0
fi

for scenario in clean proto handler greeting behavior header; do
    scenario_runs=1
    [[ "$scenario" == proto ]] && scenario_runs="$runs"
    for ((number=1; number<=scenario_runs; number++)); do
        measure_one "$scenario" optimized "$number"
    done
done

median() {
    local scenario="$1" variant="$2"
    awk -F '\t' -v s="$scenario" -v v="$variant" \
        'NR>1 && $1==s && $2==v {print $4}' "$table" | sort -n |
        awk '{value[NR]=$1} END {if (NR%2) print value[(NR+1)/2]; else print (value[NR/2]+value[NR/2+1])/2}'
}

{
    echo '# Compilation measurements'
    echo
    echo "Proto ran $runs times for both variants; other scenarios ran once per variant. The main metric is"
    echo 'the sum of Clang `Total ExecuteCompiler` durations, excluding protoc'
    echo 'and linking. Parallel compiler durations are summed.'
    echo
    echo 'Every measurement has its own CBA report, traces and logs in a `scenario-variant-number/` folder.'
    echo
    echo '| Scenario | Baseline Clang | Optimized Clang |'
    echo '|---|---:|---:|'
    for scenario in clean proto handler greeting behavior header; do
        if [[ "$scenario" == proto ]]; then
            label='proto (medians)'
        else
            label="$scenario (single runs)"
        fi
        printf '| %s | %.3f s | %.3f s |\n' "$label" \
            "$(median "$scenario" baseline)" "$(median "$scenario" optimized)"
    done
    echo
    echo '| Scenario | Variant | Run | Clang | Frontend | Backend | Compiled files |'
    echo '|---|---|---:|---:|---:|---:|---|'
    while IFS=$'\t' read -r scenario variant number clang front back count files; do
        [[ "$scenario" == scenario ]] && continue
        printf '| %s | %s | [%s](runs/%s-%s-%s/cba.txt) | %.3f s | %.3f s | %.3f s | %s: %s |\n' \
            "$scenario" "$variant" "$number" "$scenario" "$variant" "$number" \
            "$clang" "$front" "$back" "$count" "$files"
    done < "$table"
    echo
    echo 'Each measurement folder contains `cba.txt`, `cba.bin`, `build.log`, control logs, and `traces/`.'
} > "$run_dir/summary.md"

echo "Finished: $run_dir/summary.md"
