package raylib_examples

/*******************************************************************************************
*
*   raylib [shapes] example - Colors palette
*
*   This example was originally created in C with raylib 1.0, and updated with raylib 2.5
*   before being translated to Odin.
*
*   The original example in C can be found on raylib.com at:
*
*   https://www.raylib.com/examples/shapes/loader.html?name=shapes_colors_palette
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

Color_And_Name :: struct{
	color: rl.Color,
	name:  cstring,
}

COLORS_AND_NAMES :: [?]Color_And_Name {
	{rl.DARKGRAY,   "DARKGRAY"},
	{rl.MAROON,     "MAROON"},
	{rl.ORANGE,     "ORANGE"},
	{rl.DARKGREEN,  "DARKGREEN"},
	{rl.DARKBLUE,   "DARKBLUE"},
	{rl.DARKPURPLE, "DARKPURPLE"},
	{rl.DARKBROWN,  "DARKBROWN"},
	{rl.GRAY,       "GRAY"},
	{rl.RED,        "RED"},
	{rl.GOLD,       "GOLD"},
	{rl.LIME,       "LIME"},
	{rl.BLUE,       "BLUE"},
	{rl.VIOLET,     "VIOLET"},
	{rl.BROWN,      "BROWN"},
	{rl.LIGHTGRAY,  "LIGHTGRAY"},
	{rl.PINK,       "PINK"},
	{rl.YELLOW,     "YELLOW"},
	{rl.GREEN,      "GREEN"},
	{rl.SKYBLUE,    "SKYBLUE"},
	{rl.PURPLE,     "PURPLE"},
	{rl.BEIGE,      "BEIGE"},
}

NUMBER_OF_COLORS :: len(COLORS_AND_NAMES)

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

color_rects: [NUMBER_OF_COLORS]rl.Rectangle

@(init) // Calls this proc once before main.
initialize_colors_rects :: proc "contextless" () {
	// Initial rectangle geometry data in colors_rects.
	for i in 0..<len(color_rects) {
		color_rects[i].x      = 20 + 100 * f32(i % 7) + 10 * f32(i % 7)
		color_rects[i].y      = 80 + 100 * f32(i / 7) + 10 * f32(i / 7)
		color_rects[i].width  = 100
		color_rects[i].height = 100
	}
}

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - colors palette")
	defer rl.CloseWindow() // Close window and OpenGL context when leaving main.

	color_state: [NUMBER_OF_COLORS]bool // Represents if the mouse is hovering over a rect.
	mouse_pos: rl.Vector2
	rl.SetTargetFPS(60) // Set frames per second.

	// The primary loop.
	for !rl.WindowShouldClose() { // Detect window close button or ESC key press.
		mouse_pos = rl.GetMousePosition()

		// Set mouse-hover information.
		#assert(len(color_state) == len(color_rects))
		for &state, i in color_state {
			state = rl.CheckCollisionPointRec(mouse_pos, color_rects[i])
		}

		// Start drawing.
		rl.BeginDrawing()

		// Background and background text.
		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawText("raylib colors palette", 28, 42, 20, rl.BLACK)
		rl.DrawText("press SPACE to see all colors", rl.GetScreenWidth() - 180, rl.GetScreenHeight() - 40, 10, rl.GRAY)

		// Draw rectangles.
		#assert(len(COLORS_AND_NAMES) == len(color_rects))
		#assert(len(COLORS_AND_NAMES) == len(color_state))
		for color_and_name, i in COLORS_AND_NAMES {
			color, name := color_and_name.color, color_and_name.name
			rl.DrawRectangleRec(color_rects[i], rl.Fade(color, color_state[i] ? 0.6 : 1))
			if rl.IsKeyDown(rl.KeyboardKey.SPACE) || color_state[i] {
				crect := color_rects[i]
				rl.DrawRectangle(i32(crect.x), i32(crect.y + crect.height) - 26, i32(crect.width), 20, rl.BLACK)
				rl.DrawRectangleLinesEx(crect, 6, rl.Fade(rl.BLACK, 0.3))
				rl.DrawText(name, i32(crect.x + crect.width) - rl.MeasureText(name, 10) - 12, i32(crect.y + crect.height) - 20, 10, color)
			}
		}
		rl.EndDrawing()
	}
}
