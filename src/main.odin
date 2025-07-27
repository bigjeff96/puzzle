package puzzle

import "core:os"
import "core:strconv"
import "core:log"
import "core:math"
import "core:math/rand"
import "core:math/bits"
import "core:slice"
import sa "core:container/small_array"

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
        coords := id_to_coord(p, id)
        if coords.x == 0            do piece[.left]   = BORDER
        if coords.x == p.dims.x - 1 do piece[.right]  = BORDER
        if coords.y == 0            do piece[.bottom] = BORDER
        if coords.y == p.dims.y - 1 do piece[.top]    = BORDER
    }

    for &piece, id in p.pieces {
        for side in Sides do if piece[side] == NONE {
            piece[side] = total_connections
            neighbor_piece := &p.pieces[get_neighbor_piece_id(p, id, side)]
            neighbor_piece[opposite[side]] = total_connections
            total_connections -= 1
        }
    }

    info("Pieces:", p.pieces)

    return p
}

rotate_piece_left :: proc(piece: ^Piece) {
    tmp_piece := Piece{
        .left   = piece[.top],
        .top    = piece[.right],
        .right  = piece[.bottom],
        .bottom = piece[.left],
    }
    piece^ = tmp_piece
}

rotate_piece_left_n :: #force_inline proc(piece: ^Piece, n : int) {
    for i in 0..<n do rotate_piece_left(piece)
}


// :coords, :id
id_to_coord_val :: proc(p: Puzzle, id: int) -> [2]int {
    y, x := math.floor_divmod(id, p.dims.y)
    return {x, y}
}
id_to_coord_ptr :: proc(p: ^Puzzle, id: int) -> [2]int {
    return id_to_coord_val(p^, id)
}
id_to_coord :: proc{id_to_coord_val, id_to_coord_ptr}

coord_to_id_val :: proc(p: Puzzle, coord: [2]int) -> int {
    if coord.x < 0 || coord.x >= p.dims.x ||
       coord.y < 0 || coord.y >= p.dims.y {
        return bits.I64_MAX
    }
    return coord.x + p.dims.y * coord.y
}
coord_to_id_ptr :: proc(p: ^Puzzle, coord: [2]int) -> int {
    return coord_to_id_val(p^, coord)
}
coord_to_id :: proc{coord_to_id_val, coord_to_id_ptr}

get_neighbor_piece_id :: proc(p: Puzzle, id: int, side: Sides) -> int {
    coords := id_to_coord(p, id)
    neighbor_coords := coords + normal[side]
    return coord_to_id(p, neighbor_coords)
}

solve_puzzle_v0 :: proc(p: ^Puzzle) -> bool {
    // Find the bottom left piece
    bottom_left_id := 0
    for piece, id in p.pieces {
        if piece[.left] == BORDER && piece[.bottom] == BORDER {
            bottom_left_id = id
            break
        }
    }
    slice.swap(p.pieces, bottom_left_id, 0)

    /*
    the only way to solve a puzzle is to check every new piece one at a time right?
    with a real puzzle, you can use the image to be able to group together pieces without necessarily
    checking the connection directly
    NOTES:
    - OK so the first search and me remembering the video where made an algo to solve a huge puzzle,
      You try to make bigger "pieces" out of other pieces then try again to make bigger pieces etc until
      you solve the puzzle
    - But given my case where I want a puzzle thats has two solutions, and that it would be cooler if the
      puzzle wasn't too big to hide the "magic". So since we will do dims of like 5-7, trying one piece at a
      time should work out here (hopefully)
    */
    recursive_solve :: proc(p: ^Puzzle, id_next_piece_to_find: int, id_start_of_next_pieces: int) -> bool {
        if id_next_piece_to_find == len(p.pieces) do return true

        assume(PIECES_ARE_ALREADY_IN_THE_RIGHT_ORIENTATION)
        // get the neighbor pieces that are already solved
        // and we know they are solved since their id will be smaller than id_next_piece_to_find
        coords_for_future_piece := id_to_coord(p, id_next_piece_to_find)
        sides_to_validate : bit_set[Sides]
        sides_to_connect : [Sides]int

        { //deal with the borders
            if coords_for_future_piece.x == 0            {
                sides_to_validate |= {.left}
                sides_to_connect[.left] = BORDER
            }
            if coords_for_future_piece.x == p.dims.x - 1 {
                sides_to_validate |= {.right}
                sides_to_connect[.right] = BORDER
            }
            if coords_for_future_piece.y == 0            {
                sides_to_validate |= {.bottom}
                sides_to_connect[.bottom] = BORDER
            }
            if coords_for_future_piece.y == p.dims.y - 1 {
                sides_to_validate |= {.top}
                sides_to_connect[.top] = BORDER
            }
        }

        for side in Sides do if side not_in sides_to_validate {
            neighbor_id := get_neighbor_piece_id(p^, id_next_piece_to_find, side)
            if neighbor_id < id_next_piece_to_find {
                neighbor_piece := &p.pieces[neighbor_id]
                sides_to_validate |= {side}
                sides_to_connect[side] = neighbor_piece[opposite[side]]
            }
        }

        next_piece_id := -1
        next_pieces := p.pieces[id_start_of_next_pieces:]
        for &piece, id in next_pieces {
            ok := true
            for side in Sides do if side in sides_to_validate {
                if piece[side] != sides_to_connect[side] {
                    ok = false
                    break
                }
            }
            if ok {
                next_piece_id = id_start_of_next_pieces + id
                break
            }
        }

        if next_piece_id != -1 {
            slice.swap(p.pieces, next_piece_id, id_next_piece_to_find)
            return recursive_solve(p, id_next_piece_to_find + 1, id_start_of_next_pieces + 1)
        } else {
            return false
        }
    }

    return recursive_solve(p, id_next_piece_to_find = 1, id_start_of_next_pieces = 1)
}

