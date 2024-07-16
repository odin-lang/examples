package main

import    "rlights"

import rl "vendor:raylib"

MAX_INSTANCES :: 10_000

main :: proc() {
	screenWidth  :: 800
	screenHeight :: 450

	rl.InitWindow(screenWidth, screenHeight, "raylib [shaders] example - mesh instancing")
	defer rl.CloseWindow()

	camera := rl.Camera{
        position   = { -125, 125, -125 },
        target     = 0,
        up         = { 0, 1, 0 },
        fovy       = 45,
        projection = .PERSPECTIVE,
    }

	cube := rl.GenMeshCube(1, 1, 1)

	transforms := make([]rl.Matrix, MAX_INSTANCES)
	defer delete(transforms)

	for i in 0..<MAX_INSTANCES {
		translation := rl.MatrixTranslate(f32(rl.GetRandomValue(-50, 50)), f32(rl.GetRandomValue(-50, 50)), f32(rl.GetRandomValue(-50, 50)))
		axis        := rl.Vector3Normalize({f32(rl.GetRandomValue(0, 360)), f32(rl.GetRandomValue(0, 360)), f32(rl.GetRandomValue(0, 360))})
		angle       := f32(rl.GetRandomValue(0, 10)) * f32(rl.DEG2RAD)
		rotation    := rl.MatrixRotate(axis, angle)

		transforms[i] = rotation * translation
	}

	shader := rl.LoadShader("resources/shaders/lighting_instancing.vs", "resources/shaders/lighting.fs")
	defer rl.UnloadShader(shader)

	shader.locs[rl.ShaderLocationIndex.MATRIX_MVP]   = i32(rl.GetShaderLocation(shader, "mvp"))
	shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW]  = i32(rl.GetShaderLocation(shader, "viewPos"))
	shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = i32(rl.GetShaderLocationAttrib(shader, "instanceTransform"))

	ambientLoc := rl.GetShaderLocation(shader, "ambient")
	rl.SetShaderValue(shader, ambientLoc, &[4]f32{ 0.2, 0.2, 0.2, 1 }, .VEC4)

	rlights.CreateLight(.Directional, { 50, 50, 0 }, 0, rl.WHITE, shader)

	matInstances := rl.LoadMaterialDefault()
	matInstances.shader = shader
	matInstances.maps[rl.MaterialMapIndex.ALBEDO].color = rl.RED

	matDefault := rl.LoadMaterialDefault()
	matDefault.maps[rl.MaterialMapIndex.ALBEDO].color = rl.BLUE

	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.UpdateCamera(&camera, .ORBITAL)

		cameraPos := [3]f32{ camera.position.x, camera.position.y, camera.position.z }
		rl.SetShaderValue(shader, rl.ShaderLocationIndex(shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW]), &cameraPos, .VEC3)

		{
			rl.BeginDrawing()
			defer rl.EndDrawing()

			rl.ClearBackground(rl.RAYWHITE)
			
			{
				rl.BeginMode3D(camera)
				defer rl.EndMode3D()

				rl.DrawMesh(cube, matDefault, rl.MatrixTranslate(-10, 0, 0))

				rl.DrawMeshInstanced(cube, matInstances, raw_data(transforms), MAX_INSTANCES)

				rl.DrawMesh(cube, matDefault, rl.MatrixTranslate(10, 0, 0))
			}

			rl.DrawFPS(10, 10)
		}
	}
}
