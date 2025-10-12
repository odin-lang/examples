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
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [core] example - input mouse")

	ball_position := rl.Vector2 { -100, -100 }
	ball_color: rl.Color = rl.DARKBLUE

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//---------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsKeyPressed(.H) {
			if rl.IsCursorHidden() {
				rl.ShowCursor()
			} else {
				rl.HideCursor()
			}
		}

		ball_position = rl.GetMousePosition()

		if rl.IsMouseButtonPressed(.LEFT) {
			ball_color = rl.MAROON
		} else if rl.IsMouseButtonPressed(.MIDDLE) {
			ball_color = rl.LIME
		} else if rl.IsMouseButtonPressed(.RIGHT) {
			ball_color = rl.DARKBLUE
		} else if rl.IsMouseButtonPressed(.SIDE) {
			ball_color = rl.PURPLE
		} else if rl.IsMouseButtonPressed(.EXTRA) {
			ball_color = rl.YELLOW
		} else if rl.IsMouseButtonPressed(.FORWARD) {
			ball_color = rl.ORANGE
		} else if rl.IsMouseButtonPressed(.BACK) {
			ball_color = rl.BEIGE
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawCircleV(ball_position, 40, ball_color)

			rl.DrawText("move ball with mouse and click mouse button to change color", 10, 10, 20, rl.DARKGRAY)
			rl.DrawText("Press 'H' to toggle cursor visibility", 10, 30, 20, rl.DARKGRAY)

			if rl.IsCursorHidden() {
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