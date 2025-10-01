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

MAX_BUNNIES :: 50000    // 50K bunnies limit

// This is the maximum amount of elements (quads) per batch
// NOTE: This value is defined in [rlgl] module and can be changed there
MAX_BATCH_ELEMENTS :: 8192

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

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [textures] example - bunnymark")

	// Load bunny texture
	texBunny: rl.Texture2D = rl.LoadTexture("resources/wabbit_alpha.png")

	bunnies: [dynamic]Bunny          // Bunnies array

	bunniesCount: uint = 0           // Bunnies counter
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		if rl.IsMouseButtonDown(.LEFT) {
			for i: uint; i < 100; i += 1 {
				if bunniesCount < MAX_BUNNIES {
					bunny: Bunny
					bunny.position = rl.GetMousePosition()
					bunny.speed.x = f32(rl.GetRandomValue(-250, 250))/60
					bunny.speed.y = f32(rl.GetRandomValue(-250, 250))/60
					bunny.color = {u8(rl.GetRandomValue(50, 240)),
													   u8(rl.GetRandomValue(80, 240)),
													   u8(rl.GetRandomValue(100, 240)), 255}
					
					append(&bunnies, bunny)
					
					bunniesCount += 1
				}
			}
		}

		// Update bunnies
		bunniesSize: uint = len(bunnies)
		for i: uint; i < bunniesSize; i += 1 {
			bunny: ^Bunny = &bunnies[i]
			
			bunny.position += bunny.speed * rl.GetFrameTime() * 30
			
			if (bunny.position.x + f32(texBunny.width)/2) > f32(rl.GetScreenWidth()) ||
				(bunny.position.x + f32(texBunny.width)/2) < 0 {
					bunny.speed.x *= -1
				}
			if (bunny.position.y + f32(texBunny.height/2)) > f32(rl.GetScreenHeight()) ||
				(bunny.position.y + f32(texBunny.height)/2 - 40) < 0 {
					bunny.speed.y *= -1
				}
		}
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			for bunny in bunnies {
				rl.DrawTexture(texBunny, i32(bunny.position.x), i32(bunny.position.y), bunny.color)
			}

			rl.DrawRectangle(0, 0, SCREEN_WIDTH, 40, rl.BLACK)
			rl.DrawText(rl.TextFormat("bunnies: %i", bunniesCount), 120, 10, 20, rl.GREEN)
			rl.DrawText(rl.TextFormat("batched draw calls: %i", 1 + bunniesCount/MAX_BATCH_ELEMENTS), 320, 10, 20, rl.MAROON)

			rl.DrawFPS(10, 10)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	delete(bunnies)            // Unload bunnies data array

	rl.UnloadTexture(texBunny)    // Unload bunny texture

	rl.CloseWindow()              // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}