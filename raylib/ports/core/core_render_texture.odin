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
	screenWidth :: 800
	screenHeight :: 450

	rl.InitWindow(screenWidth, screenHeight, "raylib [core] example - render texture")
	
	// Define a render texture to render
	renderTextureWidth: i32 = 300
	renderTextureHeight: i32 = 300
	target: rl.RenderTexture2D = rl.LoadRenderTexture(renderTextureWidth, renderTextureHeight)

	ballPosition: rl.Vector2 = {f32(renderTextureWidth)/2, f32(renderTextureHeight)/2}
	ballSpeed: rl.Vector2 = {5.0, 4.0}
	ballRadius: i32 = 20

	rotation: f32 = 0

	rl.SetTargetFPS(60)               // Set our game to run at 60 frames-per-second
	//----------------------------------------------------------

	// Main game loop
	for (!rl.WindowShouldClose()) {    // Detect window close button or ESC key
		// Update
		//-----------------------------------------------------
		// Ball movement logic
		ballPosition.x += ballSpeed.x
		ballPosition.y += ballSpeed.y

		// Check walls collision for bouncing
		if ((ballPosition.x >= f32(renderTextureWidth - ballRadius)) || (ballPosition.x <= f32(ballRadius))) {
			ballSpeed.x *= -1
		}
		if ((ballPosition.y >= f32(renderTextureHeight - ballRadius)) || (ballPosition.y <= f32(ballRadius))) {
			ballSpeed.y *= -1
		}

		// Render texture rotation
		rotation += 0.5
		//-----------------------------------------------------

		// Draw
		//-----------------------------------------------------
		// Draw our scene to the render texture
		rl.BeginTextureMode(target)
		
			rl.ClearBackground(rl.SKYBLUE)
			
			rl.DrawCircleV(ballPosition, f32(ballRadius), rl.MAROON)
		
		rl.EndTextureMode()
		
		// Draw render texture to main framebuffer
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			// Draw our render texture with rotation applied
			// NOTE: We set the origin of the texture to the center of the render texture
			rl.DrawTexturePro(target.texture, 
				{0, 0, f32(target.texture.width), f32(-target.texture.height)}, 
				{screenWidth/2, screenHeight/2, f32(target.texture.width), f32(-target.texture.height)}, 
				{f32(target.texture.width/2), f32(target.texture.height/2)}, rotation, rl.WHITE)

			rl.DrawText("DRAWING BOUNCING BALL INSIDE RENDER TEXTURE!", 10, screenHeight - 40, 20, rl.BLACK)
			

			rl.DrawFPS(10, 10)

		rl.EndDrawing()
		//-----------------------------------------------------
	}

	// De-Initialization
	//---------------------------------------------------------
	rl.CloseWindow()        // Close window and OpenGL context
	//----------------------------------------------------------
}