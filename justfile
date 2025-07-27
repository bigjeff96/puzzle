
build:
    mkdir -p build
    odin build src/ -out:build/puzzle.exe -show-timings \\
                                          -debug \\
                                          -linker:lld \\
                                          -define:REAL_SHUFFLE=true \\
                                          -define:DEFAULT_TEMP_ALLOCATOR_BACKING_SIZE=1_000_000_000 \\
                                          -sanitize:address \\

run DIM: build
    ./build/puzzle.exe {{DIM}}
