/*******************************************************************************************
*
*   raylib [models] example - orthographic projection
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 2.0, last time updated with raylib 3.7
*
*   Example contributed by Max Danielsson (@autious) and reviewed by Ramon Santamaria (@raysan5)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2018-2025 Max Danielsson (@autious) and Ramon Santamaria (@raysan5)
*
********************************************************************************************/

package raylib_examples

import rl "vendor:raylib"

FOVY_PERSPECTIVE :: 45
WIDTH_ORTHOGRAPHIC :: 10

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//--------------------------------------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [models] example - orthographic projection")

	// Define the camera to look into our 3d world
	camera := rl.Camera {
		position = {0, 10, 10},
		//target = {0, 0, 0},
		up = {0, 1, 0},
		fovy = FOVY_PERSPECTIVE,
		projection = .PERSPECTIVE,
	}

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsKeyPressed(.SPACE) {
			if camera.projection == .PERSPECTIVE {
				camera.fovy = WIDTH_ORTHOGRAPHIC
				camera.projection = .ORTHOGRAPHIC
			} else {
				camera.fovy = FOVY_PERSPECTIVE
				camera.projection = .PERSPECTIVE
			}
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.BeginMode3D(camera)

				rl.DrawCube({-4, 0, 2}, 2, 5, 2, rl.RED)
				rl.DrawCubeWires({-4, 0, 2}, 2, 5, 2, rl.GOLD)
				rl.DrawCubeWires({-4, 0, -2}, 3, 6, 2, rl.MAROON)

				rl.DrawSphere({-1, 0, -2}, 1, rl.GREEN)
				rl.DrawSphereWires({1, 0, 2}, 2, 16, 16, rl.LIME)

				rl.DrawCylinder({4, 0, -2}, 1, 2, 3, 4, rl.SKYBLUE)
				rl.DrawCylinderWires({4, 0, -2}, 1, 2, 3, 4, rl.DARKBLUE)
				rl.DrawCylinderWires({4, -1, 2}, 1, 1, 2, 6, rl.BROWN)

				rl.DrawCylinder({1, 0, -4}, 0, 1.5, 3, 8, rl.GOLD)
				rl.DrawCylinderWires({1, 0, -4}, 0, 1.5, 3, 8, rl.PINK)

				rl.DrawGrid(10, 1)        // Draw a grid

			rl.EndMode3D()

			rl.DrawText("Press Spacebar to switch camera type", 10, rl.GetScreenHeight() - 30, 20, rl.DARKGRAY)

			if camera.projection == .ORTHOGRAPHIC {
				rl.DrawText("ORTHOGRAPHIC", 10, 40, 20, rl.BLACK)
			} else if camera.projection == .PERSPECTIVE {
				rl.DrawText("PERSPECTIVE", 10, 40, 20, rl.BLACK)
			}

			rl.DrawFPS(10, 10)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}