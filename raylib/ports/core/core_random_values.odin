/*******************************************************************************************
*
*   raylib [core] example - random values
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.1, last time updated with raylib 1.1
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
main :: proc()
{
	// Initialization
	//--------------------------------------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [core] example - random values")

	// SetRandomSeed(0xaabbccff);   // Set a custom random seed if desired, by default: "time(NULL)"

	rand_value: i32 = rl.GetRandomValue(-8, 5)   // Get a random integer number between -8 and 5 (both included)

	timer: f32 // Variable used to count frames
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		// Every two seconds (120 frames) a new random value is generated
		if timer >= 2 {
			rand_value = rl.GetRandomValue(-8, 5)
			timer = 0
		}
		
		timer += rl.GetFrameTime()
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawText("Every 2 seconds a new random value is generated:", 130, 100, 20, rl.MAROON)

			rl.DrawText(rl.TextFormat("%i", rand_value), 360, 180, 80, rl.LIGHTGRAY)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}