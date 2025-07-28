
build:
    mkdir -p build
    odin build src/ -out:build/puzzle.exe -show-timings \
                                          -debug \
                                          -o:speed \
                                          -linker:lld \
                                          -define:DEFAULT_TEMP_ALLOCATOR_BACKING_SIZE=4_000_000_000 \

run DIM: build
    ./build/puzzle.exe {{DIM}}
