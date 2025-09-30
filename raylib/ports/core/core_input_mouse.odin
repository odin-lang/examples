/*******************************************************************************************
*
*   raylib [core] example - input mouse
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.0, last time updated with raylib 5.5
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2014-2025 Ramon Santamaria (@raysan5)
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

	rl.InitWindow(screenWidth, screenHeight, "raylib [core] example - input mouse")

	ballPosition: rl.Vector2 = { -100, -100 }
	ballColor: rl.Color = rl.DARKBLUE

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//---------------------------------------------------------------------------------------

	// Main game loop
	for (!rl.WindowShouldClose()) {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if (rl.IsKeyPressed(.H)) {
			if (rl.IsCursorHidden()) {
				rl.ShowCursor()
			} else {
				rl.HideCursor()
			}
		}

		ballPosition = rl.GetMousePosition()

		if (rl.IsMouseButtonPressed(.LEFT)) {
			ballColor = rl.MAROON
		} else if (rl.IsMouseButtonPressed(.MIDDLE)) {
			ballColor = rl.LIME
		} else if (rl.IsMouseButtonPressed(.RIGHT)) {
			ballColor = rl.DARKBLUE
		} else if (rl.IsMouseButtonPressed(.SIDE)) {
			ballColor = rl.PURPLE
		} else if (rl.IsMouseButtonPressed(.EXTRA)) {
			ballColor = rl.YELLOW
		} else if (rl.IsMouseButtonPressed(.FORWARD)) {
			ballColor = rl.ORANGE
		} else if (rl.IsMouseButtonPressed(.BACK)) {
			ballColor = rl.BEIGE
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawCircleV(ballPosition, 40, ballColor)

			rl.DrawText("move ball with mouse and click mouse button to change color", 10, 10, 20, rl.DARKGRAY)
			rl.DrawText("Press 'H' to toggle cursor visibility", 10, 30, 20, rl.DARKGRAY)

			if (rl.IsCursorHidden()) {
				rl.DrawText("CURSOR HIDDEN", 20, 60, 20, rl.RED)
			} else {
				rl.DrawText("CURSOR VISIBLE", 20, 60, 20, rl.LIME)
			}

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}