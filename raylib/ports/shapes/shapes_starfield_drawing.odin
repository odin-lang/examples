package shapes

/*******************************************************************************************
*
*   raylib [shapes] example - starfield drawing
*
*   Example complexity rating: [★★☆☆] 2/4
*
*   Example originally created with raylib 5.5, last time updated with raylib 5.6
*
*   Example contributed by Robin (@RobinsAviary) and reviewed by Ramon Santamaria (@raysan5)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2025-2025 Robin (@RobinsAviary)
*
********************************************************************************************/

import rl "vendor:raylib"

Star :: struct {
	position: rl.Vector2,
}

stars: [50]Star

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc()
{
    // Initialization
    //--------------------------------------------------------------------------------------
    screenWidth :: 800;
    screenHeight :: 450;

    rl.InitWindow(screenWidth, screenHeight, "raylib [shapes] example - starfield drawing");

    for i: uint = 0; i < len(stars); i += 1 {
		star: ^Star = &stars[i]
		
		star.position = {f32(rl.GetRandomValue(0, screenWidth)), f32(rl.GetRandomValue(0, screenHeight))}
	}

    rl.SetTargetFPS(60);
    //--------------------------------------------------------------------------------------

    // Main game loop
    for (!rl.WindowShouldClose())    // Detect window close button or ESC key
    {
        // Update
        

        // Draw
        //----------------------------------------------------------------------------------
        rl.BeginDrawing();

            rl.ClearBackground(rl.BLACK);
			
			for star in stars {
				rl.DrawPixelV(star.position, rl.WHITE)
			}

        rl.EndDrawing();
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
    rl.CloseWindow();        // Close window and OpenGL context
    //--------------------------------------------------------------------------------------
}