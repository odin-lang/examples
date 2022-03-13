package main


/*******************************************************************************************
*
*   raylib - classic game: tetroid
*
*   Sample game developed by Marc Palau and Ramon Santamaria
*
*   This game has been created using raylib v1.3 (www.raylib.com)
*   raylib is licensed under an unmodified zlib/libpng license (View raylib.h for details)
*
*  Translation from https://github.com/raysan5/raylib-games/blob/master/classics/src/tetris.c to Odin
*
*   Copyright (c) 2015 Ramon Santamaria (@raysan5)
*   Copyright (c) 2021 Ginger Bill
*
********************************************************************************************/



import rl "vendor:raylib"

SQUARE_SIZE             :: 20

GRID_HORIZONTAL_SIZE    :: 12
GRID_VERTICAL_SIZE      :: 20

LATERAL_SPEED           :: 10
TURNING_SPEED           :: 12
FAST_FALL_AWAIT_COUNTER :: 30

FADING_TIME             :: 33

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

Grid_Square :: enum u8 {
	Empty,
	Moving,
	Full,
	Block,
	Fading,
}

game_over := false
pause := false

grid:           [GRID_HORIZONTAL_SIZE][GRID_VERTICAL_SIZE]Grid_Square
piece:          [4][4]Grid_Square
incoming_piece: [4][4]Grid_Square

piece_position: [2]i32

fading_color: rl.Color

begin_play := true
piece_active := false
detection := false
line_to_delete := false

level := 1
lines := 0

gravity_movement_counter := 0
lateral_movement_counter := 0
turn_movement_counter := 0
fast_fall_movement_counter := 0

fade_line_counter := 0

inverse_gravity_speed := 30



main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tetroid")
	defer rl.CloseWindow()   
	
	init_game()

	rl.SetTargetFPS(60)      

	for !rl.WindowShouldClose() { // Detect window close button or ESC key
		update_game()
		draw_game()
	}
}


init_game :: proc() {
	level = 1
	lines = 0

	fading_color = rl.GRAY

	piece_position = {0, 0}

	pause = false

	begin_play     = true
	piece_active   = false
	detection      = false
	line_to_delete = false

	// Counters
	gravity_movement_counter = 0
	lateral_movement_counter = 0
	turn_movement_counter = 0
	fast_fall_movement_counter = 0

	fade_line_counter = 0
	inverse_gravity_speed = 30

	grid = {}
	incoming_piece = {}

	// Initialize grid matrices
	for i in 0..<GRID_HORIZONTAL_SIZE {
		for j in 0..<GRID_VERTICAL_SIZE {
			switch {
			case j == GRID_VERTICAL_SIZE - 1,
			     i == GRID_HORIZONTAL_SIZE - 1,
			     i == 0:
				grid[i][j] = .Block
			}
		}
	}
}

update_game :: proc() {
	if game_over {
		if rl.IsKeyPressed(.ENTER) {
			init_game()
			game_over = false
		}
		return
	}
	
	if rl.IsKeyPressed(.P) {
		pause = !pause
	}
	
	if pause {
		return
	}
	
	if line_to_delete {
		fade_line_counter += 1
		
		if fade_line_counter % 8 < 4 {
			fading_color = rl.MAROON
		} else {
			fading_color = rl.GRAY
		}
		
		if fade_line_counter >= FADING_TIME {
			delete_complete_lines()
			fade_line_counter = 0
			line_to_delete = false
			
			lines += 1
		}
		return
	}
	
	
	if !piece_active {
		piece_active = create_piece()
		fast_fall_movement_counter = 0
	} else {
		fast_fall_movement_counter += 1
		gravity_movement_counter   += 1
		lateral_movement_counter   += 1
		turn_movement_counter      += 1
		
		// We make sure to move if we've pressed the key this frame
		if rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.RIGHT) {
			lateral_movement_counter = LATERAL_SPEED
		}
		if rl.IsKeyPressed(.UP) {
			turn_movement_counter = TURNING_SPEED
		}
		
		// Fall down
		if rl.IsKeyDown(.DOWN) && fast_fall_movement_counter >= FAST_FALL_AWAIT_COUNTER {
			// We make sure the piece is going to fall this frame
			gravity_movement_counter += inverse_gravity_speed
		}

		if gravity_movement_counter >= inverse_gravity_speed {
			// Basic falling movement
			check_detection(&detection)

			// Check if the piece has collided with another piece or with the boundings
			resolve_falling_movement(&detection, &piece_active)

			// Check if we fullfilled a line and if so, erase the line and pull down the the lines above
			check_completion(&line_to_delete)

			gravity_movement_counter = 0
		}

		// Move laterally at player's will
		if lateral_movement_counter >= LATERAL_SPEED {
			// Update the lateral movement and if success, reset the lateral counter
			if !resolve_lateral_movement() {
				lateral_movement_counter = 0
			}
		}

		// Turn the piece at player's will
		if turn_movement_counter >= TURNING_SPEED {
			// Update the turning movement and reset the turning counter
			if resolve_turn_movement() {
				turn_movement_counter = 0
			}
		}
		
		for j in 0..<2 {
			for i in 1..<GRID_HORIZONTAL_SIZE-1 {
				if grid[i][j] == .Full {
					game_over = true
				}
			}
		}
	}
}

