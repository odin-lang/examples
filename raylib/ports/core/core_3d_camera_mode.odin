package core

/*******************************************************************************************
*
*   raylib [core] example - 3d camera mode
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.0, last time updated with raylib 1.0
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2014-2025 Ramon Santamaria (@raysan5)
*
********************************************************************************************/

import rl "vendor:raylib"

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc()
{
    // Initialization
    //--------------------------------------------------------------------------------------
    screenWidth :: 800
    screenHeight :: 450

    rl.InitWindow(screenWidth, screenHeight, "raylib [core] example - 3d camera mode")

    // Define the camera to look into our 3d world
    camera: rl.Camera3D
    camera.position = { 0, 10, 10 }  // Camera position
    camera.target = { 0, 0, 0 }      // Camera looking at point
    camera.up = { 0, 1, 0 }          // Camera up vector (rotation towards target)
    camera.fovy = 45                                // Camera field-of-view Y
    camera.projection = .PERSPECTIVE             // Camera mode type

    cubePosition: rl.Vector3 = { 0, 0, 0 }

    rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    for (!rl.WindowShouldClose())    // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------
        // TODO: Update your variables here
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()

            rl.ClearBackground(rl.RAYWHITE)

            rl.BeginMode3D(camera);

                rl.DrawCube(cubePosition, 2, 2, 2, rl.RED)
                rl.DrawCubeWires(cubePosition, 2, 2, 2, rl.MAROON)

                rl.DrawGrid(10, 1)

            rl.EndMode3D()

            rl.DrawText("Welcome to the third dimension!", 10, 40, 20, rl.DARKGRAY)

            rl.DrawFPS(10, 10)

        rl.EndDrawing()
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.CloseWindow()        // Close window and OpenGL context
    //--------------------------------------------------------------------------------------
}
