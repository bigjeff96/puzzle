package puzzle

import "core:log"
import "core:math"
import "core:math/rand"

// :struct
BORDER :: -1
NONE :: 0

Piece :: [Sides]int

Sides :: enum {
    left   = 0,
    top    = 1,
    right  = 2,
    bottom = 3,
}

opposite := [Sides]Sides{
    .left   = .right,
    .top    = .bottom,
    .right  = .left,
    .bottom = .top,
}

normal := [Sides][2]int {
    .left   = {-1, 0},
    .top    = {0, 1},
    .right  = {1, 0},
    .bottom = {0, -1},
}

Puzzle :: struct {
    pieces: []Piece,
    dims:   [2]int,
    total:  int,
}

total_unique_connections_types_in_puzzle :: proc(p: Puzzle) -> int {
    // +1 for the border connection type that exists all around the border
    return 1 +
        (p.dims.x - 1) * p.dims.y + // along the x axis
        p.dims.x * (p.dims.y - 1)   // along the y axis
}

// :init :puzzle
init_square_puzzle :: proc(dim_side: int, allocator := context.allocator) -> Puzzle {
    p : Puzzle
    p.total = dim_side * dim_side
    p.dims = {dim_side, dim_side}
    pieces := make([]Piece, p.total, allocator)
    p.pieces = pieces
    info("Creation of square puzzle of dim", dim_side)

    total_connections := total_unique_connections_types_in_puzzle(p) - 1 //to remove the borders
    info("total_connections with border type:", total_connections + 1)

    for &piece, id in p.pieces {
        coords := piece_id_to_coord(p, id)
        if coords.x == 0            do piece[.left]   = BORDER
        if coords.x == p.dims.x - 1 do piece[.right]  = BORDER
        if coords.y == 0            do piece[.bottom] = BORDER
        if coords.y == p.dims.y - 1 do piece[.top]    = BORDER
    }

    for &piece, id in p.pieces {
        coords := piece_id_to_coord(p, id)
        for side in Sides do if piece[side] == NONE {
            piece[side] = total_connections
            neighbor_coords := coords + normal[side]
            neighbor_id := coord_to_id(p, neighbor_coords)
            neighbor_piece := &p.pieces[neighbor_id]
            neighbor_piece[opposite[side]] = total_connections
            total_connections -= 1
        }
    }

    info("Pieces:", p.pieces)

    return p
}



// :coords, :id
piece_id_to_coord :: proc(p: Puzzle, id: int) -> [2]int {
    y, x := math.floor_divmod(id, p.dims.y)
    return {x, y}
}

coord_to_id :: proc(p: Puzzle, coord: [2]int) -> int {
    return coord.x + p.dims.y * coord.y
}

// :using :logs
debug :: log.debug
debugf :: log.debugf
info :: log.info
infof :: log.infof
warn :: log.warn
warnf :: log.warnf

// :main
main :: proc() {
    context.logger = log.create_console_logger(opt = {.Level, .Short_File_Path, .Line, .Terminal_Color})
    defer log.destroy_console_logger(context.logger)

    p := init_square_puzzle(4)

    // fixing the seed, (seed == 0 same thing as using the current time as the seed, bad stuff dude)
    rand.reset(1)
    // lets make a "puzzle" now
    rand.shuffle(p.pieces)
    info("Pieces after shuffle:", p.pieces)
}