draw_game :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()
	
	rl.ClearBackground(rl.RAYWHITE)
	
	if game_over {
		text :: "PRESS [ENTER] TO PLAY AGAIN"
		rl.DrawText(text, rl.GetScreenWidth()/2 - rl.MeasureText(text, 20)/2, rl.GetScreenHeight()/2 - 50, 20, rl.GRAY)
		return
	}
	
	offset := [2]i32{
		SCREEN_WIDTH/2 - (GRID_HORIZONTAL_SIZE*SQUARE_SIZE/2) - 50,
		SCREEN_HEIGHT/2 - ((GRID_VERTICAL_SIZE-1)*SQUARE_SIZE/2) + SQUARE_SIZE*2,
	}
	
	offset.y -= 50
	
	controller := offset.x
	
	for j in 0..<GRID_VERTICAL_SIZE {
		for i in 0..<GRID_HORIZONTAL_SIZE {
			switch grid[i][j] {
			case .Empty:
				rl.DrawLine(offset.x, offset.y, offset.x + SQUARE_SIZE, offset.y, rl.LIGHTGRAY)
				rl.DrawLine(offset.x, offset.y, offset.x, offset.y + SQUARE_SIZE, rl.LIGHTGRAY)
				rl.DrawLine(offset.x + SQUARE_SIZE, offset.y, offset.x + SQUARE_SIZE, offset.y + SQUARE_SIZE, rl.LIGHTGRAY)
				rl.DrawLine(offset.x, offset.y + SQUARE_SIZE, offset.x + SQUARE_SIZE, offset.y + SQUARE_SIZE, rl.LIGHTGRAY)
			case .Full:
				rl.DrawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, rl.GRAY)
			case .Moving:
				rl.DrawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, rl.DARKGRAY)
			case .Block:
				rl.DrawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, rl.LIGHTGRAY)
			case .Fading:
				rl.DrawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, fading_color)
			}
			offset.x += SQUARE_SIZE
		}
		
		offset.x = controller
		offset.y += SQUARE_SIZE
	}
	
	offset = {500, 45}
	
	controller = offset.x
	
	for j in 0..<4 {
		for i in 0..<4 {
			#partial switch incoming_piece[i][j] {
			case .Empty:
				rl.DrawLine(offset.x, offset.y, offset.x + SQUARE_SIZE, offset.y, rl.LIGHTGRAY)
				rl.DrawLine(offset.x, offset.y, offset.x, offset.y + SQUARE_SIZE, rl.LIGHTGRAY)
				rl.DrawLine(offset.x + SQUARE_SIZE, offset.y, offset.x + SQUARE_SIZE, offset.y + SQUARE_SIZE, rl.LIGHTGRAY)
				rl.DrawLine(offset.x, offset.y + SQUARE_SIZE, offset.x + SQUARE_SIZE, offset.y + SQUARE_SIZE, rl.LIGHTGRAY)
				offset.x += SQUARE_SIZE
			case .Moving:
				rl.DrawRectangle(offset.x, offset.y, SQUARE_SIZE, SQUARE_SIZE, rl.GRAY)
				offset.x += SQUARE_SIZE
			}
		}
		
		offset.x = controller
		offset.y += SQUARE_SIZE
	}
	
	rl.DrawText("INCOMING:", offset.x, offset.y - 100, 10, rl.GRAY)
	rl.DrawText(rl.TextFormat("LINES:      %04i", lines), offset.x, offset.y + 20, 10, rl.GRAY)
	
	if pause {
		text :: "GAME PAUSED"
		rl.DrawText(text, SCREEN_WIDTH/2 - rl.MeasureText(text, 40)/2, SCREEN_WIDTH/2 - 40, 40, rl.GRAY)
	}
}


create_piece :: proc() -> bool {
	piece_position.x = (GRID_HORIZONTAL_SIZE - 4)/2
	piece_position.y = 0

	// If the game is starting and you are going to create the first piece, we create an extra one
	if (begin_play) {
		get_random_piece()
		begin_play = false
	}

	// We assign the incoming piece to the actual piece
	piece = incoming_piece

	// We assign a random piece to the incoming one
	get_random_piece()

	// Assign the piece to the grid
	for i in piece_position.x ..< piece_position.x+4 {
		for j in 0 ..< 4 {
			if piece[i - piece_position.x][j] == .Moving {
				grid[i][j] = .Moving
			}
		}
	}

	return true
}

