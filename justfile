
build:
    mkdir -p build
    odin build src/ -out:build/puzzle.exe -show-timings -debug  -linker:lld
    ./build/puzzle.exe
