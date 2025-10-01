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
	screenWidth :: 800
	screenHeight :: 450

	rl.InitWindow(screenWidth, screenHeight, "raylib [audio] example - sound loading")

	rl.InitAudioDevice()      // Initialize audio device

	fxWav: rl.Sound = rl.LoadSound("resources/spring.wav")         // Load WAV audio file
	fxOgg: rl.Sound = rl.LoadSound("resources/target.ogg")        // Load OGG audio file

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsKeyPressed(.SPACE) {
			rl.PlaySound(fxWav)      // Play WAV sound
		}
		if rl.IsKeyPressed(.ENTER) {
			rl.PlaySound(fxOgg)      // Play OGG sound
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
	rl.UnloadSound(fxWav)     // Unload sound data
	rl.UnloadSound(fxOgg)     // Unload sound data

	rl.CloseAudioDevice()     // Close audio device

	rl.CloseWindow()          // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}