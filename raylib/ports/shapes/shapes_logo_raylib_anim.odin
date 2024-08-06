package raylib_examples

/*******************************************************************************************
*
*   raylib [shapes] example - raylib logo animation
*
*   This example was originally created in C with raylib 1.0, and updated with raylib 4.0
*   before being translated to Odin.
*
*   The original example in C can be found on raylib.com at:
*
*   https://www.raylib.com/examples/shapes/loader.html?name=shapes_logo_raylib_anim
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
*   Copyright (c) 2014-2023 Ramon Santamaria (@raysan5)
*   Copyright (c) 2023 Benjamin G. Thompson (@bg-thompson)
*
********************************************************************************************/

import rl "vendor:raylib"

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

State :: enum u8 {
	STATE_0,
	STATE_1,
	STATE_2,
	STATE_3,
	STATE_4,
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - raylib logo animation")
	defer rl.CloseWindow() // Close window and OpenGL context when leaving main.

	logoPosX: i32 = SCREEN_WIDTH  / 2 - 128
	logoPosY: i32 = SCREEN_HEIGHT / 2 - 128

	framesCounter := 0
	lettersCount: i32 = 0

	topSideRecWidth:    i32 = 16
	leftSideRecHeight:  i32 = 16
	bottomSideRecWidth: i32 = 16
	rightSideRecHeight: i32 = 16


	state := State.STATE_0 // Track animation states.
	alpha: f32 = 1.0       // Useful for fading.
	rl.SetTargetFPS(60)    // Set frames per second.

	// The primary loop.
	for !rl.WindowShouldClose() { // Detect window close button or ESC key press.
		switch state {
		case .STATE_0:                 // State 0: Small box blinking.
			framesCounter += 1
			if framesCounter == 120 {
				state = .STATE_1
				framesCounter = 0      // Reset counter... will be used later...
			}

		case .STATE_1:                 // State 1: Top and left bars growing.
			topSideRecWidth   += 4
			leftSideRecHeight += 4
			if topSideRecWidth == 256 {
				state = .STATE_2
			}

		case .STATE_2:                 // State 2: Bottom and right bars growing.
			bottomSideRecWidth += 4
			rightSideRecHeight += 4
			if bottomSideRecWidth == 256 {
				state = .STATE_3
			}

		case .STATE_3:                 // State 3: Letters appearing (one by one).
			framesCounter += 1
			if framesCounter / 12 == 1 { // Every 12 frames, one more letter!
				lettersCount += 1
				framesCounter = 0
			}

			if lettersCount >= 10 { // When all letters have appeared, fade out everything.
				alpha -= 0.02
				if alpha <= 0 {
					alpha = 0
					state = .STATE_4
				}
			}

		case .STATE_4:
			if rl.IsKeyPressed(rl.KeyboardKey.R) {
				framesCounter      = 0
				lettersCount       = 0
				topSideRecWidth    = 16
				leftSideRecHeight  = 16
				bottomSideRecWidth = 16
				rightSideRecHeight = 16
				alpha = 1.0
				state = .STATE_0          // Return to State 0
			}
		}

		// Start drawing.
		rl.BeginDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		switch state {
		case .STATE_0:
			if (framesCounter / 15) % 2 != 0 {
				rl.DrawRectangle(logoPosX, logoPosY, 16, 16, rl.BLACK)
			}

		case .STATE_1:
			rl.DrawRectangle(logoPosX, logoPosY, topSideRecWidth, 16, rl.BLACK)
			rl.DrawRectangle(logoPosX, logoPosY, 16, leftSideRecHeight, rl.BLACK)

		case .STATE_2:
			rl.DrawRectangle(logoPosX, logoPosY, topSideRecWidth, 16, rl.BLACK)
			rl.DrawRectangle(logoPosX, logoPosY, 16, leftSideRecHeight, rl.BLACK)

			rl.DrawRectangle(logoPosX + 240, logoPosY, 16, rightSideRecHeight, rl.BLACK)
			rl.DrawRectangle(logoPosX, logoPosY + 240, bottomSideRecWidth, 16, rl.BLACK)

		case .STATE_3:
			rl.DrawRectangle(logoPosX, logoPosY, topSideRecWidth, 16, rl.Fade(rl.BLACK, alpha))
			rl.DrawRectangle(logoPosX, logoPosY + 16, 16, leftSideRecHeight - 32, rl.Fade(rl.BLACK, alpha))

			rl.DrawRectangle(logoPosX + 240, logoPosY + 16, 16, rightSideRecHeight - 32, rl.Fade(rl.BLACK, alpha))
			rl.DrawRectangle(logoPosX, logoPosY + 240, bottomSideRecWidth, 16, rl.Fade(rl.BLACK, alpha))

			rl.DrawRectangle(rl.GetScreenWidth() / 2 - 112, rl.GetScreenHeight() / 2 - 112, 224, 224, rl.Fade(rl.RAYWHITE, alpha))

			rl.DrawText(rl.TextSubtext("raylib", 0, lettersCount), rl.GetScreenWidth()/2 - 44, rl.GetScreenHeight() / 2 + 48, 50, rl.Fade(rl.BLACK, alpha))

		case .STATE_4:
			rl.DrawText("[R] REPLAY", 340, 200, 20, rl.GRAY)
		}
		rl.EndDrawing()
	}
}
