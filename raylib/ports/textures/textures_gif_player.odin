package main

import rl "vendor:raylib"

MAX_FRAME_DELAY :: 20
MIN_FRAME_DELAY :: 1

main :: proc() {
	screen_width  := i32(800)
	screen_height := i32(450)

	rl.InitWindow(screen_width, screen_height, "raylib [textures] example - gif playing")
	defer rl.CloseWindow()

	anim_frames: i32
	im_scarfy_anim := rl.LoadImageAnim("resources/scarfy_run.gif", &anim_frames)
	defer rl.UnloadImage(im_scarfy_anim)

	tex_scarfy_anim := rl.LoadTextureFromImage(im_scarfy_anim)
	defer rl.UnloadTexture(tex_scarfy_anim)

	next_frame_data_offset, current_anim_frame, frame_counter: i32
	frame_delay := i32(MAX_FRAME_DELAY/2)

	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		frame_counter += 1
		if frame_counter >= frame_delay {
			current_anim_frame = (current_anim_frame + 1) % anim_frames

			next_frame_data_offset = im_scarfy_anim.width * im_scarfy_anim.height * 4 * current_anim_frame

			rl.UpdateTexture(tex_scarfy_anim, ([^]byte)(im_scarfy_anim.data)[next_frame_data_offset:])

			frame_counter = 0
		}

		if rl.IsKeyPressed(.RIGHT) {
			frame_delay = min(frame_delay + 1, MAX_FRAME_DELAY)
		} else if rl.IsKeyPressed(.LEFT) {
			frame_delay = max(frame_delay - 1, MIN_FRAME_DELAY)
		}

		{
			rl.BeginDrawing()
			defer rl.EndDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.DrawText(rl.TextFormat("TOTAL GIF FRAMES: %02i", anim_frames), 50, 30, 20, rl.LIGHTGRAY)
			rl.DrawText(rl.TextFormat("CURRENT FRAME: %02i", current_anim_frame), 50, 60, 20, rl.GRAY)
			rl.DrawText(rl.TextFormat("CURRENT FRAME IMAGE.DATA OFFSET: %02i", next_frame_data_offset), 50, 90, 20, rl.GRAY)

			rl.DrawText("FRAMES DELAY: ", 100, 305, 10, rl.DARKGRAY)
			rl.DrawText(rl.TextFormat("%02i frames", frame_delay), 620, 305, 10, rl.DARKGRAY)
			rl.DrawText("PRESS RIGHT/LEFT KEYS to CHANGE SPEED!", 290, 350, 10, rl.DARKGRAY)

			for i in i32(0)..<MAX_FRAME_DELAY {
				if i < frame_delay {
					rl.DrawRectangle(190 + 21*i, 300, 20, 20, rl.RED)
				}
				rl.DrawRectangleLines(190 + 21*i, 300, 20, 20, rl.MAROON)
			}

			rl.DrawTexture(tex_scarfy_anim, rl.GetScreenWidth()/2 - tex_scarfy_anim.width/2, 140, rl.WHITE)

			rl.DrawText("(c) Scarfy sprite by Eiden Marsal", screen_width - 200, screen_height - 20, 10, rl.GRAY)
		}
	}
}
