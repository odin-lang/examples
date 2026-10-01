package fen_tool

import runtime "base:runtime"
import log "core:log"
import fmt "core:fmt"
import strings "core:strings"
import strconv "core:strconv"
import win "core:sys/windows"

Parse_FEN_Error :: struct {
	is_error: bool,
	cursor: int,
	display_message: string,
}

// Retrieves the (possibly) localized error string with the specified ID from the embedded resource, and formats
// the error with the given arguments.
make_fen_errorf :: proc(ctx: Parse_Ctx, allocator: runtime.Allocator, string_resource_id: win.UINT, args: ..any) -> Parse_FEN_Error {
	hInstance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)
	format := load_string_resource(hInstance, string_resource_id)
	message := fmt.aprintf(format, args = args, allocator = allocator)
	return Parse_FEN_Error {
		is_error = true,
		cursor = ctx.c,
		display_message = message,
	}
}

parse_fen :: proc(s: string, allocator := context.temp_allocator) -> (board: Board, error: Parse_FEN_Error) {

	// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1

	ctx := Parse_Ctx { s = s }
	eat_spaces(&ctx)

	// rank index 0 is the "1" rank on the board.
	for rank := 7; rank >= 0; rank -= 1 {
		// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
		// ^
		// file index 0 is the "A" file on the board.
		file := 0
		rank_loop: for {
			c := cast(rune)ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
			piece: Maybe(Board_Piece)
			switch c {
			case 'r': piece = Board_Piece { .rook,   .black }
			case 'n': piece = Board_Piece { .knight, .black }
			case 'b': piece = Board_Piece { .bishop, .black }
			case 'q': piece = Board_Piece { .queen,  .black }
			case 'k': piece = Board_Piece { .king,   .black }
			case 'p': piece = Board_Piece { .pawn,   .black }
			case 'R': piece = Board_Piece { .rook,   .white }
			case 'N': piece = Board_Piece { .knight, .white }
			case 'B': piece = Board_Piece { .bishop, .white }
			case 'Q': piece = Board_Piece { .queen,  .white }
			case 'K': piece = Board_Piece { .king,   .white }
			case 'P': piece = Board_Piece { .pawn,   .white }
			case:
				if c == '/' {
					if file != 8 || rank == 0 {
						log.warnf("Rank separator '/' at invalid position: %v", board_format_position(file, rank))
						error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_RANK_SEPARATOR_AT_INVALID_POSITION_0, board_format_position(file, rank))
						return
					}
					// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
					//         ^
					ctx.c += 1
					log.debugf("Rank %v complete - next rank.", rank)
					break rank_loop
				} else if c >= '1' && c <= '8' {
					spaces := cast(int)(c - '0')
					if file + spaces > 8 {
						log.warnf("Rank overflow (cannot advance by %v empty squares): %v", spaces, board_format_position(file, rank))
						error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_RANK_OVERFLOW_ADVANCE_0_1, spaces, board_format_position(file, rank))
						return
					}
					// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
					//                   ^
					ctx.c += 1
					log.debugf("Advance %v empty squares at %v.", spaces, board_format_position(file, rank))
					file += spaces
				} else if c == ' ' {
					if file != 8 || rank != 0 {
						log.warnf("Board separator ' ' at invalid position: %v", board_format_position(file, rank))
						error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_BOARD_SEPARATOR_AT_INVALID_POSITION_0, board_format_position(file, rank))
						return
					}
					// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
					//                                            ^
					ctx.c += 1
					log.debugf("Pieces done.")
					break rank_loop
				} else {
					log.warnf("Invalid character '%v' at position: %v", c, board_format_position(file, rank))
					error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_INVALID_CHARACTER_0_AT_POSITION_1, c, board_format_position(file, rank))
					return
				}
			}

			if piece != nil {
				if file >= 8 {
					log.warnf("Rank overflow (cannot place %v %v) at %v", piece.?.color, piece.?.type, board_format_position(file, rank))
					error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_RANK_OVERFLOW_CANNOT_PLACE_0_1_AT_2, piece.?.color, piece.?.type, board_format_position(file, rank))
					return
				}
				// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
				// ^
				ctx.c += 1
				boardwhere := rank * 8 + file
				log.debugf("Placed %v %v at %v", piece.?.color, piece.?.type, board_format_position(file, rank))
				ctx.board.pieces[boardwhere] = piece.?
				file += 1
			}
		}
	}

	eat_spaces(&ctx)

	// Which player is to move?

	// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
	//                                             ^

	{
		c := cast(rune)ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
		switch c {
		case 'w':
			ctx.board.turn_player = .white
			ctx.c += 1
		case 'b':
			ctx.board.turn_player = .black
			ctx.c += 1
		case:
			log.warnf("Expected player to move (w/b), got %v", c)
			error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_EXPECTED_PLAYER_TO_MOVE_0, c)
			return
		}
	}

	// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
	//                                              ^

	{
		c := cast(rune)ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
		if c != ' ' {
			log.warnf("Expected space, got %v", c)
			error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_EXPECTED_SPACE_0, c)
			return
		}
		ctx.c += 1
	}

	eat_spaces(&ctx)

	// Castling rights

	// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
	//                                               ^

	castling_rights_loop: for {
		c := cast(rune)ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
		switch c {
		case 'K':
			if ctx.board.white_can_castle_kingside {
				log.warnf("Duplicate castling right specifier: %v", c)
				error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_DUPLICATE_CASTLING_RIGHT_SPECIFIER_0, c)
				return
			}
			ctx.board.white_can_castle_kingside = true
		case 'Q':
			if ctx.board.white_can_castle_queenside {
				log.warnf("Duplicate castling right specifier: %v", c)
				error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_DUPLICATE_CASTLING_RIGHT_SPECIFIER_0, c)
				return
			}
			ctx.board.white_can_castle_queenside = true
		case 'k':
			if ctx.board.black_can_castle_kingside {
				log.warnf("Duplicate castling right specifier: %v", c)
				error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_DUPLICATE_CASTLING_RIGHT_SPECIFIER_0, c)
				return
			}
			ctx.board.black_can_castle_kingside = true
		case 'q':
			if ctx.board.black_can_castle_queenside {
				log.warnf("Duplicate castling right specifier: %v", c)
				error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_DUPLICATE_CASTLING_RIGHT_SPECIFIER_0, c)
				return
			}
			ctx.board.black_can_castle_queenside = true
		case '-':
			// No castling rights. This is only valid
			// if no castling rights are being specified.
			// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w - - 0 1
			//                                               ^
			if ctx.board.white_can_castle_kingside ||
			   ctx.board.white_can_castle_queenside ||
			   ctx.board.black_can_castle_kingside ||
			   ctx.board.black_can_castle_queenside {
				log.warnf("Castling right specifier conflict")
				error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_CASTLING_RIGHT_SPECIFIER_CONFLICT)
				return
			}
		case ' ':
			// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
			//                                                   ^
			ctx.c += 1
			break castling_rights_loop
		case:
			log.warnf("Expected castling rights specifier, got %v", c)
			error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_EXPECTED_CASTLING_RIGHTS_SPECIFIER_0, c)
			return
		}
		ctx.c += 1
	}

	eat_spaces(&ctx)

	// En passant target square

	// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e3 0 1
	//                                                    ^

	{
		c := cast(rune)ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
		if c == '-' {
			// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
			//                                                    ^
			ctx.c += 1
		} else {
			// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e3 0 1
			//                                                    ^
			if c < 'a' || c > 'h' {
				log.warnf("Invalid en passant target square file: %v", c)
				error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_INVALID_EN_PASSANT_TARGET_SQUARE_FILE_0, c)
				return
			}
			file := c - 'a'
			ctx.c += 1

			// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq e3 0 1
			//                                                     ^

			c = cast(rune)ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
			if c != '3' && c != '6' {
				log.warnf("Invalid en passant target square rank: %v", c)
				error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_INVALID_EN_PASSANT_TARGET_SQUARE_RANK_0, c)
				return
			}
			rank := c - '1'
			ctx.c += 1
			ctx.board.en_passant_target_square = { cast(i8)file, cast(i8)rank }
		}

		// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
		//                                                     ^

		c = cast(rune)ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
		if c != ' ' {
			log.warnf("Expected space, got %v", c)
			error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_EXPECTED_SPACE_0, c)
			return
		}
		ctx.c += 1
	}

	eat_spaces(&ctx)

	// Halfmove clock

	{
		// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
		//                                                      ^
		number_string := read_number(&ctx)
		n, n_ok := strconv.parse_int(number_string, 10)
		if !n_ok {
			log.warnf("Invalid halfmove clock: %v", number_string)
			error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_INVALID_HALFMOVE_CLOCK_0, number_string)
			return
		}
		ctx.board.halfmove_clock = cast(i32)n

		// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
		//                                                       ^

		c := cast(rune)ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
		if c != ' ' {
			log.warnf("Expected space, got %v", c)
			error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_EXPECTED_SPACE_0, c)
			return
		}
		ctx.c += 1
	}

	eat_spaces(&ctx)

	// Fullmove number

	{
		// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
		//                                                        ^
		number_string := read_number(&ctx)
		n, n_ok := strconv.parse_int(number_string, 10)
		if !n_ok {
			log.warnf("Invalid fullmove number: %v", number_string)
			error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_INVALID_FULLMOVE_NUMBER_0, number_string)
			return
		}
		ctx.board.fullmove_number = cast(i32)n

		// rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1
		//                                                         ^

		eat_spaces(&ctx)
		if ctx.c < len(ctx.s) {
			log.warnf("Expected end of string")
			error = make_fen_errorf(ctx, allocator, IDS_FEN_ERR_EXPECTED_END_OF_STRING)
			return
		}
	}

	log.debugf("FEN string parsed successfully: %v", s)

	board = ctx.board
	return
}

