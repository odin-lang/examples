/*******************************************************************************************
*
*   raylib [shapes] example - following eyes
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

import "core:math"       // Required for: math.atan2()

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//--------------------------------------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - following eyes")

	sclera_left_position: rl.Vector2 = {SCREEN_WIDTH/2 - 100, SCREEN_HEIGHT/2}
	sclera_right_position: rl.Vector2 = {SCREEN_WIDTH/2 + 100, SCREEN_HEIGHT/2}
	sclera_radius: f32 = 80

	iris_left_position: rl.Vector2 = {SCREEN_WIDTH/2 - 100, SCREEN_HEIGHT/2}
	iris_right_position: rl.Vector2 = {SCREEN_WIDTH/2 + 100, SCREEN_HEIGHT/2}
	iris_radius: f32 = 24

	angle, dx, dy, dxx, dyy: f32 // Initialized to zero.

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for (!rl.WindowShouldClose()) {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		iris_left_position = rl.GetMousePosition()
		iris_right_position = rl.GetMousePosition()

		// Check not inside the left eye sclera
		if (!rl.CheckCollisionPointCircle(iris_left_position, sclera_left_position, sclera_radius - iris_radius)) {
			dx = iris_left_position.x - sclera_left_position.x
			dy = iris_left_position.y - sclera_left_position.y

			angle = math.atan2(dy, dx)

			dxx = (sclera_radius - iris_radius)*math.cos(angle)
			dyy = (sclera_radius - iris_radius)*math.sin(angle)

			iris_left_position.x = sclera_left_position.x + dxx
			iris_left_position.y = sclera_left_position.y + dyy
		}

		// Check not inside the right eye sclera
		if (!rl.CheckCollisionPointCircle(iris_right_position, sclera_right_position, sclera_radius - iris_radius)) {
			dx = iris_right_position.x - sclera_right_position.x
			dy = iris_right_position.y - sclera_right_position.y

			angle = math.atan2(dy, dx)

			dxx = (sclera_radius - iris_radius)*math.cos(angle)
			dyy = (sclera_radius - iris_radius)*math.sin(angle)

			iris_right_position.x = sclera_right_position.x + dxx
			iris_right_position.y = sclera_right_position.y + dyy
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawCircleV(sclera_left_position, sclera_radius, rl.LIGHTGRAY)
			rl.DrawCircleV(iris_left_position, iris_radius, rl.BROWN)
			rl.DrawCircleV(iris_left_position, 10, rl.BLACK)

			rl.DrawCircleV(sclera_right_position, sclera_radius, rl.LIGHTGRAY)
			rl.DrawCircleV(iris_right_position, iris_radius, rl.DARKGREEN)
			rl.DrawCircleV(iris_right_position, 10, rl.BLACK)

			rl.DrawFPS(10, 10)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}