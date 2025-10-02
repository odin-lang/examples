/*******************************************************************************************
*
*   raylib [shapes] example - logo raylib
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.0, last time updated with raylib 1.0
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - logo raylib")
	defer rl.CloseWindow()        // Close window and OpenGL context

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		// TODO: Update your variables here
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawRectangle(rl.GetScreenWidth()/2 - 128, rl.GetScreenHeight()/2 - 128, 256, 256, rl.BLACK)
			rl.DrawRectangle(rl.GetScreenWidth()/2 - 112, rl.GetScreenHeight()/2 - 112, 224, 224, rl.RAYWHITE)
			rl.DrawText("raylib", rl.GetScreenWidth()/2 - 44, rl.GetScreenHeight()/2 + 48, 50, rl.BLACK)

			rl.DrawText("this is NOT a texture!", 350, 370, 10, rl.GRAY)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
}