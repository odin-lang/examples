/*******************************************************************************************
*
*   raylib [core] example - scissor test
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 2.5, last time updated with raylib 3.0
*
*   Example contributed by Chris Dill (@MysteriousSpace) and reviewed by Ramon Santamaria (@raysan5)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2019-2025 Chris Dill (@MysteriousSpace)
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [core] example - scissor test")

	scissor_area: rl.Rectangle = {0, 0, 300, 300}
	scissor_mode: bool = true

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsKeyPressed(.S) {
			scissor_mode = !scissor_mode
		}

		// Centre the scissor area around the mouse position
		scissor_area.x = f32(rl.GetMouseX()) - scissor_area.width/2
		scissor_area.y = f32(rl.GetMouseY()) - scissor_area.height/2
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			if scissor_mode {
				rl.BeginScissorMode(i32(scissor_area.x), i32(scissor_area.y), i32(scissor_area.width), i32(scissor_area.height))
			}

			// Draw full screen rectangle and some text
			// NOTE: Only part defined by scissor area will be rendered
			rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.RED)
			rl.DrawText("Move the mouse around to reveal this text!", 190, 200, 20, rl.LIGHTGRAY)

			if scissor_mode {
				rl.EndScissorMode()
			}

			rl.DrawRectangleLinesEx(scissor_area, 1, rl.BLACK)
			rl.DrawText("Press S to toggle scissor test", 10, 10, 20, rl.BLACK)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}