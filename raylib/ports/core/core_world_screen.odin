/*******************************************************************************************
*
*   raylib [core] example - world screen
*
*   Example complexity rating: [★★☆☆] 2/4
*
*   Example originally created with raylib 1.3, last time updated with raylib 1.4
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [core] example - world screen")
	defer rl.CloseWindow()        // Close window and OpenGL context

	// Define the camera to look into our 3d world
	camera := rl.Camera {
		position = {10, 10, 10}, // Camera position
		//target = {0, 0, 0},      // Camera looking at point
		up = {0, 1, 0},          // Camera up vector (rotation towards target)
		fovy = 45,                                // Camera field-of-view Y
		projection = .PERSPECTIVE,             // Camera projection type
	}

	cube_position: rl.Vector3
	cube_screen_position: rl.Vector2

	rl.DisableCursor()                    // Limit cursor to relative movement inside the window

	rl.SetTargetFPS(60)                   // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for (!rl.WindowShouldClose()) {        // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		rl.UpdateCamera(&camera, .THIRD_PERSON)

		// Calculate cube screen space position (with a little offset to be in top)
		cube_screen_position = rl.GetWorldToScreen({cube_position.x, cube_position.y + 2.5, cube_position.z}, camera)
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.BeginMode3D(camera)

				rl.DrawCube(cube_position, 2, 2, 2, rl.RED)
				rl.DrawCubeWires(cube_position, 2, 2, 2, rl.MAROON)

				rl.DrawGrid(10, 1)

			rl.EndMode3D()

			rl.DrawText("Enemy: 100/100", i32(cube_screen_position.x - f32(rl.MeasureText("Enemy: 100/100", 20)/2)), i32(cube_screen_position.y), 20, rl.BLACK)

			rl.DrawText(rl.TextFormat("Cube position in screen space coordinates: [%i, %i]", i32(cube_screen_position.x), i32(cube_screen_position.y)), 10, 10, 20, rl.LIME)
			rl.DrawText("Text 2d should be always on top of the cube", 10, 40, 20, rl.GRAY)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	
	//--------------------------------------------------------------------------------------
}