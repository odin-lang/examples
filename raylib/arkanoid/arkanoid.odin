package main

// /*******************************************************************************************
// *
// *   raylib - classic game: arkanoid
// *
// *   Sample game developed by Marc Palau and Ramon Santamaria
// *
// *   This game has been created using raylib v1.3 (www.raylib.com)
// *   raylib is licensed under an unmodified zlib/libpng license (View raylib.h for details)
// *
// *   Copyright (c) 2015 Ramon Santamaria (@raysan5)
// *
// ********************************************************************************************/


import rl "vendor:raylib"

PLAYER_MAX_LIFE ::  5
LINES_OF_BRICKS ::  5
BRICKS_PER_LINE :: 20

Player :: struct {
	position: rl.Vector2,
	size: rl.Vector2,
	life: int,
}

Ball :: struct {
	position: rl.Vector2,
	speed: rl.Vector2,
	radius: f32,
	active: bool,
}

Brick :: struct {
	position: rl.Vector2,
	active: bool,
}

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

game_over := false
pause     := false

player: Player
ball: Ball
brick: [LINES_OF_BRICKS][BRICKS_PER_LINE]Brick
brick_size: rl.Vector2

main :: proc() {
	// Initialization (Note windowTitle is unused on Android)
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "classic game: arkanoid")

	init_game()

	rl.SetTargetFPS(60)

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		update_draw_frame()
	}

	unload_game()    // Unload loaded data (textures, sounds, models...)

	rl.CloseWindow() // Close window and OpenGL context

}

// Initialize game variables
init_game :: proc() {
	brick_size = { f32(rl.GetScreenWidth()/BRICKS_PER_LINE), 40 }

	// Initialize player
	player.position = { SCREEN_WIDTH/2, SCREEN_HEIGHT*7/8 }
	player.size = { SCREEN_WIDTH/10, 20 }
	player.life = PLAYER_MAX_LIFE

	// Initialize ball
	ball.position = { player.position.x, player.position.y - player.size.y/2 - ball.radius }
	ball.speed = { 0, 0 }
	ball.radius = 7
	ball.active = false

	// Initialize bricks
	initialDownPosition := 50

	for i in 0..<LINES_OF_BRICKS {
		for j in 0..<BRICKS_PER_LINE {
			brick[i][j].position = { f32(j)*brick_size.x + brick_size.x/2, f32(i)*brick_size.y + f32(initialDownPosition) }
			brick[i][j].active = true
		}
	}
}

