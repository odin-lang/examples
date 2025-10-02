/*******************************************************************************************
*
*   raylib [textures] example - npatch drawing
*
*   Example complexity rating: [★★★☆] 3/4
*
*   NOTE: Images are loaded in CPU memory (RAM); textures are loaded in GPU memory (VRAM)
*
*   Example originally created with raylib 2.0, last time updated with raylib 2.5
*
*   Example contributed by Jorge A. Gomes (@overdev) and reviewed by Ramon Santamaria (@raysan5)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2018-2025 Jorge A. Gomes (@overdev) and Ramon Santamaria (@raysan5)
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [textures] example - npatch drawing")
	defer rl.CloseWindow()                // Close window and OpenGL context

	// NOTE: Textures MUST be loaded after Window initialization (OpenGL context is required)
	n_patch_texture := rl.LoadTexture("resources/ninepatch_button.png")
	defer rl.UnloadTexture(n_patch_texture)       // Texture unloading

	mouse_position: rl.Vector2
	origin: rl.Vector2

	// Position and size of the n-patches
	dstRec1 := rl.Rectangle {480, 160, 32, 32}
	dstRec2 := rl.Rectangle {160, 160, 32, 32}
	dstRecH := rl.Rectangle {160, 93, 32, 32}
	dstRecV := rl.Rectangle {92, 160, 32, 32}

	// A 9-patch (NPATCH_NINE_PATCH) changes its sizes in both axis
	nine_patch_info_1 := rl.NPatchInfo {{0, 0, 64, 64}, 12, 40, 12, 12, .NINE_PATCH}
	nine_patch_info_2 := rl.NPatchInfo {{0, 128, 64, 64}, 16, 16, 16, 16, .NINE_PATCH}

	// A horizontal 3-patch (NPATCH_THREE_PATCH_HORIZONTAL) changes its sizes along the x axis only
	h3_patch_info := rl.NPatchInfo {{0, 64, 64, 64}, 8, 8, 8, 8, .THREE_PATCH_HORIZONTAL}

	// A vertical 3-patch (NPATCH_THREE_PATCH_VERTICAL) changes its sizes along the y axis only
	v3_patch_info := rl.NPatchInfo {{0, 192, 64, 64}, 6, 6, 6, 6, .THREE_PATCH_VERTICAL}

	rl.SetTargetFPS(60)
	//---------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		mouse_position = rl.GetMousePosition()

		// Resize the n-patches based on mouse position
		dstRec1.width = mouse_position.x - dstRec1.x
		dstRec1.height = mouse_position.y - dstRec1.y
		dstRec2.width = mouse_position.x - dstRec2.x
		dstRec2.height = mouse_position.y - dstRec2.y
		dstRecH.width = mouse_position.x - dstRecH.x
		dstRecV.height = mouse_position.y - dstRecV.y

		// Set a minimum width and/or height
		if dstRec1.width < 1 {
			dstRec1.width = 1
		}
		if dstRec1.width > 300 {
			dstRec1.width = 300
		}
		if dstRec1.height < 1 {
			dstRec1.height = 1
		}
		if dstRec2.width < 1 {
			dstRec2.width = 1
		}
		if dstRec2.width > 300 {
			dstRec2.width = 300
		}
		if dstRec2.height < 1 {
			dstRec2.height = 1
		}
		if dstRecH.width < 1 {
			dstRecH.width = 1
		}
		if dstRecV.height < 1 {
			dstRecV.height = 1
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			// Draw the n-patches
			rl.DrawTextureNPatch(n_patch_texture, nine_patch_info_2, dstRec2, origin, 0, rl.WHITE)
			rl.DrawTextureNPatch(n_patch_texture, nine_patch_info_1, dstRec1, origin, 0, rl.WHITE)
			rl.DrawTextureNPatch(n_patch_texture, h3_patch_info, dstRecH, origin, 0, rl.WHITE)
			rl.DrawTextureNPatch(n_patch_texture, v3_patch_info, dstRecV, origin, 0, rl.WHITE)

			// Draw the source texture
			rl.DrawRectangleLines(5, 88, 74, 266, rl.BLUE)
			rl.DrawTexture(n_patch_texture, 10, 93, rl.WHITE)
			rl.DrawText("TEXTURE", 15, 360, 10, rl.DARKGRAY)

			rl.DrawText("Move the mouse to stretch or shrink the n-patches", 10, 20, 20, rl.DARKGRAY)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
}