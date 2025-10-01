/*******************************************************************************************
*
*   raylib [audio] example - music stream
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.3, last time updated with raylib 4.2
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2015-2025 Ramon Santamaria (@raysan5)
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [audio] example - music stream")

	rl.InitAudioDevice()              // Initialize audio device

	music: rl.Music = rl.LoadMusicStream("resources/country.mp3")

	rl.PlayMusicStream(music)

	time_played: f32         // Time played normalized [0.0f..1.0f]
	pause: bool             // Music playing paused

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for (!rl.WindowShouldClose()) {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		rl.UpdateMusicStream(music)   // Update music buffer with new stream data

		// Restart music playing (stop and play)
		if rl.IsKeyPressed(.SPACE) {
			rl.StopMusicStream(music)
			rl.PlayMusicStream(music)
		}

		// Pause/Resume music playing
		if rl.IsKeyPressed(.P) {
			pause = !pause

			if pause {
				rl.PauseMusicStream(music)
			} else {
				rl.ResumeMusicStream(music)
			}
		}

		// Get normalized time played for current music stream
		time_played = rl.GetMusicTimePlayed(music)/rl.GetMusicTimeLength(music)

		if time_played > 1 {
			time_played = 1   // Make sure time played is no longer than music
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawText("MUSIC SHOULD BE PLAYING!", 255, 150, 20, rl.LIGHTGRAY)

			rl.DrawRectangle(200, 200, 400, 12, rl.LIGHTGRAY)
			rl.DrawRectangle(200, 200, i32(time_played*400), 12, rl.MAROON)
			rl.DrawRectangleLines(200, 200, 400, 12, rl.GRAY)

			rl.DrawText("PRESS SPACE TO RESTART MUSIC", 215, 250, 20, rl.LIGHTGRAY)
			rl.DrawText("PRESS P TO PAUSE/RESUME MUSIC", 208, 280, 20, rl.LIGHTGRAY)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.UnloadMusicStream(music)   // Unload music stream buffers from RAM

	rl.CloseAudioDevice()         // Close audio device (music streaming is automatically stopped)

	rl.CloseWindow()              // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}