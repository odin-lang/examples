package raylib_examples

/*******************************************************************************************
*
*   raylib [shapes] example - Draw basic shapes 2d (rectangle, circle, line...)
*
*   This example was originally created in C with raylib 1.0, and updated with raylib 4.2
*   before being translated to Odin.
*
*   The original example in C can be found on raylib.com at:
*
*   https://www.raylib.com/examples/shapes/loader.html?name=shapes_basic_shapes
*
*   raylib is licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software. The license
*   can be found in its entirety as part of the standard Odin distribution at:
*
*   /vendor/raylib/LICENSE
*
*   or online at:
*
*   https://www.raylib.com/license.html
*
*   This example is licensed under an unmodified zlib/libpng license, which is an
*   OSI-certified, BSD-like license that allows static linking with closed source software.
*
*   Copyright (c) 2014-2023 Ramon Santamaria (@raysan5)
*   Copyright (c) 2023 Benjamin G. Thompson (@bg-thompson)
*
********************************************************************************************/

import rl "vendor:raylib"

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - basic shapes drawing")
	defer rl.CloseWindow() // Close window and OpenGL context when leaving main.

	rotation: f32 = 0
	rl.SetTargetFPS(60) // Set frames per second.

	// The primary loop.
	for !rl.WindowShouldClose() { // Detect window close button or ESC key press.
		rotation += 0.2

		// Start drawing.
		rl.BeginDrawing()

		// Draw background and text.
		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawText("some basic shapes available on raylib", 20, 20, 20, rl.DARKGRAY)

		// Draw circle shapes and lines.
		rl.DrawCircle(SCREEN_WIDTH / 5, 120, 35, rl.DARKBLUE)
		rl.DrawCircleGradient(SCREEN_WIDTH / 5, 220, 60, rl.GREEN, rl.SKYBLUE)
		rl.DrawCircleLines(SCREEN_WIDTH / 5, 340, 80, rl.DARKBLUE)

		// Draw rectangle shapes and lines.
		rl.DrawRectangle(SCREEN_WIDTH / 4 * 2 - 60, 100, 120, 60, rl.RED)
		rl.DrawRectangleGradientH(SCREEN_WIDTH /4 * 2 - 90, 170, 180, 130, rl.MAROON, rl.GOLD)
		rl.DrawRectangleLines(SCREEN_WIDTH / 4 * 2 - 40, 320, 80, 60, rl.ORANGE) // NOTE: Uses QUADS internally, not lines.

		// Draw triangle shapes and lines.
		rl.DrawTriangle({SCREEN_WIDTH / 4 * 3, 80},
			{SCREEN_WIDTH / 4 * 3 - 60, 150},
			{SCREEN_WIDTH / 4 * 3 + 60, 150},
			rl.VIOLET)

		rl.DrawTriangleLines({SCREEN_WIDTH / 4 * 3, 160},
			{SCREEN_WIDTH / 4 * 3 - 20, 230},
			{SCREEN_WIDTH / 4 * 3 + 20, 230},
			rl.DARKBLUE)

		// Draw polygon shapes and lines.
		rl.DrawPoly({ SCREEN_WIDTH / 4 * 3, 330}, 6, 80, rotation, rl.BROWN)
		rl.DrawPolyLines({SCREEN_WIDTH / 4 * 3, 330}, 6, 90, rotation, rl.BROWN)
		rl.DrawPolyLinesEx({SCREEN_WIDTH / 4 * 3, 330}, 6, 85, rotation, 6, rl.BEIGE)

		// NOTE: We draw all LINES based shapes together to optimize internal drawing,
		// this way, all LINES are rendered in a single draw pass.
		rl.DrawLine(18, 42, SCREEN_WIDTH - 18, 42, rl.BLACK)
		rl.EndDrawing()
	}
}