get_random_piece :: proc() {
	random := rl.GetRandomValue(0, 6)
	
	incoming_piece = {}
	
	switch random {
	case 0: incoming_piece[1][1] = .Moving; incoming_piece[2][1] = .Moving; incoming_piece[1][2] = .Moving; incoming_piece[2][2] = .Moving //Cube
	case 1: incoming_piece[1][0] = .Moving; incoming_piece[1][1] = .Moving; incoming_piece[1][2] = .Moving; incoming_piece[2][2] = .Moving //L
	case 2: incoming_piece[1][2] = .Moving; incoming_piece[2][0] = .Moving; incoming_piece[2][1] = .Moving; incoming_piece[2][2] = .Moving //L inversa
	case 3: incoming_piece[0][1] = .Moving; incoming_piece[1][1] = .Moving; incoming_piece[2][1] = .Moving; incoming_piece[3][1] = .Moving //Recta
	case 4: incoming_piece[1][0] = .Moving; incoming_piece[1][1] = .Moving; incoming_piece[1][2] = .Moving; incoming_piece[2][1] = .Moving //Creu tallada
	case 5: incoming_piece[1][1] = .Moving; incoming_piece[2][1] = .Moving; incoming_piece[2][2] = .Moving; incoming_piece[3][2] = .Moving //S
	case 6: incoming_piece[1][2] = .Moving; incoming_piece[2][2] = .Moving; incoming_piece[2][1] = .Moving; incoming_piece[3][1] = .Moving //S inversa
	}
}



delete_complete_lines :: proc() {
	for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
		for grid[1][j] == .Fading {
			for i := 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
				grid[i][j] = .Empty
			}
			
			for j2 := j-1; j2 >= 0; j2 -= 1 {
				for i2 := 1; i2 < GRID_HORIZONTAL_SIZE-1; i2 += 1 {
					#partial switch grid[i2][j2] {
					case .Full:
						grid[i2][j2+1] = .Full
						grid[i2][j2] = .Empty
					case .Fading:
						grid[i2][j2+1] = .Fading
						grid[i2][j2] = .Empty
					}
				}
			}
		}
		
	}
}

check_detection :: proc(detection: ^bool) {
	for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
		for i := 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
			if (grid[i][j] == .Moving) && ((grid[i][j+1] == .Full) || (grid[i][j+1] == .Block)) {
				detection^ = true
			}
		}
	}
}

resolve_falling_movement :: proc(detection: ^bool, piece_active: ^bool) {
	if detection^ {
		for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
			for i := 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
				if grid[i][j] == .Moving {
					grid[i][j] = .Full
					detection^ = false
					piece_active^ = false
				}
			}
		}
	} else {
		for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
			for i := 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
				if grid[i][j] == .Moving {
					grid[i][j+1] = .Moving
					grid[i][j] = .Empty
				}
			}
		}
		
		piece_position.y += 1
	}
}

check_completion :: proc(line_to_delete: ^bool) {
	for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
		calculator := 0
		for i := 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
			if grid[i][j] == .Full {
				calculator += 1
			}
			
			if calculator == GRID_HORIZONTAL_SIZE-2 {
				line_to_delete^ = true
				calculator = 0
				
				for z in 1..<GRID_HORIZONTAL_SIZE-1 {
					grid[z][j] = .Fading
				}
			}
		}
	}
}

resolve_lateral_movement :: proc() -> (collision: bool) {
	switch {
	case rl.IsKeyDown(.LEFT):
		left_collision_loop: for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
			for i := 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
				if grid[i][j] == .Moving {
					if i-1 == 0 || grid[i-1][j] == .Full {
						collision = true
						break left_collision_loop
					}
				}
			}
		}
		
		if !collision {
			 for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
				for i := 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
					if grid[i][j] == .Moving {
						if grid[i][j] == .Moving {
							grid[i-1][j] = .Moving
							grid[i][j] = .Empty
						}
					}
				}
			}
			
			piece_position.x -= 1
		}
		
		
	case rl.IsKeyDown(.RIGHT):
		right_collision_loop: for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
			for i := 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
				if grid[i][j] == .Moving {
					if i+1 == GRID_HORIZONTAL_SIZE-1 || grid[i+1][j] == .Full {
						collision = true
						break right_collision_loop
					}
				}
			}
		}
		
		
		if !collision {
			 for j := GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
			 	for i := GRID_HORIZONTAL_SIZE-1; i >= 1; i -= 1 {
					if grid[i][j] == .Moving {
						if grid[i][j] == .Moving {
							grid[i+1][j] = .Moving
							grid[i][j] = .Empty
						}
					}
				}
			}
			
			
			piece_position.x += 1
		}
		
	}
	
	return
}

