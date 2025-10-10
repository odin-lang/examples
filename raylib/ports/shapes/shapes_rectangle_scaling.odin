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
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - rectangle scaling")
	defer rl.CloseWindow()        // Close window and OpenGL context

	rec := rl.Rectangle {100, 100, 200, 80}

	mouse_position: rl.Vector2

	mouse_scale_ready: bool
	mouse_scale_mode: bool

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		mouse_position = rl.GetMousePosition()

		if rl.CheckCollisionPointRec(mouse_position, {rec.x + rec.width - MOUSE_SCALE_MARK_SIZE, rec.y + rec.height - MOUSE_SCALE_MARK_SIZE, MOUSE_SCALE_MARK_SIZE, MOUSE_SCALE_MARK_SIZE}) {
			mouse_scale_ready = true
			if rl.IsMouseButtonPressed(.LEFT) {
				mouse_scale_mode = true
			}
		} else {
			mouse_scale_ready = false
		}

		if mouse_scale_mode {
			mouse_scale_ready = true

			rec.width = (mouse_position.x - rec.x)
			rec.height = (mouse_position.y - rec.y)

			// Check minimum rec size
			if rec.width < MOUSE_SCALE_MARK_SIZE {
				rec.width = MOUSE_SCALE_MARK_SIZE
			}
			if rec.height < MOUSE_SCALE_MARK_SIZE {
				rec.height = MOUSE_SCALE_MARK_SIZE
			}

			// Check maximum rec size
			if rec.width > (f32(rl.GetScreenWidth()) - rec.x) {
				rec.width = f32(rl.GetScreenWidth()) - rec.x
			}
			if rec.height > (f32(rl.GetScreenHeight()) - rec.y) {
				rec.height = f32(rl.GetScreenHeight()) - rec.y
			}

			if rl.IsMouseButtonReleased(.LEFT) {
				mouse_scale_mode = false
			}
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawText("Scale rectangle dragging from bottom-right corner!", 10, 10, 20, rl.GRAY)

			rl.DrawRectangleRec(rec, rl.Fade(rl.GREEN, 0.5))

			if mouse_scale_ready {
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
	
	//--------------------------------------------------------------------------------------
}