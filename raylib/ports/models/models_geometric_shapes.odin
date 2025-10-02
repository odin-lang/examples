/*******************************************************************************************
*
*   raylib [models] example - geometric shapes
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.0, last time updated with raylib 3.5
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2014-2025 Ramon Santamaria (@raysan5)
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

    rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [models] example - geometric shapes")
	defer rl.CloseWindow();        // Close window and OpenGL context

    // Define the camera to look into our 3d world
	camera := rl.Camera {
		position = {0, 10, 10},
		//target = {0, 0, 0},
		up = {0, 1, 0},
		fovy = 45,
		projection = .PERSPECTIVE,
	}

    rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    for !rl.WindowShouldClose() {    // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
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
                rl.DrawCylinderWires({4.5, -1, 2}, 1, 1, 2, 6, rl.BROWN)

                rl.DrawCylinder({1, 0, -4}, 0, 1.5, 3, 8, rl.GOLD)
                rl.DrawCylinderWires({1, 0, -4}, 0, 1.5, 3, 8, rl.PINK)

                rl.DrawCapsule     ({-3, 1.5, -4}, {-4, -1, -4}, 1.2, 8, 8, rl.VIOLET)
                rl.DrawCapsuleWires({-3, 1.5, -4}, {-4, -1, -4}, 1.2, 8, 8, rl.PURPLE)

                rl.DrawGrid(10, 1)        // Draw a grid

            rl.EndMode3D();

            rl.DrawFPS(10, 10);

        rl.EndDrawing();
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    
    //--------------------------------------------------------------------------------------
}