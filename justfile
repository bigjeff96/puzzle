
build:
    mkdir -p build
    odin build src/ -out:build/puzzle.exe -show-timings -debug -linker:lld -define:REAL_SHUFFLE=false

run DIM: build
    ./build/puzzle.exe {{DIM}}
