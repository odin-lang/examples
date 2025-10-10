/*******************************************************************************************
*
*   raylib [shapes] example - collision area
*
*   Example complexity rating: [★★☆☆] 2/4
*
*   Example originally created with raylib 2.5, last time updated with raylib 2.5
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2013-2025 Ramon Santamaria (@raysan5)
*
********************************************************************************************/

package raylib_examples

import rl "vendor:raylib"

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//---------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - collision area")
	defer rl.CloseWindow()        // Close window and OpenGL context

	// Box A: Moving box
	box_a := rl.Rectangle {10, f32(rl.GetScreenHeight())/2 - 50, 200, 100}
	box_a_speed_x: int = 4

	// Box B: Mouse moved box
	box_b := rl.Rectangle {f32(rl.GetScreenWidth())/2 - 30, f32(rl.GetScreenHeight())/2 - 30, 60, 60}

	box_collision: rl.Rectangle // Collision rectangle

	screen_upper_limit: i32 = 40      // Top menu limits

	pause: bool             // Movement pause
	collision: bool         // Collision detection

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//----------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//-----------------------------------------------------
		// Move box if not paused
		if !pause {
			box_a.x += f32(box_a_speed_x)
		}

		// Bounce box on x screen limits
		if (box_a.x + box_a.width) >= f32(rl.GetScreenWidth()) || box_a.x <= 0 {
			box_a_speed_x *= -1
		}

		// Update player-controlled-box (box02)
		box_b.x = f32(rl.GetMouseX()) - box_b.width/2
		box_b.y = f32(rl.GetMouseY()) - box_b.height/2

		// Make sure Box B does not go out of move area limits
		if box_b.x + box_b.width >= f32(rl.GetScreenWidth()) {
			box_b.x = f32(rl.GetScreenWidth()) - box_b.width
		} else if box_b.x <= 0 {
			box_b.x = 0
		}

		if box_b.y + box_b.height >= f32(rl.GetScreenHeight()) {
			box_b.y = f32(rl.GetScreenHeight()) - box_b.height
		} else if box_b.y <= f32(screen_upper_limit) {
			box_b.y = f32(screen_upper_limit)
		}

		// Check boxes collision
		collision = rl.CheckCollisionRecs(box_a, box_b)

		// Get collision rectangle (only on collision)
		if collision {
			box_collision = rl.GetCollisionRec(box_a, box_b)
		}

		// Pause Box A movement
		if rl.IsKeyPressed(.SPACE) {
			pause = !pause
		}
		//-----------------------------------------------------

		// Draw
		//-----------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawRectangle(0, 0, SCREEN_WIDTH, screen_upper_limit, collision? rl.RED : rl.BLACK)

			rl.DrawRectangleRec(box_a, rl.GOLD)
			rl.DrawRectangleRec(box_b, rl.BLUE)

			if collision {
				// Draw collision area
				rl.DrawRectangleRec(box_collision, rl.LIME)

				// Draw collision message
				rl.DrawText("COLLISION!", rl.GetScreenWidth()/2 - rl.MeasureText("COLLISION!", 20)/2, screen_upper_limit/2 - 10, 20, rl.BLACK)

				// Draw collision area
				rl.DrawText(rl.TextFormat("Collision Area: %i", i32(box_collision.width*box_collision.height)), rl.GetScreenWidth()/2 - 100, screen_upper_limit + 10, 20, rl.BLACK)
			}

			// Draw help instructions
			rl.DrawText("Press SPACE to PAUSE/RESUME", 20, SCREEN_HEIGHT - 35, 20, rl.LIGHTGRAY)

			rl.DrawFPS(10, 10)

		rl.EndDrawing()
		//-----------------------------------------------------
	}

	// De-Initialization
	//---------------------------------------------------------
	
	//----------------------------------------------------------
}