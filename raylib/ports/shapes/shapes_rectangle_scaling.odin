/*******************************************************************************************
*
*   raylib [shapes] example - rectangle scaling
*
*   Example complexity rating: [★★☆☆] 2/4
*
*   Example originally created with raylib 2.5, last time updated with raylib 2.5
*
*   Example contributed by Vlad Adrian (@demizdor) and reviewed by Ramon Santamaria (@raysan5)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2018-2025 Vlad Adrian (@demizdor) and Ramon Santamaria (@raysan5)
*
********************************************************************************************/

package raylib_examples

import rl "vendor:raylib"

MOUSE_SCALE_MARK_SIZE :: 12

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//--------------------------------------------------------------------------------------
	screenWidth :: 800
	screenHeight :: 450

	rl.InitWindow(screenWidth, screenHeight, "raylib [shapes] example - rectangle scaling")

	rec: rl.Rectangle = {100, 100, 200, 80}

	mousePosition: rl.Vector2

	mouseScaleReady: bool
	mouseScaleMode: bool

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for (!rl.WindowShouldClose()) {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		mousePosition = rl.GetMousePosition()

		if (rl.CheckCollisionPointRec(mousePosition, {rec.x + rec.width - MOUSE_SCALE_MARK_SIZE, rec.y + rec.height - MOUSE_SCALE_MARK_SIZE, MOUSE_SCALE_MARK_SIZE, MOUSE_SCALE_MARK_SIZE})) {
			mouseScaleReady = true
			if (rl.IsMouseButtonPressed(.LEFT)) {
				mouseScaleMode = true
			}
		} else {
			mouseScaleReady = false
		}

		if (mouseScaleMode) {
			mouseScaleReady = true

			rec.width = (mousePosition.x - rec.x)
			rec.height = (mousePosition.y - rec.y)

			// Check minimum rec size
			if (rec.width < MOUSE_SCALE_MARK_SIZE) {
				rec.width = MOUSE_SCALE_MARK_SIZE
			}
			if (rec.height < MOUSE_SCALE_MARK_SIZE) {
				rec.height = MOUSE_SCALE_MARK_SIZE
			}

			// Check maximum rec size
			if (rec.width > (f32(rl.GetScreenWidth()) - rec.x)) {
				rec.width = f32(rl.GetScreenWidth()) - rec.x
			}
			if (rec.height > (f32(rl.GetScreenHeight()) - rec.y)) {
				rec.height = f32(rl.GetScreenHeight()) - rec.y
			}

			if (rl.IsMouseButtonReleased(.LEFT)) {
				mouseScaleMode = false
			}
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawText("Scale rectangle dragging from bottom-right corner!", 10, 10, 20, rl.GRAY)

			rl.DrawRectangleRec(rec, rl.Fade(rl.GREEN, 0.5))

			if (mouseScaleReady) {
				rl.DrawRectangleLinesEx(rec, 1, rl.RED)
				rl.DrawTriangle({rec.x + rec.width - MOUSE_SCALE_MARK_SIZE, rec.y + rec.height},
							 {rec.x + rec.width, rec.y + rec.height},
							 {rec.x + rec.width, rec.y + rec.height - MOUSE_SCALE_MARK_SIZE}, rl.RED)
			}

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}