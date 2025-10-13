/*******************************************************************************************
*
*   raylib [textures] example - bunnymark
*
*   Example complexity rating: [★★★☆] 3/4
*
*   Example originally created with raylib 1.6, last time updated with raylib 2.5
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2014-2025 Ramon Santamaria (@raysan5)
*
********************************************************************************************/

package raylib_examples

import rl "vendor:raylib"

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------
Bunny :: struct {
	position: rl.Vector2,
	speed: rl.Vector2,
	color: rl.Color,
}

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//--------------------------------------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	MAX_BUNNIES :: 50000    // 50K bunnies limit

	// This is the maximum amount of elements (quads) per batch
	// NOTE: This value is defined in [rlgl] module and can be changed there
	MAX_BATCH_ELEMENTS :: 8192

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [textures] example - bunnymark")

	// Load bunny texture
	tex_bunny := rl.LoadTexture("resources/wabbit_alpha.png")

	bunnies: [dynamic]Bunny          // Bunnies array
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsMouseButtonDown(.LEFT) {
			for i := 0; i < 100; i += 1 {
				if len(bunnies) < MAX_BUNNIES {
					bunny: Bunny
					bunny.position = rl.GetMousePosition()
					bunny.speed.x = f32(rl.GetRandomValue(-250, 250))/60
					bunny.speed.y = f32(rl.GetRandomValue(-250, 250))/60
					bunny.color = {u8(rl.GetRandomValue(50, 240)),
					               u8(rl.GetRandomValue(80, 240)),
					               u8(rl.GetRandomValue(100, 240)), 255}
					
					append(&bunnies, bunny)
				}
			}
		}

		// Update bunnies
		for &bunny in bunnies {
			bunny.position += bunny.speed * rl.GetFrameTime() * 30
			
			if bunny.position.x + f32(tex_bunny.width)/2 > f32(rl.GetScreenWidth()) ||
				bunny.position.x + f32(tex_bunny.width)/2 < 0 {
					bunny.speed.x *= -1
				}
			if bunny.position.y + f32(tex_bunny.height/2) > f32(rl.GetScreenHeight()) ||
				bunny.position.y + f32(tex_bunny.height)/2 - 40 < 0 {
					bunny.speed.y *= -1
				}
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			for bunny in bunnies {
				rl.DrawTexture(tex_bunny, i32(bunny.position.x), i32(bunny.position.y), bunny.color)
			}

			rl.DrawRectangle(0, 0, SCREEN_WIDTH, 40, rl.BLACK)
			
			bunnies_count := len(bunnies)
			rl.DrawText(rl.TextFormat("bunnies: %i", bunnies_count), 120, 10, 20, rl.GREEN)
			rl.DrawText(rl.TextFormat("batched draw calls: %i", 1 + bunnies_count/MAX_BATCH_ELEMENTS), 320, 10, 20, rl.MAROON)

			rl.DrawFPS(10, 10)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	delete(bunnies)            // Unload bunnies data array

	rl.UnloadTexture(tex_bunny)    // Unload bunny texture

	rl.CloseWindow()              // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}