solve_puzzle ::proc(p: ^Puzzle) -> (bool, Puzzle) {
    // get the corner pieces
    corner_ids : sa.Small_Array(4, int)
    for piece, id in p.pieces {
        side_is_border : bit_set[Sides]
        for side in Sides do if piece[side] == BORDER {
            side_is_border |= {side}
        }
        if card(side_is_border) == 2 do sa.append(&corner_ids, id)
    }

    // for each corner piece, make a copy slice of the pieces
    solutions : [4]Puzzle
    for &solution in solutions {
        solution = p^
        solution.pieces = make([]Piece, p.total, context.temp_allocator)
        copy_slice(solution.pieces, p.pieces)
    }
    defer free_all(context.temp_allocator)


    for corner_id, id in sa.slice(&corner_ids) {
        // move corner_piece to [0,0] while also rotate it to the right place
        puzzle := solutions[id]
        slice.swap(puzzle.pieces, 0, corner_id)
        pieces := puzzle.pieces
        for pieces[0][.left] != BORDER && pieces[0][.bottom] != BORDER do rotate_piece_left(&pieces[0])
        assert(pieces[0][.left] == BORDER && pieces[0][.bottom] == BORDER)

        solved := recursive_solve(&puzzle, id_next_piece_to_find = 1, id_start_of_next_pieces = 1)
        if solved {
            solved_puzzle := solutions[id]
            solved_puzzle.pieces = make([]Piece, p.total, context.allocator)
            copy_slice(solved_puzzle.pieces, solutions[id].pieces)
            return true, solved_puzzle
        }
    }

    recursive_solve :: proc(p: ^Puzzle, id_next_piece_to_find, id_start_of_next_pieces: int) -> bool {
        if id_next_piece_to_find == len(p.pieces) do return true

        coords_for_future_piece := id_to_coord(p, id_next_piece_to_find)
        sides_to_validate : bit_set[Sides]
        sides_to_connect : [Sides]int

        { //deal with the borders
            if coords_for_future_piece.x == 0            {
                sides_to_validate |= {.left}
                sides_to_connect[.left] = BORDER
            }
            if coords_for_future_piece.x == p.dims.x - 1 {
                sides_to_validate |= {.right}
                sides_to_connect[.right] = BORDER
            }
            if coords_for_future_piece.y == 0            {
                sides_to_validate |= {.bottom}
                sides_to_connect[.bottom] = BORDER
            }
            if coords_for_future_piece.y == p.dims.y - 1 {
                sides_to_validate |= {.top}
                sides_to_connect[.top] = BORDER
            }
        }

        for side in Sides do if side not_in sides_to_validate {
            neighbor_id := get_neighbor_piece_id(p^, id_next_piece_to_find, side)
            if neighbor_id < id_next_piece_to_find {
                neighbor_piece := &p.pieces[neighbor_id]
                sides_to_validate |= {side}
                sides_to_connect[side] = neighbor_piece[opposite[side]]
            }
        }

        return false
    }

    return false, {}
}

puzzle_solved :: proc(p: Puzzle) -> bool {
    ok := true
    outer: for piece, id in p.pieces {

        coords := id_to_coord(p, id)
        if coords.x == 0            && piece[.left]   != BORDER do ok = false
        if coords.x == p.dims.x - 1 && piece[.right]  != BORDER do ok = false
        if coords.y == 0            && piece[.bottom] != BORDER do ok = false
        if coords.y == p.dims.y - 1 && piece[.top]    != BORDER do ok = false

        if !ok do break outer

        for side in Sides do if piece[side] != BORDER {
            neighbor_piece := &p.pieces[get_neighbor_piece_id(p, id, side)]
            if piece[side] != neighbor_piece[opposite[side]] {
                ok = false
                break outer
            }
        }
    }

    return ok
}

// :main
main :: proc() {
when ODIN_DEBUG
{
    context.logger = log.create_console_logger(opt = {.Level, .Short_File_Path, .Line, .Terminal_Color})
    defer log.destroy_console_logger(context.logger)
}
    dims, ok := strconv.parse_i64(os.args[1])
    assert(ok)
    p := init_square_puzzle(int(dims))
    assert(puzzle_solved(p))

    // rand.reset(1)
    // lets make a "puzzle" now
    rand.shuffle(p.pieces)
when REAL_SHUFFLE
{
    for &piece in p.pieces {
        n := rand.int_max(4)
        rotate_piece_left_n(&piece, n)

    }
}
    info("Pieces after shuffle:", p.pieces)

    solved, _ := solve_puzzle(&p)
    info("Solved?", solved)
    info("Pieces after solve:", p.pieces)
    assert(puzzle_solved(p))
}


assume :: proc($T: bool) {/*THIS IS A NOP*/}

REAL_SHUFFLE :: #config(REAL_SHUFFLE, false)
// Inspired from the better software conference talk from Andrew Reece
// Have markers in your code  (#define ASSUMPTION ) that represent the assumptions in your code
// and when you change/remove that assumption, the compiler will tell you where you'll need to revisite
PIECES_ARE_ALREADY_IN_THE_RIGHT_ORIENTATION :: true

// :using :logs
debug :: log.debug
debugf :: log.debugf
info :: log.info
infof :: log.infof
warn :: log.warn
warnf :: log.warnf
error :: log.error
errorf :: log.errorf