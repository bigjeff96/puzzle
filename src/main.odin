package puzzle

import "core:os"
import "core:strconv"
import "core:log"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:math/bits"
import "core:slice"
import sa "core:container/small_array"
import "core:time"

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

normal := [Sides][2]int{
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
           p.dims.x * (p.dims.y - 1) + // along the y axis
           (p.dims.x - 1) * p.dims.y   // along the x axis
}

// :init :puzzle
init_square_puzzle_single_solution :: proc(dim_side: int, allocator := context.allocator) -> Puzzle {
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

copy_puzzle :: proc(p: Puzzle, allocator := context.allocator) -> Puzzle {
    res: Puzzle
    res = p
    res.pieces = make([]Piece, p.total, allocator)
    copy_slice(res.pieces, p.pieces)
    return res
}

contraints_for_piece_id :: proc(p: Puzzle, id: int) -> (sides_to_validate: bit_set[Sides],
                                                        sides_to_connect: [Sides]int) {

    coords_for_future_piece := id_to_coord(p, id)
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
        neighbor_id := get_neighbor_piece_id(p, id, side)
        if neighbor_id < id {
            neighbor_piece := &p.pieces[neighbor_id]
            sides_to_validate |= {side}
            sides_to_connect[side] = neighbor_piece[opposite[side]]
        }
    }

    return
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

when false
{
    for corner_id, id in sa.slice(&corner_ids) {
        // move corner_piece to [0,0] while also rotate it to the right place
        puzzle := solutions[id]
        slice.swap(puzzle.pieces, 0, corner_id)
        pieces := puzzle.pieces
        for pieces[0][.left] != BORDER || pieces[0][.bottom] != BORDER do rotate_piece_left(&pieces[0])
        assert(pieces[0][.left] == BORDER && pieces[0][.bottom] == BORDER)
        solved, solution := recursive_solve(&puzzle, id_next_piece_to_find = 1, id_start_of_next_pieces = 1)
        if solved {
            solved_puzzle := solutions[id]
            solved_puzzle.pieces = make([]Piece, p.total, context.allocator)
            copy_slice(solved_puzzle.pieces, solution)
            return true, solved_puzzle
        }
    }
}
else
{
    Args :: struct {
        puzzle: Puzzle,
        id_next_piece_to_find: int,
        id_start_of_next_pieces: int,
    }
    args_stack := make([dynamic]Args, len=0, cap=500)
    defer delete(args_stack)

    for corner_id, id in sa.slice(&corner_ids) {
        puzzle := solutions[id]
        slice.swap(puzzle.pieces, 0, corner_id)
        pieces := puzzle.pieces
        for pieces[0][.left] != BORDER || pieces[0][.bottom] != BORDER do rotate_piece_left(&pieces[0])
        assert(pieces[0][.left] == BORDER && pieces[0][.bottom] == BORDER)
        append(&args_stack, Args{puzzle = puzzle, id_next_piece_to_find = 1, id_start_of_next_pieces = 1})

        stack: for len(args_stack) > 0 {
            args := pop(&args_stack)
            p := args.puzzle
            id_next_piece_to_find := args.id_next_piece_to_find
            id_start_of_next_pieces := args.id_start_of_next_pieces

            if id_next_piece_to_find == len(p.pieces) {
                solved_puzzle := p
                solved_puzzle.pieces = make([]Piece, p.total, context.allocator)
                copy_slice(solved_puzzle.pieces, p.pieces)
               return true, solved_puzzle
            }

            next_pieces := p.pieces[id_start_of_next_pieces:]
            sides_to_validate, sides_to_connect := contraints_for_piece_id(p, id_next_piece_to_find)

            for &piece, id in next_pieces {
                big_ok := false
                outer: for _ in 0..<4 {
                    rotate_piece_left(&piece)
                    ok := true
                    for side in Sides do if side in sides_to_validate {
                        if piece[side] != sides_to_connect[side] {
                            ok = false
                            break
                        }
                    }
                    if ok {
                        big_ok = true
                        break outer
                    }
                }

                if big_ok {
                    // copied_puzzle := copy_puzzle(p, context.temp_allocator)
                    copied_puzzle := p
                    slice.swap(copied_puzzle.pieces, id + id_start_of_next_pieces, id_next_piece_to_find)
                    new_args := Args{copied_puzzle, id_next_piece_to_find + 1, id_start_of_next_pieces}
                    append(&args_stack, new_args)
                    continue stack
                }

            }
        }

        clear(&args_stack)
    }
}

    recursive_solve :: proc(p: ^Puzzle, id_next_piece_to_find, id_start_of_next_pieces: int) -> (bool, []Piece) {
        if id_next_piece_to_find == len(p.pieces) do return true, p.pieces

        next_pieces := p.pieces[id_start_of_next_pieces:]
        sides_to_validate, sides_to_connect := contraints_for_piece_id(p^, id_next_piece_to_find)

        for &piece, id in next_pieces {
            big_ok := false
            outer: for _ in 0..<4 {
                rotate_piece_left(&piece)
                ok := true
                for side in Sides do if side in sides_to_validate {
                    if piece[side] != sides_to_connect[side] {
                        ok = false
                        break
                    }
                }
                if ok {
                    big_ok = true
                    break outer
                }
            }

            if big_ok {
                copied_puzzle := copy_puzzle(p^, context.temp_allocator)
                slice.swap(copied_puzzle.pieces, id + id_start_of_next_pieces, id_next_piece_to_find)
                solved, solution := recursive_solve(&copied_puzzle,
                                                    id_next_piece_to_find + 1,
                                                    id_start_of_next_pieces + 1)

                if solved do return true, solution
            }

        }

        return false, {}
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

when LOG
{
    context.logger = log.create_console_logger(opt = {.Level, .Short_File_Path, .Line})
    defer log.destroy_console_logger(context.logger)
}

when MEASURE_EXECUTABLE
{
    timer : time.Stopwatch
    time.stopwatch_start(&timer)
    defer {
        time.stopwatch_stop(&timer)
        fmt.println("runtime duration:", time.stopwatch_duration(timer))
    }
}
    dims, ok := strconv.parse_i64(os.args[1])
    assert(ok)
    p := init_square_puzzle_single_solution(int(dims))
    defer delete(p.pieces)
    assert(puzzle_solved(p))

    // rand.reset(1)
    // lets make a "puzzle" now
    rand.shuffle(p.pieces)
    for &piece in p.pieces {
        n := rand.int_max(4) // 0..=3
        rotate_piece_left_n(&piece, n)
    }
    info("Pieces after shuffle:", p.pieces)

    solved, solved_puzzle := solve_puzzle(&p)
    defer delete(solved_puzzle.pieces)
    info("Solved?", solved)
    info("Pieces after solve:", solved_puzzle.pieces)
    assert(puzzle_solved(solved_puzzle))
}

MEASURE_EXECUTABLE :: #config(MEASURE_EXECUTABLE, true)
LOG :: #config(LOG, false)

// :using :logs
debug :: log.debug
debugf :: log.debugf
info :: log.info
infof :: log.infof
warn :: log.warn
warnf :: log.warnf
error :: log.error
errorf :: log.errorf