// Update game (one frame)
update_game :: proc() {
	if !game_over {
		if rl.IsKeyPressed(.P) {
			pause = !pause
		}

		if !pause {
			// Player movement logic
			if rl.IsKeyDown(.LEFT) { player.position.x -= 5 }
			if (player.position.x - player.size.x/2) <= 0 { player.position.x = player.size.x/2 }
			if rl.IsKeyDown(.RIGHT) { player.position.x += 5 }
			if (player.position.x + player.size.x/2) >= SCREEN_WIDTH { player.position.x = SCREEN_WIDTH - player.size.x/2 }

			// Ball launching logic
			if !ball.active {
				if rl.IsKeyPressed(.SPACE) {
					ball.active = true
					ball.speed = { 0, -5 }
				}
			}

			// Ball movement logic
			if ball.active {
				ball.position.x += ball.speed.x
				ball.position.y += ball.speed.y
			} else {
				ball.position = { player.position.x, player.position.y - player.size.y/2 - ball.radius }
			}

			// Collision logic: ball vs walls
			if ((ball.position.x + ball.radius) >= SCREEN_WIDTH) || ((ball.position.x - ball.radius) <= 0) { ball.speed.x *= -1 }
			if (ball.position.y - ball.radius) <= 0 { ball.speed.y *= -1 }
			if (ball.position.y + ball.radius) >= SCREEN_HEIGHT {
				ball.speed = { 0, 0 }
				ball.active = false

				player.life -= 1
			}

			// Collision logic: ball vs player
			if rl.CheckCollisionCircleRec(ball.position, ball.radius,
				(rl.Rectangle){ player.position.x - player.size.x/2, player.position.y - player.size.y/2, player.size.x, player.size.y}) {
				if ball.speed.y > 0 {
					ball.speed.y *= -1
					ball.speed.x = (ball.position.x - player.position.x)/(player.size.x/2)*5
				}
			}

			// Collision logic: ball vs bricks
			for i in 0..<LINES_OF_BRICKS {
				for j in 0..<BRICKS_PER_LINE {
					if brick[i][j].active {
						if ((ball.position.y - ball.radius) <= (brick[i][j].position.y + brick_size.y/2)) &&
							((ball.position.y - ball.radius) > (brick[i][j].position.y + brick_size.y/2 + ball.speed.y)) &&
							((abs(ball.position.x - brick[i][j].position.x)) < (brick_size.x/2 + ball.radius*2/3)) && (ball.speed.y < 0) {
							
							// Hit below
							brick[i][j].active = false
							ball.speed.y *= -1
						} else if ((ball.position.y + ball.radius) >= (brick[i][j].position.y - brick_size.y/2)) &&
								((ball.position.y + ball.radius) < (brick[i][j].position.y - brick_size.y/2 + ball.speed.y)) &&
								((abs(ball.position.x - brick[i][j].position.x)) < (brick_size.x/2 + ball.radius*2/3)) && (ball.speed.y > 0) {
							// Hit above
							brick[i][j].active = false
							ball.speed.y *= -1
						} else if ((ball.position.x + ball.radius) >= (brick[i][j].position.x - brick_size.x/2)) &&
								((ball.position.x + ball.radius) < (brick[i][j].position.x - brick_size.x/2 + ball.speed.x)) &&
								((abs(ball.position.y - brick[i][j].position.y)) < (brick_size.y/2 + ball.radius*2/3)) && (ball.speed.x > 0) {
							// Hit left
							brick[i][j].active = false
							ball.speed.x *= -1
						} else if ((ball.position.x - ball.radius) <= (brick[i][j].position.x + brick_size.x/2)) &&
								((ball.position.x - ball.radius) > (brick[i][j].position.x + brick_size.x/2 + ball.speed.x)) &&
								((abs(ball.position.y - brick[i][j].position.y)) < (brick_size.y/2 + ball.radius*2/3)) && (ball.speed.x < 0) {
							// Hit right
							brick[i][j].active = false
							ball.speed.x *= -1
						}
					}
				}
			}

			// Game over logic
			if player.life <= 0 {
				game_over = true
			} else {
				game_over = true

				for i in 0..<LINES_OF_BRICKS {
					for j in 0..<BRICKS_PER_LINE {
						if brick[i][j].active {
							game_over = false
						}
					}
				}
			}
		}

	} else {
		if rl.IsKeyPressed(.ENTER) {
			init_game()
			game_over = false
		}
	}
}

// Draw game (one frame)
draw_game :: proc() {
	rl.BeginDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		if !game_over {
			// Draw player bar
			rl.DrawRectangle(i32(player.position.x - player.size.x/2), i32(player.position.y - player.size.y/2), i32(player.size.x), i32(player.size.y), rl.BLACK)

			// Draw player lives
			for i in 0..<player.life {
				rl.DrawRectangle(20 + i32(40*i), SCREEN_HEIGHT - 30, 35, 10, rl.LIGHTGRAY)
			}

			// Draw ball
			rl.DrawCircleV(ball.position, ball.radius, rl.MAROON)

			// Draw bricks
			for i in 0..<LINES_OF_BRICKS {
				for j in 0..<BRICKS_PER_LINE {
					if brick[i][j].active {
						if (i + j) % 2 == 0 {
							rl.DrawRectangle(i32(brick[i][j].position.x - brick_size.x/2), i32(brick[i][j].position.y - brick_size.y/2), i32(brick_size.x), i32(brick_size.y), rl.GRAY)
						} else {
							rl.DrawRectangle(i32(brick[i][j].position.x - brick_size.x/2), i32(brick[i][j].position.y - brick_size.y/2), i32(brick_size.x), i32(brick_size.y), rl.DARKGRAY)
						}
					}
				}
			}

			if pause { 
				rl.DrawText("GAME PAUSED", SCREEN_WIDTH/2 - rl.MeasureText("GAME PAUSED", 40)/2, SCREEN_HEIGHT/2 - 40, 40, rl.RED)
			}
		} else {
			rl.DrawText("PRESS [ENTER] TO PLAY AGAIN", rl.GetScreenWidth()/2 - rl.MeasureText("PRESS [ENTER] TO PLAY AGAIN", 20)/2, rl.GetScreenHeight()/2 - 50, 20, rl.GRAY)
		}

	rl.EndDrawing()
}

// Unload game variables
unload_game :: proc() {
	// TODO: Unload all dynamic loaded data (textures, sounds, models...)
}

// Update and Draw (one frame)
update_draw_frame :: proc() {
	update_game()
	draw_game()
}
