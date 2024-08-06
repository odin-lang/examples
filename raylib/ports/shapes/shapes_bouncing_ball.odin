package raylib_examples

/*******************************************************************************************
*
*   raylib [shapes] example - bouncing ball
*
*   This example was originally created in C with raylib 2.5 before being translated to Odin.
*
*   The original example in C can be found on raylib.com at:
*
*   https://www.raylib.com/examples/shapes/loader.html?name=shapes_bouncing_ball
*
*   raylib is licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software. The license
*   can be found in its entirety as part of the standard Odin distribution at:
*
*   /vendor/raylib/LICENSE
*
*   or online at:
*
*   https://www.raylib.com/license.html
*
*   This example is licensed under an unmodified zlib/libpng license, which is an
*   OSI-certified, BSD-like license that allows static linking with closed source software.
*
*   Copyright (c) 2013-2023 Ramon Santamaria (@raysan5)
*   Copyright (c) 2023 Benjamin G. Thompson (@bg-thompson)
*
********************************************************************************************/

import rl "vendor:raylib"

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

main :: proc() {
	rl.SetConfigFlags(rl.ConfigFlags{.MSAA_4X_HINT}) // Try to enable MSAA 4X.
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - bouncing ball")
	defer rl.CloseWindow() // Close window and OpenGL context when leaving main.

	// Ball position, velocity, radius, and color.
	ball_pos   := rl.Vector2{f32(rl.GetScreenWidth() / 2), f32(rl.GetScreenHeight() / 2)}
	ball_vel   := rl.Vector2{5,4}
	ball_rad   :: 20
	ball_color :: rl.MAROON

	pause := true
	framesCounter := 0
	rl.SetTargetFPS(60) // Set frames-per-second.

	// The primary loop.
	for !rl.WindowShouldClose() { // Detect window close button or ESC key press.
		if rl.IsKeyPressed(rl.KeyboardKey.SPACE) {
			pause = ! pause
		}
		if ! pause {
			ball_pos.x += ball_vel.x
			ball_pos.y += ball_vel.y

			// Check walls collision for bouncing.
			if ball_pos.x >= f32(rl.GetScreenWidth() - ball_rad) || ball_pos.x <= ball_rad {
				ball_vel.x *= -1
			}
			if ball_pos.y >= f32(rl.GetScreenHeight() - ball_rad) || ball_pos.y <= ball_rad {
				ball_vel.y *= -1
			}
		} else {
			framesCounter += 1
		}

		// Start drawing.
		rl.BeginDrawing()

		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawCircleV(ball_pos, ball_rad, ball_color)
		rl.DrawText("PRESS SPACE to PAUSE BALL MOVEMENT", 10, rl.GetScreenHeight() - 25, 20, rl.LIGHTGRAY)
		rl.DrawFPS(10, 10)

		// On pause, we draw a blinking message
		if pause && (framesCounter / 30) % 2 != 0 {
			rl.DrawText("PAUSED", 350, 200, 30, rl.GRAY)
		}

		rl.EndDrawing()
	}
}