format_fen :: proc(board: Board, allocator := context.temp_allocator) -> string {
	sb := strings.builder_make_len_cap(0, 200, allocator)

	fen_write_pieces(&sb, board.pieces)

	strings.write_string(&sb, " ")

	switch board.turn_player {
	case .white:
		strings.write_string(&sb, "w")
	case .black:
		strings.write_string(&sb, "b")
	case:
		strings.write_string(&sb, "?")
	}

	strings.write_string(&sb, " ")

	if !board.white_can_castle_kingside &&
	   !board.white_can_castle_queenside &&
	   !board.black_can_castle_kingside &&
	   !board.black_can_castle_queenside {
		strings.write_string(&sb, "-")
	} else {
		if board.white_can_castle_kingside  { strings.write_string(&sb, "K") }
		if board.white_can_castle_queenside { strings.write_string(&sb, "Q") }
		if board.black_can_castle_kingside  { strings.write_string(&sb, "k") }
		if board.black_can_castle_queenside { strings.write_string(&sb, "q") }
	}

	strings.write_string(&sb, " ")

	fen_write_en_passant_target_square(&sb, board.en_passant_target_square)

	strings.write_string(&sb, " ")

	strings.write_int(&sb, auto_cast board.halfmove_clock)

	strings.write_string(&sb, " ")

	strings.write_int(&sb, auto_cast board.fullmove_number)

	return strings.to_string(sb)
}

