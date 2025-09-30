/*******************************************************************************************
*
*   raylib [core] example - window should close
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 4.2, last time updated with raylib 4.2
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2013-2025 Ramon Santamaria (@raysan5)
*
********************************************************************************************/

package raylib_examples

import rl "vendor:raylib"

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//--------------------------------------------------------------------------------------
	screenWidth :: 800
	screenHeight :: 450

	rl.InitWindow(screenWidth, screenHeight, "raylib [core] example - window should close")

	rl.SetExitKey(.KEY_NULL)       // Disable KEY_ESCAPE to close window, X-button still works

	exitWindowRequested: bool = false   // Flag to request window to exit
	exitWindow: bool = false    // Flag to set window to exit

	rl.SetTargetFPS(60)           // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for (!exitWindow) {
		// Update
		//----------------------------------------------------------------------------------
		// Detect if X-button or KEY_ESCAPE have been pressed to close window
		if (rl.WindowShouldClose() || rl.IsKeyPressed(.ESCAPE)) {
			exitWindowRequested = true
		}

		if (exitWindowRequested) {
			// A request for close window has been issued, we can save data before closing
			// or just show a message asking for confirmation

			if (rl.IsKeyPressed(.Y)) {
				exitWindow = true
			} else if (rl.IsKeyPressed(.N)) {
				exitWindowRequested = false
			}
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			if (exitWindowRequested) {
				rl.DrawRectangle(0, 100, screenWidth, 200, rl.BLACK)
				rl.DrawText("Are you sure you want to exit program? [Y/N]", 40, 180, 30, rl.WHITE)
			} else {
				rl.DrawText("Try to close the window to get confirmation message!", 120, 200, 20, rl.LIGHTGRAY)
			}

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}