#!/usr/bin/env bash
set -Eeuo pipefail

# This is a copy of the generated service; the baseline remains untouched.
service="$1"
main="$service/src/main.cpp"
grpc="$service/src/hello_grpc.cpp"

grep -Fq '#include <hello_grpc.hpp>' "$main"
grep -Fq '.Append<service_template::HelloGrpc>()' "$main"

# main.cpp now knows only a small registration function, not the generated
# gRPC service class. The function is called at the same place in the list.
sed -i 's|#include <hello_grpc.hpp>|#include <hello_grpc_registration.hpp>|' "$main"
sed -i '/\.Append<service_template::HelloGrpc>()/d' "$main"
sed -i '/return userver::utils::DaemonMain/i\    service_template::AppendHelloGrpc(component_list);' "$main"

cat > "$service/src/hello_grpc_registration.hpp" <<'EOF'
#pragma once
#include <userver/components/component_list.hpp>

namespace service_template {
void AppendHelloGrpc(userver::components::ComponentList& component_list);
}
EOF

sed -i '1a #include <hello_grpc_registration.hpp>' "$grpc"
cat >> "$grpc" <<'EOF'

namespace service_template {
void AppendHelloGrpc(userver::components::ComponentList& component_list) {
    component_list.Append<HelloGrpc>();
}
}
EOF
