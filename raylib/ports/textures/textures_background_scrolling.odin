/*******************************************************************************************
*
*   raylib [textures] example - background scrolling
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 2.0, last time updated with raylib 2.5
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2019-2025 Ramon Santamaria (@raysan5)
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

	rl.InitWindow(screenWidth, screenHeight, "raylib [textures] example - background scrolling")

	// NOTE: Be careful, background width must be equal or bigger than screen width
	// if not, texture should be draw more than two times for scrolling effect
	background: rl.Texture2D = rl.LoadTexture("resources/cyberpunk_street_background.png")
	midground: rl.Texture2D = rl.LoadTexture("resources/cyberpunk_street_midground.png")
	foreground: rl.Texture2D = rl.LoadTexture("resources/cyberpunk_street_foreground.png")

	scrollingBack: f32 = 0
	scrollingMid: f32 = 0
	scrollingFore: f32 = 0

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		scrollingBack -= 0.1
		scrollingMid -= 0.5
		scrollingFore -= 1

		// NOTE: Texture is scaled twice its size, so it sould be considered on scrolling
		if scrollingBack <= f32(-background.width*2) {
			scrollingBack = 0
		}
		if scrollingMid <= f32(-midground.width*2) {
			scrollingMid = 0
		}
		if scrollingFore <= f32(-foreground.width*2) {
			scrollingFore = 0
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.GetColor(0x052c46ff))

			// Draw background image twice
			// NOTE: Texture is scaled twice its size
			rl.DrawTextureEx(background, {scrollingBack, 20}, 0, 2, rl.WHITE)
			rl.DrawTextureEx(background, {f32(background.width*2) + scrollingBack, 20}, 0, 2, rl.WHITE)

			// Draw midground image twice
			rl.DrawTextureEx(midground, {scrollingMid, 20}, 0, 2, rl.WHITE)
			rl.DrawTextureEx(midground, {f32(midground.width*2) + scrollingMid, 20}, 0, 2, rl.WHITE)

			// Draw foreground image twice
			rl.DrawTextureEx(foreground, {scrollingFore, 70}, 0, 2, rl.WHITE)
			rl.DrawTextureEx(foreground, {f32(foreground.width*2) + scrollingFore, 70}, 0, 2, rl.WHITE)

			rl.DrawText("BACKGROUND SCROLLING & PARALLAX", 10, 10, 20, rl.RED)
			rl.DrawText("(c) Cyberpunk Street Environment by Luis Zuno (@ansimuz)", screenWidth - 330, screenHeight - 20, 10, rl.RAYWHITE)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.UnloadTexture(background)  // Unload background texture
	rl.UnloadTexture(midground)   // Unload midground texture
	rl.UnloadTexture(foreground)  // Unload foreground texture

	rl.CloseWindow()              // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}