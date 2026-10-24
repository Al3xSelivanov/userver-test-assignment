#!/usr/bin/env bash
set -Eeuo pipefail

run_dir="$1"
runs="$2"
exec > >(tee -a "$run_dir/console.log") 2>&1
finish() {
    status=$?
    chown -R "${OUTPUT_UID}:${OUTPUT_GID}" "$run_dir" || true
    exit "$status"
}
trap finish EXIT

echo '[1/5] Install Clang and jq; fix sanitizer flag'
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends clang jq
for cmake_file in \
    /usr/lib/cmake/userver/debug/universal/userver-targets-universal_d.cmake \
    /usr/lib/cmake/userver/Sanitizers.cmake; do
    sed -i 's/-static-libasan/-static-libsan/g' "$cmake_file"
done

echo '[2/5] Build the Clang Build Analyzer'
cmake -S /input/vendor/ClangBuildAnalyzer -B "$run_dir/cba-build" \
    -DCMAKE_BUILD_TYPE=Release
cmake --build "$run_dir/cba-build" -j4

echo '[3/5] Generate and configure the original service'
mkdir -p "$run_dir/baseline"
(
    cd "$run_dir/baseline"
    userver-create-service --grpc --mongo --postgresql service_template
)
configure_service() {
    variant="$1"
    cmake -S "$run_dir/$variant/service_template" \
        -B "$run_dir/build-$variant" \
        -DCMAKE_CXX_COMPILER=/usr/bin/clang++ \
        -DCMAKE_CXX_FLAGS="-ftime-trace" \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
        -DUSERVER_LTO_CACHE=OFF \
        -DUSERVER_USE_CCACHE=OFF \
        -DUSERVER_COMPILATION_TIME_TRACE=ON
}
configure_service baseline
rm -f -- "$run_dir/-.json"

echo '[4/5] Measure baseline: proto repeatedly, other scenarios once'
bash /input/scripts/measure.sh "$run_dir" initial "$runs"

echo '[5/5] Apply the hypothesis and measure each scenario repeatedly'
mkdir -p "$run_dir/optimized"
cp -a "$run_dir/baseline/service_template" "$run_dir/optimized/service_template"
bash /input/scripts/make_variant.sh "$run_dir/optimized/service_template"
configure_service optimized
rm -f -- "$run_dir/-.json"
bash /input/scripts/measure.sh "$run_dir" optimized "$runs"
