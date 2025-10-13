package text_codepoints_loading

/*******************************************************************************************
*
*   raylib [text] example - Codepoints loading
*
*   This example was originally created with raylib 4.2 in C, last time updated with raylib 2.5
*   The original example in C can be found on raylib.com at:
*
*   https://www.raylib.com/examples/text/loader.html?name=text_codepoints_loading
*
*   raylib is licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software. The license
*   can be found in its entirety as part of the standard Odin distribution at:
*
*   /vendor/raylib/LICENSE
*
*   or online at:
*
*   https://www.raylib.com/license.html
*
*   This example is licensed under an unmodified zlib/libpng license, which is an
*   OSI-certified, BSD-like license that allows static linking with closed source software.
*
*   Copyright (c) 2022-2024 Ramon Santamaria (@raysan5)
*
********************************************************************************************/


import rl "vendor:raylib"
import "core:slice"

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

// NOTE: It can contain all the required text for the game,
// this text will be scanned to get all the required codepoints
text: cstring = "いろはにほへと　ちりぬるを\nわかよたれそ　つねならむ\nうゐのおくやま　けふこえて\nあさきゆめみし　ゑひもせす"

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [text] example - codepoints loading")
	defer rl.CloseWindow()

	// Set our game to run at 60 frames-per-second
	rl.SetTargetFPS(60)

	codepoint_count: i32
	codepoints   := rl.LoadCodepoints(text, &codepoint_count)
	deduplicated := codepoints_remove_duplicates(codepoints[:codepoint_count])
	rl.UnloadCodepoints(codepoints)

	// Load font containing all the provided codepoint glyphs
	// A texture font atlas is automatically generated
	font := rl.LoadFontEx("resources/DotGothic16-Regular.ttf", 36, raw_data(deduplicated), i32(len(deduplicated)))
	defer rl.UnloadFont(font)

	// Free codepoints, atlas has already been generated
	delete(deduplicated)

	// Set bilinear scale filter for better font scaling
	rl.SetTextureFilter(font.texture, .BILINEAR)

	// Set line spacing for multiline text (when line breaks are included '\n')
	// NOTE: The original value of 20 results in overlapping glyphs
	// Here it's set to twice the point size we loaded the font with.
	rl.SetTextLineSpacing(72)

	showFontAtlas := false

	// Detect window close button or ESC key
	for !rl.WindowShouldClose() {
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsKeyPressed(.SPACE) {
			showFontAtlas = !showFontAtlas
		}

		// NOTE: The original example had unsafe code to scroll through
		// the text one codepoint at a time by adding/subtracting codepoint
		// size from the text pointer, without checking it remained within the
		// string. This offset `ptr` was not actually used in the rendering below,
		// and part of the example is therefore removed.

		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()
		defer rl.EndDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawRectangle(0, 0, rl.GetScreenWidth(), 70, rl.BLACK)
			rl.DrawText(rl.TextFormat("Total codepoints contained in provided text: %i", codepoint_count), 10, 10, 20, rl.GREEN)
			rl.DrawText(rl.TextFormat("Total codepoints required for font atlas (duplicates excluded): %i", i32(len(deduplicated))), 10, 40, 20, rl.GREEN)

			if showFontAtlas {
				// Draw generated font texture atlas containing provided codepoints
				rl.DrawTexture(font.texture, 150, 100, rl.BLACK)
				rl.DrawRectangleLines(150, 100, font.texture.width, font.texture.height, rl.BLACK)
			} else {
				// Draw provided text with loaded font, containing all required codepoint glyphs
				rl.DrawTextEx(font, text, { 160, 110 }, 48, 5, rl.BLACK)
			}

			rl.DrawText("Press SPACE to toggle font atlas view!", 10, rl.GetScreenHeight() - 30, 20, rl.GRAY)
	}
}

// Remove codepoint duplicates if requested
codepoints_remove_duplicates :: proc (codepoints: []rune) -> (deduplicated: []rune) {
	deduplicated = slice.clone(codepoints)
	slice.sort(deduplicated)
	return slice.unique(deduplicated)
}