fen_write_pieces :: proc(sb: ^strings.Builder, pieces: Board_Pieces) {
	assert(len(pieces) == 64)

	// file index 0 is the 'A' file.
	// rank index 0 is the '1' rank.
	for rank := 7; rank >= 0; rank -= 1 {

		file := 0

		file_loop: for {
			if file == 8 {
				break file_loop
			}
			assert(file < 8)
			p := pieces[rank * 8 + file]
			if p.type == .none {
				// Consolidate consecutive empty squares within a rank.
				num_consecutive_empty_squares: int
				for file < 8 && pieces[rank * 8 + file].type == .none {
					num_consecutive_empty_squares += 1
					file += 1
				}
				assert(num_consecutive_empty_squares > 0)
				assert(num_consecutive_empty_squares <= 8)
				strings.write_rune(sb, cast(rune)('0' + num_consecutive_empty_squares))
			} else {
				switch {
				case p == { .rook,   .white }: strings.write_rune(sb, 'R')
				case p == { .knight, .white }: strings.write_rune(sb, 'N')
				case p == { .bishop, .white }: strings.write_rune(sb, 'B')
				case p == { .queen,  .white }: strings.write_rune(sb, 'Q')
				case p == { .king,   .white }: strings.write_rune(sb, 'K')
				case p == { .pawn,   .white }: strings.write_rune(sb, 'P')
				case p == { .rook,   .black }: strings.write_rune(sb, 'r')
				case p == { .knight, .black }: strings.write_rune(sb, 'n')
				case p == { .bishop, .black }: strings.write_rune(sb, 'b')
				case p == { .queen,  .black }: strings.write_rune(sb, 'q')
				case p == { .king,   .black }: strings.write_rune(sb, 'k')
				case p == { .pawn,   .black }: strings.write_rune(sb, 'p')
				case:                          strings.write_rune(sb, '?')
				}
				file += 1
			}
		}

		assert(file == 8)

		if rank != 0 {
			strings.write_rune(sb, '/')
		}
	}
}

fen_write_en_passant_target_square :: proc(sb: ^strings.Builder, square: Square_Specifier) {
	if square == {} {
		// NOTE: This works because (0, 0) is never a valid en passant square.
		strings.write_string(sb, "-")
	} else {
		if square.file < 0 || square.file >= 8 {
			strings.write_string(sb, "?")
		} else {
			strings.write_rune(sb, cast(rune)('a' + square.file))
		}

		if square.rank < 0 || square.rank >= 8 {
			strings.write_string(sb, "?")
		} else {
			strings.write_rune(sb, cast(rune)('1' + square.rank))
		}
	}
}

@(private="file")
Parse_Ctx :: struct {
	s: string,
	c: int,
	board: Board,
}

@(private="file")
eat_spaces :: proc(ctx: ^Parse_Ctx) {
	for ctx.c < len(ctx.s) && strings.is_ascii_space(cast(rune)ctx.s[ctx.c]) {
		ctx.c += 1
	}
}

@(private="file")
read_number :: proc(ctx: ^Parse_Ctx) -> string {
	start := ctx.c
	for {
		c := ctx.s[ctx.c] if ctx.c < len(ctx.s) else 0
		if c >= '0' && c <= '9' {
			ctx.c += 1
		} else {
			break
		}
	}
	return ctx.s[start:ctx.c]
}