resolve_turn_movement :: proc() -> bool {
	// Input for turning the piece
	if rl.IsKeyDown(.UP) {
		checker := false

		// Check all turning possibilities
		if ((grid[piece_position.x + 3][piece_position.y] == .Moving) &&
		    (grid[piece_position.x][piece_position.y] != .Empty) &&
		    (grid[piece_position.x][piece_position.y] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 3][piece_position.y + 3] == .Moving) &&
		           (grid[piece_position.x + 3][piece_position.y] != .Empty) &&
		           (grid[piece_position.x + 3][piece_position.y] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x][piece_position.y + 3] == .Moving) &&
		           (grid[piece_position.x + 3][piece_position.y + 3] != .Empty) &&
		           (grid[piece_position.x + 3][piece_position.y + 3] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x][piece_position.y] == .Moving) &&
		           (grid[piece_position.x][piece_position.y + 3] != .Empty) &&
		           (grid[piece_position.x][piece_position.y + 3] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 1][piece_position.y] == .Moving) &&
		           (grid[piece_position.x][piece_position.y + 2] != .Empty) &&
		           (grid[piece_position.x][piece_position.y + 2] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 3][piece_position.y + 1] == .Moving) &&
		           (grid[piece_position.x + 1][piece_position.y] != .Empty) &&
		           (grid[piece_position.x + 1][piece_position.y] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 2][piece_position.y + 3] == .Moving) &&
		           (grid[piece_position.x + 3][piece_position.y + 1] != .Empty) &&
		           (grid[piece_position.x + 3][piece_position.y + 1] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x][piece_position.y + 2] == .Moving) &&
		           (grid[piece_position.x + 2][piece_position.y + 3] != .Empty) &&
		           (grid[piece_position.x + 2][piece_position.y + 3] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 2][piece_position.y] == .Moving) &&
		           (grid[piece_position.x][piece_position.y + 1] != .Empty) &&
		           (grid[piece_position.x][piece_position.y + 1] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 3][piece_position.y + 2] == .Moving) &&
		           (grid[piece_position.x + 2][piece_position.y] != .Empty) &&
		           (grid[piece_position.x + 2][piece_position.y] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 1][piece_position.y + 3] == .Moving) &&
		           (grid[piece_position.x + 3][piece_position.y + 2] != .Empty) &&
		           (grid[piece_position.x + 3][piece_position.y + 2] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x][piece_position.y + 1] == .Moving) &&
		           (grid[piece_position.x + 1][piece_position.y + 3] != .Empty) &&
		           (grid[piece_position.x + 1][piece_position.y + 3] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 1][piece_position.y + 1] == .Moving) &&
		           (grid[piece_position.x + 1][piece_position.y + 2] != .Empty) &&
		           (grid[piece_position.x + 1][piece_position.y + 2] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 2][piece_position.y + 1] == .Moving) &&
		           (grid[piece_position.x + 1][piece_position.y + 1] != .Empty) &&
		           (grid[piece_position.x + 1][piece_position.y + 1] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 2][piece_position.y + 2] == .Moving) &&
		           (grid[piece_position.x + 2][piece_position.y + 1] != .Empty) &&
		           (grid[piece_position.x + 2][piece_position.y + 1] != .Moving)) {
			checker = true
		} else if ((grid[piece_position.x + 1][piece_position.y + 2] == .Moving) &&
		           (grid[piece_position.x + 2][piece_position.y + 2] != .Empty) &&
		           (grid[piece_position.x + 2][piece_position.y + 2] != .Moving)) {
			checker = true
		}

		if !checker {
			piece[0][0], piece[3][0], piece[3][3], piece[0][3] = \
			piece[3][0], piece[3][3], piece[0][3], piece[0][0]
			
			piece[1][0], piece[3][1], piece[2][3], piece[0][2] = \
			piece[3][1], piece[2][3], piece[0][2], piece[1][0]

			piece[2][0], piece[3][2], piece[1][3], piece[0][1] = \
			piece[3][2], piece[1][3], piece[0][1], piece[2][0]
			
			piece[1][1], piece[2][1], piece[2][2], piece[1][2] = \
			piece[2][1], piece[2][2], piece[1][2], piece[1][1]
		}

		for j: i32 = GRID_VERTICAL_SIZE-2; j >= 0; j -= 1 {
			for i: i32 = 1; i < GRID_HORIZONTAL_SIZE-1; i += 1 {
				if grid[i][j] == .Moving {
					grid[i][j] = .Empty
				}
			}
		}

		for i in i32(0)..<4 {
			for j in i32(0)..<4 {
				if piece[i][j] == .Moving {
					grid[piece_position.x+i][piece_position.y+j] = .Moving
				}
			}
		}

		return true
	}

	return false
}
