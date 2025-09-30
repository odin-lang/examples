/*******************************************************************************************
*
*   raylib [core] example - input mouse wheel
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 1.1, last time updated with raylib 1.3
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
main :: proc()
{
    // Initialization
    //--------------------------------------------------------------------------------------
    screenWidth :: 800
    screenHeight :: 450

    rl.InitWindow(screenWidth, screenHeight, "raylib [core] example - input mouse wheel")

	boxPositionY: int = screenHeight/2 - 40
    scrollSpeed: int = 4            // Scrolling speed in pixels

    rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    for (!rl.WindowShouldClose())    // Detect window close button or ESC key
    {
        // Update
        //----------------------------------------------------------------------------------
        boxPositionY -= int(rl.GetMouseWheelMove()*f32(scrollSpeed))
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing()

            rl.ClearBackground(rl.RAYWHITE)

            rl.DrawRectangle(screenWidth/2 - 40, i32(boxPositionY), 80, 80, rl.MAROON)

            rl.DrawText("Use mouse wheel to move the cube up and down!", 10, 10, 20, rl.GRAY)
            rl.DrawText(rl.TextFormat("Box position Y: %03i", boxPositionY), 10, 40, 20, rl.LIGHTGRAY)

        rl.EndDrawing()
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.CloseWindow()        // Close window and OpenGL context
    //--------------------------------------------------------------------------------------
}