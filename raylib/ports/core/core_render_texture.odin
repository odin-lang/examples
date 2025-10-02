/*******************************************************************************************
*
*   raylib [core] example - render texture
*
*   Example complexity rating: [★☆☆☆] 1/4
*
*   Example originally created with raylib 5.6-dev, last time updated with raylib 5.6-dev
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2025 Ramon Santamaria (@raysan5)
*
********************************************************************************************/

package raylib_examples

import rl "vendor:raylib"

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//---------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [core] example - render texture")
	defer rl.CloseWindow()        // Close window and OpenGL context
	
	// Define a render texture to render
	render_texture_width: i32 = 300
	render_texture_height: i32 = 300
	target: rl.RenderTexture2D = rl.LoadRenderTexture(render_texture_width, render_texture_height)

	ball_position := rl.Vector2 {f32(render_texture_width)/2, f32(render_texture_height)/2}
	ball_speed := rl.Vector2 {5.0, 4.0}
	ball_radius: i32 = 20

	rotation: f32 = 0

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//----------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() {    // Detect window close button or ESC key
		// Update
		//-----------------------------------------------------
		// Ball movement logic
		ball_position.x += ball_speed.x
		ball_position.y += ball_speed.y

		// Check walls collision for bouncing
		if ball_position.x >= f32(render_texture_width - ball_radius)) || (ball_position.x <= f32(ball_radius) {
			ball_speed.x *= -1
		}
		if ball_position.y >= f32(render_texture_height - ball_radius)) || (ball_position.y <= f32(ball_radius) {
			ball_speed.y *= -1
		}

		// Render texture rotation
		rotation += 0.5
		//-----------------------------------------------------

		// Draw
		//-----------------------------------------------------
		// Draw our scene to the render texture
		rl.BeginTextureMode(target)
		
			rl.ClearBackground(rl.SKYBLUE)
			
			rl.DrawCircleV(ball_position, f32(ball_radius), rl.MAROON)
		
		rl.EndTextureMode()
		
		// Draw render texture to main framebuffer
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			// Draw our render texture with rotation applied
			// NOTE: We set the origin of the texture to the center of the render texture
			rl.DrawTexturePro(target.texture, 
				{0, 0, f32(target.texture.width), f32(-target.texture.height)}, 
				{SCREEN_WIDTH/2, SCREEN_HEIGHT/2, f32(target.texture.width), f32(-target.texture.height)}, 
				{f32(target.texture.width)/2, f32(target.texture.height)/2}, rotation, rl.WHITE)

			rl.DrawText("DRAWING BOUNCING BALL INSIDE RENDER TEXTURE!", 10, SCREEN_HEIGHT - 40, 20, rl.BLACK)
			

			rl.DrawFPS(10, 10)

		rl.EndDrawing()
		//-----------------------------------------------------
	}

	// De-Initialization
	//---------------------------------------------------------
	
	//----------------------------------------------------------
}