# Compilation measurements

Proto ran 5 times for both variants; other scenarios ran once per variant. The main metric is
the sum of Clang `Total ExecuteCompiler` durations, excluding protoc
and linking. Parallel compiler durations are summed.

Every measurement has its own CBA report, traces and logs in a `scenario-variant-number/` folder.

| Scenario | Baseline Clang | Optimized Clang |
|---|---:|---:|
| clean (single runs) | 39.561 s | 40.417 s |
| proto (medians) | 27.284 s | 22.785 s |
| handler (single runs) | 2.715 s | 3.664 s |
| greeting (single runs) | 0.779 s | 0.878 s |
| behavior (single runs) | 3.618 s | 4.585 s |
| header (single runs) | 8.047 s | 3.655 s |

| Scenario | Variant | Run | Clang | Frontend | Backend | Compiled files |
|---|---|---:|---:|---:|---:|---|
| clean | baseline | [1](runs/clean-baseline-1/cba.txt) | 39.561 s | 35.179 s | 4.146 s | 10: greeting.cpp,hello.cpp,hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_mongo.cpp,hello_postgres.cpp,hello_service.usrv.pb.cpp,main.cpp |
| proto | baseline | [1](runs/proto-baseline-1/cba.txt) | 27.284 s | 23.333 s | 3.764 s | 6: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp,main.cpp |
| proto | baseline | [2](runs/proto-baseline-2/cba.txt) | 28.015 s | 23.765 s | 4.045 s | 6: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp,main.cpp |
| proto | baseline | [3](runs/proto-baseline-3/cba.txt) | 27.283 s | 23.059 s | 4.020 s | 6: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp,main.cpp |
| proto | baseline | [4](runs/proto-baseline-4/cba.txt) | 27.334 s | 23.108 s | 4.028 s | 6: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp,main.cpp |
| proto | baseline | [5](runs/proto-baseline-5/cba.txt) | 27.240 s | 23.058 s | 3.993 s | 6: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp,main.cpp |
| handler | baseline | [1](runs/handler-baseline-1/cba.txt) | 2.715 s | 2.551 s | 0.142 s | 1: hello_grpc.cpp |
| greeting | baseline | [1](runs/greeting-baseline-1/cba.txt) | 0.779 s | 0.739 s | 0.034 s | 1: greeting.cpp |
| behavior | baseline | [1](runs/behavior-baseline-1/cba.txt) | 3.618 s | 3.409 s | 0.181 s | 2: greeting.cpp,hello_grpc.cpp |
| header | baseline | [1](runs/header-baseline-1/cba.txt) | 8.047 s | 7.187 s | 0.781 s | 2: hello_grpc.cpp,main.cpp |
| clean | optimized | [1](runs/clean-optimized-1/cba.txt) | 40.417 s | 35.408 s | 4.782 s | 10: greeting.cpp,hello.cpp,hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_mongo.cpp,hello_postgres.cpp,hello_service.usrv.pb.cpp,main.cpp |
| proto | optimized | [1](runs/proto-optimized-1/cba.txt) | 22.785 s | 19.049 s | 3.595 s | 5: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp |
| proto | optimized | [2](runs/proto-optimized-2/cba.txt) | 21.853 s | 18.557 s | 3.159 s | 5: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp |
| proto | optimized | [3](runs/proto-optimized-3/cba.txt) | 22.055 s | 18.640 s | 3.282 s | 5: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp |
| proto | optimized | [4](runs/proto-optimized-4/cba.txt) | 26.395 s | 22.415 s | 3.819 s | 5: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp |
| proto | optimized | [5](runs/proto-optimized-5/cba.txt) | 27.270 s | 22.856 s | 4.251 s | 5: hello.grpc.pb.cc,hello.pb.cc,hello_client.usrv.pb.cpp,hello_grpc.cpp,hello_service.usrv.pb.cpp |
| handler | optimized | [1](runs/handler-optimized-1/cba.txt) | 3.664 s | 3.243 s | 0.389 s | 1: hello_grpc.cpp |
| greeting | optimized | [1](runs/greeting-optimized-1/cba.txt) | 0.878 s | 0.833 s | 0.039 s | 1: greeting.cpp |
| behavior | optimized | [1](runs/behavior-optimized-1/cba.txt) | 4.585 s | 4.122 s | 0.428 s | 2: greeting.cpp,hello_grpc.cpp |
| header | optimized | [1](runs/header-optimized-1/cba.txt) | 3.655 s | 3.249 s | 0.377 s | 1: hello_grpc.cpp |

Each measurement folder contains `cba.txt`, `cba.bin`, `build.log`, control logs, and `traces/`.
