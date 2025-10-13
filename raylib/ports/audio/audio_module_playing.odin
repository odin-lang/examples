/*******************************************************************************************
*
*   raylib [audio] example - module playing
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.5, last time updated with raylib 3.5
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2016-2025 Ramon Santamaria (@raysan5)
*
********************************************************************************************/

package raylib_examples

import rl "vendor:raylib"

CircleWave :: struct {
	position: rl.Vector2,
	radius: f32,
	alpha: f32,
	speed: f32,
	color: rl.Color,
}

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//--------------------------------------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	MAX_CIRCLES :: 64

	rl.SetConfigFlags({.MSAA_4X_HINT})  // NOTE: Try to enable MSAA 4X

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [audio] example - module playing")

	rl.InitAudioDevice()                  // Initialize audio device

	colors := [14]rl.Color {rl.ORANGE, rl.RED, rl.GOLD, rl.LIME, rl.BLUE, rl.VIOLET, rl.BROWN, rl.LIGHTGRAY, rl.PINK,
						 rl.YELLOW, rl.GREEN, rl.SKYBLUE, rl.PURPLE, rl.BEIGE}

	// Creates some circles for visual effect
	circles: [MAX_CIRCLES]CircleWave

	for &c in circles {
		radius := rl.GetRandomValue(10, 40)

		c = {
			radius = f32(radius),
			position = {f32(rl.GetRandomValue(radius, SCREEN_WIDTH - radius)), f32(rl.GetRandomValue(radius, SCREEN_HEIGHT - radius))},
			speed = f32(rl.GetRandomValue(1, 100))/2000,
			color = colors[rl.GetRandomValue(0, 13)],
		}
	}

	music := rl.LoadMusicStream("resources/mini1111.xm")
	defer rl.UnloadMusicStream(music)          // Unload music stream buffers from RAM
	music.looping = false
	pitch: f32 = 1

	rl.PlayMusicStream(music)

	time_played: f32
	pause: bool

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		rl.UpdateMusicStream(music)      // Update music buffer with new stream data

		// Restart music playing (stop and play)
		if rl.IsKeyPressed(.SPACE) {
			rl.StopMusicStream(music)
			rl.PlayMusicStream(music)
			pause = false
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

		if rl.IsKeyDown(.DOWN) {
			pitch -= 0.01
		} else if rl.IsKeyDown(.UP) {
			pitch += 0.01
		}

		rl.SetMusicPitch(music, pitch)

		// Get time_played scaled to bar dimensions
		time_played = rl.GetMusicTimePlayed(music)/rl.GetMusicTimeLength(music)*(SCREEN_WIDTH - 40)

		// Color circles animation
		if !pause {
			for &c in circles {
				c.alpha += c.speed
				c.radius += c.speed*10

				if c.alpha > 1 {
					c.speed *= -1
				}

				if c.alpha <= 0 {
					radius := rl.GetRandomValue(10, 40)

					c = {
						radius = f32(radius),
						position = {f32(rl.GetRandomValue(radius, SCREEN_WIDTH - radius)), f32(rl.GetRandomValue(radius, SCREEN_HEIGHT - radius))},
						speed = f32(rl.GetRandomValue(1, 100))/2000,
						color = colors[rl.GetRandomValue(0, 13)],
					}
				}
			}
		}
		
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			for c in circles {
				rl.DrawCircleV(c.position, c.radius, rl.Fade(c.color, c.alpha))
			}

			// Draw time bar
			rl.DrawRectangle(20, SCREEN_HEIGHT - 20 - 12, SCREEN_WIDTH - 40, 12, rl.LIGHTGRAY)
			rl.DrawRectangle(20, SCREEN_HEIGHT - 20 - 12, i32(time_played), 12, rl.MAROON)
			rl.DrawRectangleLines(20, SCREEN_HEIGHT - 20 - 12, SCREEN_WIDTH - 40, 12, rl.GRAY)

			// Draw help instructions
			rl.DrawRectangle(20, 20, 425, 145, rl.WHITE)
			rl.DrawRectangleLines(20, 20, 425, 145, rl.GRAY)
			rl.DrawText("PRESS SPACE TO RESTART MUSIC", 40, 40, 20, rl.BLACK)
			rl.DrawText("PRESS P TO PAUSE/RESUME", 40, 70, 20, rl.BLACK)
			rl.DrawText("PRESS UP/DOWN TO CHANGE SPEED", 40, 100, 20, rl.BLACK)
			rl.DrawText(rl.TextFormat("SPEED: %f", pitch), 40, 130, 20, rl.MAROON)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseAudioDevice()     // Close audio device (music streaming is automatically stopped)
	rl.CloseWindow()          // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}