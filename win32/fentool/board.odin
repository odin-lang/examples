package fen_tool

import fmt "core:fmt"
import strings "core:strings"

Board :: struct {
	pieces:                      Board_Pieces,
	turn_player:                 Board_Piece_Color,
	white_can_castle_kingside:   bool,
	white_can_castle_queenside:  bool,
	black_can_castle_kingside:   bool,
	black_can_castle_queenside:  bool,
	en_passant_target_square:    Square_Specifier,
	halfmove_clock:              i32,
	fullmove_number:             i32,
}

Square_Specifier :: struct {
	file: i8,
	rank: i8,
}

Board_Piece :: struct {
	type:   Board_Piece_Type,
	color:  Board_Piece_Color,
}

// Rank-major, file-minor.
// Starting position has white rook at index 0, white knight at index 1, and so on.
Board_Pieces :: distinct [64]Board_Piece

Board_Piece_Type :: enum i8 {
	none,
	rook,
	FIRST = rook,
	knight,
	bishop,
	queen,
	king,
	pawn,
	LAST = pawn,
}

Board_Piece_Color :: enum i8 {
	white,
	FIRST = white,
	black,
	LAST = black,
}

board_format_full :: proc(board: Board, allocator := context.temp_allocator) -> string {
	sb := strings.builder_make_len_cap(0, 1000, allocator)
	fmt.sbprintfln(&sb, "%v", board_format_pieces(board, allocator))
	fmt.sbprintfln(&sb, "White can castle kingside:  %v", board_format_yesno(board.white_can_castle_kingside))
	fmt.sbprintfln(&sb, "White can castle queenside: %v", board_format_yesno(board.white_can_castle_queenside))
	fmt.sbprintfln(&sb, "Black can castle kingside:  %v", board_format_yesno(board.black_can_castle_kingside))
	fmt.sbprintfln(&sb, "Black can castle queenside: %v", board_format_yesno(board.black_can_castle_queenside))
	fmt.sbprintfln(&sb, "En passant target square:   %v", board_format_en_passant_target_square(board.en_passant_target_square))
	fmt.sbprintfln(&sb, "Halfmove clock:             %v", board.halfmove_clock)
	fmt.sbprintfln(&sb, "Fullmove number:            %v", board.fullmove_number)
	return strings.to_string(sb)
}

board_format_position :: proc { board_format_position_file_rank, board_format_position_square }

board_format_position_file_rank :: proc(#any_int file: i32, #any_int rank: i32, allocator := context.temp_allocator) -> string {
	file_rune := cast(rune)('A' + file)
	rank_rune := cast(rune)('1' + rank)
	sb := strings.builder_make_len_cap(0, 4, context.temp_allocator)
	strings.write_rune(&sb, file_rune)
	strings.write_rune(&sb, rank_rune)
	return strings.to_string(sb)
}

board_format_position_square :: proc(square: Square_Specifier, allocator := context.temp_allocator) -> string {
	return board_format_position_file_rank(square.file, square.rank, allocator)
}

board_format_yesno :: proc(b: bool) -> string {
	return b ? "yes" : "no"
}

board_format_en_passant_target_square :: proc(ts: Square_Specifier, allocator := context.temp_allocator) -> string {
	if ts == {} {
		return "-"
	}
	return board_format_position(ts, allocator)
}

board_format_pieces :: proc(board: Board, allocator := context.temp_allocator) -> string {
	// Construct the string like this:
	// 8 | rnbqkbnr
	// 7 | pppppppp
	// 6 | ........
	// 5 | ........
	// 4 | ........
	// 3 | ........
	// 2 | PPPPPPPP
	// 1 | RNBQKBNR
	//   +---------
	//     ABCDEFGH
	sb := strings.builder_make_len_cap(0, 140, allocator)
	for rank := 7; rank >= 0; rank -= 1 {
		rank_name := cast(rune)('1' + rank)
		fmt.sbprintf(&sb, "%v | ", rank_name)
		for file in 0 ..< 8 {
			boardwhere := rank * 8 + file
			piece := board.pieces[boardwhere]
			r := get_piece_rune(piece)
			strings.write_rune(&sb, r)
		}
		fmt.sbprintln(&sb)
	}
	fmt.sbprintln(&sb, "  +---------")
	fmt.sbprint(&sb,   "    ABCDEFGH")
	return strings.to_string(sb)
}

get_piece_rune :: proc(piece: Board_Piece) -> rune {
	switch {
	case piece.type == .none: return '.'
	case piece == { .rook,   .white }: return 'R'
	case piece == { .knight, .white }: return 'N'
	case piece == { .bishop, .white }: return 'B'
	case piece == { .queen,  .white }: return 'Q'
	case piece == { .king,   .white }: return 'K'
	case piece == { .pawn,   .white }: return 'P'
	case piece == { .rook,   .black }: return 'r'
	case piece == { .knight, .black }: return 'n'
	case piece == { .bishop, .black }: return 'b'
	case piece == { .queen,  .black }: return 'q'
	case piece == { .king,   .black }: return 'k'
	case piece == { .pawn,   .black }: return 'p'
	case: return '?'
	}
}
