/*******************************************************************************************
*
*   raylib [audio] example - sound loading
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.1, last time updated with raylib 3.5
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [audio] example - sound loading")

	rl.InitAudioDevice()      // Initialize audio device

	fx_wav := rl.LoadSound("resources/spring.wav")         // Load WAV audio file
	fx_ogg := rl.LoadSound("resources/target.ogg")        // Load OGG audio file

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsKeyPressed(.SPACE) {
			rl.PlaySound(fx_wav)      // Play WAV sound
		}
		if rl.IsKeyPressed(.ENTER) {
			rl.PlaySound(fx_ogg)      // Play OGG sound
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawText("Press SPACE to PLAY the WAV sound!", 200, 180, 20, rl.LIGHTGRAY)
			rl.DrawText("Press ENTER to PLAY the OGG sound!", 200, 220, 20, rl.LIGHTGRAY)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.UnloadSound(fx_wav)     // Unload sound data
	rl.UnloadSound(fx_ogg)     // Unload sound data
	
	rl.CloseAudioDevice()     // Close audio device
	rl.CloseWindow()          // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}