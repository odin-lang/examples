/*******************************************************************************************
*
*   raylib [textures] example - blend modes
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   NOTE: Images are loaded in CPU memory (RAM); textures are loaded in GPU memory (VRAM)
*
*   Example originally created with raylib 3.5, last time updated with raylib 3.5
*
*   Example contributed by Karlo Licudine (@accidentalrebel) and reviewed by Ramon Santamaria (@raysan5)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2020-2025 Karlo Licudine (@accidentalrebel)
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [textures] example - blend modes")

	// NOTE: Textures MUST be loaded after Window initialization (OpenGL context is required)
	bg_image := rl.LoadImage("resources/cyberpunk_street_background.png")     // Loaded in CPU memory (RAM)
	bg_texture := rl.LoadTextureFromImage(bg_image)          // Image converted to texture, GPU memory (VRAM)

	fg_image := rl.LoadImage("resources/cyberpunk_street_foreground.png")     // Loaded in CPU memory (RAM)
	fg_texture := rl.LoadTextureFromImage(fg_image)          // Image converted to texture, GPU memory (VRAM)

	// Once image has been converted to texture and uploaded to VRAM, it can be unloaded from RAM
	rl.UnloadImage(bg_image)
	rl.UnloadImage(fg_image)

	BLEND_COUNT_MAX :: 4
	blend_mode := rl.BlendMode(0)

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//---------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsKeyPressed(.SPACE) {
			if int(blend_mode) >= BLEND_COUNT_MAX - 1 {
				blend_mode = rl.BlendMode(0)
			} else {
				blend_mode = rl.BlendMode(int(blend_mode) + 1)
			}
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawTexture(bg_texture, SCREEN_WIDTH/2 - bg_texture.width/2, SCREEN_HEIGHT/2 - bg_texture.height/2, rl.WHITE)

			// Apply the blend mode and then draw the foreground texture
			rl.BeginBlendMode(blend_mode)
				rl.DrawTexture(fg_texture, SCREEN_WIDTH/2 - fg_texture.width/2, SCREEN_HEIGHT/2 - fg_texture.height/2, rl.WHITE)
			rl.EndBlendMode()

			// Draw the texts
			rl.DrawText("Press SPACE to change blend modes.", 310, 350, 10, rl.GRAY)
			
			#partial switch blend_mode {
				case .ALPHA:
					rl.DrawText("Current: BLEND_ALPHA", (SCREEN_WIDTH/2) - 60, 370, 10, rl.GRAY)
				case .ADDITIVE:
					rl.DrawText("Current: BLEND_ADDITIVE", (SCREEN_WIDTH/2) - 60, 370, 10, rl.GRAY)
				case .MULTIPLIED:
					rl.DrawText("Current: BLEND_MULTIPLIED", (SCREEN_WIDTH/2) - 60, 370, 10, rl.GRAY)
				case .ADD_COLORS:
					rl.DrawText("Current: BLEND_ADD_COLORS", (SCREEN_WIDTH/2) - 60, 370, 10, rl.GRAY)
			}

			rl.DrawText("(c) Cyberpunk Street Environment by Luis Zuno (@ansimuz)", SCREEN_WIDTH - 330, SCREEN_HEIGHT - 20, 10, rl.GRAY)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.UnloadTexture(fg_texture) // Unload foreground texture
	rl.UnloadTexture(bg_texture) // Unload background texture

	rl.CloseWindow()            // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}