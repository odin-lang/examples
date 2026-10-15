/*******************************************************************************************
*
*   raylib [textures] example - mouse painting
*
*   Example complexity rating: [★★★☆] 3/4
*
*   Example originally created with raylib 3.0, last time updated with raylib 6.0
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2019-2025 Chris Dill (@MysteriousSpace) and Ramon Santamaria (@raysan5)
*
********************************************************************************************/
package raylib_examples

import "core:c"
import rl "vendor:raylib"

MAX_COLORS_COUNT :: 23          // Number of colors available

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//--------------------------------------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [textures] example - mouse painting")

	// Colors to choose from
	colors := [MAX_COLORS_COUNT]rl.Color {
		rl.RAYWHITE, rl.YELLOW, rl.GOLD, rl.ORANGE, rl.PINK, rl.RED, rl.MAROON, rl.GREEN, rl.LIME, rl.DARKGREEN,
		rl.SKYBLUE, rl.BLUE, rl.DARKBLUE, rl.PURPLE, rl.VIOLET, rl.DARKPURPLE, rl.BEIGE, rl.BROWN, rl.DARKBROWN,
		rl.LIGHTGRAY, rl.GRAY, rl.DARKGRAY, rl.BLACK }

	// Define colors_recs data (for every rectangle)
	colors_recs :[MAX_COLORS_COUNT]rl.Rectangle
	for i := 0; i < MAX_COLORS_COUNT; i += 1 {
		colors_recs[i].x = f32(10 + 30.0*i + 2*i)
		colors_recs[i].y = 10
		colors_recs[i].width = 30
		colors_recs[i].height = 30
	}

	color_selected := 0
	color_selected_prev : int  = color_selected
	color_mouse_hover := 0
	brush_size := f32(20.0)
	mouse_was_pressed := false

	btn_save_rec := rl.Rectangle{ 750, 10, 40, 30 }
	btn_save_mouse_hover := false
	show_save_message := false
	save_message_counter := 0

	// Create a RenderTexture2D to use as a canvas
	target := rl.LoadRenderTexture(SCREEN_WIDTH, SCREEN_HEIGHT)

	// Clear render texture before entering the game loop
	rl.BeginTextureMode(target)
	rl.ClearBackground(colors[0])
	rl.EndTextureMode()

	rl.SetTargetFPS(120)              // Set our game to run at 120 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {   // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		mouse_pos := rl.GetMousePosition()

		// Move between colors with keys
		if rl.IsKeyPressed(.RIGHT) {
			color_selected += 1
		} else if rl.IsKeyPressed(.LEFT) {
			color_selected -= 1
		}

		if color_selected >= MAX_COLORS_COUNT {
			color_selected = MAX_COLORS_COUNT - 1
		} else if color_selected < 0 {
			color_selected = 0	
		} 

		// Choose color with mouse
		for i := 0; i < MAX_COLORS_COUNT; i += 1 {
			if (rl.CheckCollisionPointRec(mouse_pos, colors_recs[i])) {
				color_mouse_hover = i
				break
			} else {
				color_mouse_hover = -1
			}
		}

		if color_mouse_hover >= 0 && rl.IsMouseButtonPressed(.LEFT) {
			color_selected = color_mouse_hover
			color_selected_prev = color_selected
		}

		// Change brush size
		brush_size += rl.GetMouseWheelMove()*5
		if brush_size < 2 {
			brush_size = 2
		}
		if brush_size > 50 {
			brush_size = 50
		}

		if rl.IsKeyPressed(.C) {
			// Clear render texture to clear color
			rl.BeginTextureMode(target)
			rl.ClearBackground(colors[0])
			rl.EndTextureMode()
		}

		if rl.IsMouseButtonDown(.LEFT) || rl.IsGestureDetected(.DRAG) {
			// Paint circle into render texture
			// NOTE: To avoid discontinuous circles, we could store
			// previous-next mouse points and just draw a line using brush size
			rl.BeginTextureMode(target)
			if mouse_pos.y > 50 {
				rl.DrawCircle(c.int(mouse_pos.x), c.int(mouse_pos.y), brush_size, colors[color_selected])
			}
			rl.EndTextureMode()
		}

		if rl.IsMouseButtonDown(.RIGHT) {
			if !mouse_was_pressed {
				color_selected_prev = color_selected
				color_selected = 0
			}

			mouse_was_pressed = true

			// Erase circle from render texture
			rl.BeginTextureMode(target)
			if mouse_pos.y > 50 {
				rl.DrawCircle(c.int(mouse_pos.x), c.int(mouse_pos.y), brush_size, colors[0])
			}
			rl.EndTextureMode()
		} else if rl.IsMouseButtonReleased(.RIGHT) && mouse_was_pressed {
			color_selected = color_selected_prev
			mouse_was_pressed = false
		}

		// Check mouse hover save button
		if rl.CheckCollisionPointRec(mouse_pos, btn_save_rec) {
			btn_save_mouse_hover = true
		} else {
			btn_save_mouse_hover = false
		}

		// Image saving logic
		// NOTE: Saving painted texture to a default named image
		if (btn_save_mouse_hover && rl.IsMouseButtonReleased(.LEFT)) || rl.IsKeyPressed(.S) {
			image := rl.LoadImageFromTexture(target.texture)
			rl.ImageFlipVertical(&image)
			rl.ExportImage(image, "my_amazing_texture_painting.png")
			rl.UnloadImage(image)
			show_save_message = true
		}

		if show_save_message {
			// On saving, show a full screen message for 2 seconds
			save_message_counter += 1
			if (save_message_counter > 240) {
				show_save_message = false
				save_message_counter = 0
			}
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		// NOTE: Render texture must be y-flipped due to default OpenGL coordinates (left-bottom)
		rl.DrawTextureRec(target.texture, rl.Rectangle{ 0, 0, f32(target.texture.width), f32(-target.texture.height) }, rl.Vector2 { 0, 0 }, rl.WHITE)

		// Draw drawing circle for reference
		if mouse_pos.y > 50 {
			if rl.IsMouseButtonDown(.RIGHT) {
				rl.DrawCircleLines(c.int(mouse_pos.x), c.int(mouse_pos.y), brush_size, rl.GRAY)
			} else {
				rl.DrawCircle(rl.GetMouseX(), rl.GetMouseY(), brush_size, colors[color_selected])
			}
		}

		// Draw top panel
		rl.DrawRectangle(0, 0, rl.GetScreenWidth(), 50, rl.RAYWHITE)
		rl.DrawLine(0, 50, rl.GetScreenWidth(), 50, rl.LIGHTGRAY)

		// Draw color selection rectangles
		for i := 0; i < MAX_COLORS_COUNT; i += 1 {
			rl.DrawRectangleRec(colors_recs[i], colors[i])
		}
		rl.DrawRectangleLines(10, 10, 30, 30, rl.LIGHTGRAY)

		if color_mouse_hover >= 0 {
			rl.DrawRectangleRec(colors_recs[color_mouse_hover], rl.Fade(rl.WHITE, 0.6))
		}

		rl.DrawRectangleLinesEx(rl.Rectangle{ colors_recs[color_selected].x - 2, colors_recs[color_selected].y - 2,
							 colors_recs[color_selected].width + 4, colors_recs[color_selected].height + 4 }, 2, rl.BLACK)

		// Draw save image button
		rl.DrawRectangleLinesEx(btn_save_rec, 2, btn_save_mouse_hover ? rl.RED : rl.BLACK)
		rl.DrawText("SAVE!", 755, 20, 10, btn_save_mouse_hover ? rl.RED : rl.BLACK)

		// Draw save image message
		if show_save_message {
			rl.DrawRectangle(0, 0, rl.GetScreenWidth(), rl.GetScreenHeight(), rl.Fade(rl.RAYWHITE, 0.8))
			rl.DrawRectangle(0, 150, rl.GetScreenWidth(), 80, rl.BLACK)
			rl.DrawText("IMAGE SAVED!", 150, 180, 20, rl.RAYWHITE)
		}

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.UnloadRenderTexture(target)    // Unload render texture

	rl.CloseWindow()                  // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}