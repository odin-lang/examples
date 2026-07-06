/*******************************************************************************************
*
*   raylib [models] example - animation playing
*
*   Example complexity rating: [★★☆☆] 2/4
*
*   Example originally created with raylib 2.5, last time updated with raylib 3.5
*
*   Example contributed by Culacant (@culacant) and reviewed by Ramon Santamaria (@raysan5)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2019-2025 Culacant (@culacant) and Ramon Santamaria (@raysan5)
*
********************************************************************************************
*
*   NOTE: To export a model from blender, make sure it is not posed, the vertices need to be
*         in the same position as they would be in edit mode and the scale of your models is
*         set to 0. Scaling can be done from the export menu
*
********************************************************************************************/

package raylib_examples

import rl "vendor:raylib"

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
    // Initialization
    //--------------------------------------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [models] example - animation playing")

    // Define the camera to look into our 3d world
	camera := rl.Camera { 
    	position = { 10.0, 10.0, 10.0 }, // Camera position
    	target = { 0.0, 0.0, 0.0 },      // Camera looking at point
    	up = { 0.0, 1.0, 0.0 },          // Camera up vector (rotation towards target)
		fovy = 45.0,                     // Camera field-of-view Y
    	projection = .PERSPECTIVE,       // Camera mode type
	}

	model := rl.LoadModel("resources/models/iqm/guy.iqm")            // Load the animated model mesh and basic data
	texture := rl.LoadTexture("resources/models/iqm/guytex.png")     // Load model texture and set material
	rl.SetMaterialTexture(&model.materials[0], .ALBEDO, texture)     // Set model material map texture

	position := rl.Vector3{ 0.0, 0.0, 0.0 }            // Set model position

    // Load animation data
	animsCount: i32
	anims := rl.LoadModelAnimations("resources/models/iqm/guyanim.iqm", &animsCount)
	animFrameCounter: i32

	rl.DisableCursor()                    // Catch cursor
	rl.SetTargetFPS(60)                   // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
	for !rl.WindowShouldClose() {        // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
		rl.UpdateCamera(&camera, .FIRST_PERSON)

        // Play animation when spacebar is held down
		if rl.IsKeyDown(.SPACE) {
			animFrameCounter += 1
			rl.UpdateModelAnimation(model, anims[0], animFrameCounter)
			if animFrameCounter >= anims[0].frameCount {
				animFrameCounter = 0
			}
		}
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.BeginMode3D(camera)

				rl.DrawModelEx(model, position, { 1.0, 0.0, 0.0 }, -90.0, { 1.0, 1.0, 1.0 }, rl.WHITE)

				for i := 0; i < int(model.boneCount); i += 1 {
					rl.DrawCube(anims[0].framePoses[animFrameCounter][i].translation, 0.2, 0.2, 0.2, rl.RED)
                }

				rl.DrawGrid(10, 1.0)         // Draw a grid

			rl.EndMode3D()

			rl.DrawText("PRESS SPACE to PLAY MODEL ANIMATION", 10, 10, 20, rl.MAROON)
			rl.DrawText("(c) Guy IQM 3D model by @culacant", SCREEN_WIDTH - 200, SCREEN_HEIGHT - 20, 10, rl.GRAY)

		rl.EndDrawing()
        //----------------------------------------------------------------------------------
    }

    // De-Initialization
    //--------------------------------------------------------------------------------------
	rl.UnloadTexture(texture)                     // Unload texture
	rl.UnloadModelAnimations(anims, animsCount)   // Unload model animations data
	rl.UnloadModel(model)                         // Unload model

	rl.CloseWindow()                  // Close window and OpenGL context
    //--------------------------------------------------------------------------------------
}