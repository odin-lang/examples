/*******************************************************************************************
*
*   raylib [core] example - 3d camera free
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.3, last time updated with raylib 1.3
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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [core] example - 3d camera free")

	// Define the camera to look into our 3d world
	camera: rl.Camera3D
	camera.position = {10, 10, 10} // Camera position
	camera.target = {0, 0, 0}      // Camera looking at point
	camera.up = {0, 1, 0}          // Camera up vector (rotation towards target)
	camera.fovy = 45                                // Camera field-of-view Y
	camera.projection = .PERSPECTIVE             // Camera projection type

	cube_position: rl.Vector3 = {0, 0, 0}

	rl.DisableCursor()                    // Limit cursor to relative movement inside the window

	rl.SetTargetFPS(60)                   // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for (!rl.WindowShouldClose()) {        // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		rl.UpdateCamera(&camera, .FREE)
		
		if (rl.IsKeyPressed(.Z)) {
			camera.target = {0, 0, 0}
		}
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

			rl.DrawRectangle( 10, 10, 320, 93, rl.Fade(rl.SKYBLUE, 0.5))
			rl.DrawRectangleLines( 10, 10, 320, 93, rl.BLUE)

			rl.DrawText("Free camera default controls:", 20, 20, 10, rl.BLACK)
			rl.DrawText("- Mouse Wheel to Zoom in-out", 40, 40, 10, rl.DARKGRAY)
			rl.DrawText("- Mouse Wheel Pressed to Pan", 40, 60, 10, rl.DARKGRAY)
			rl.DrawText("- Z to zoom to (0, 0, 0)", 40, 80, 10, rl.DARKGRAY)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}