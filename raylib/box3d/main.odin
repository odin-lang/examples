package main

import rl "vendor:raylib"
import gl "vendor:raylib/rlgl"
import b3 "vendor:box3d"

NUM_BOXES :: 25

main :: proc() {
	rl.InitWindow(1024, 768, "Box3D + Raylib 6 sample")

	camera := rl.Camera3D{
		position   = {25, 15, 25},
		up         = {0, 1, 0},
		fovy       = 45,
		projection = .PERSPECTIVE,
	}

	rl.SetTargetFPS(60)

	world_def := b3.DefaultWorldDef()
	world_def.gravity = {0, -10, 0}
	world_id := b3.CreateWorld(world_def)

	ground_body_def := b3.DefaultBodyDef()
	ground_body_def.position = {0, -10, 0}
	ground_id := b3.CreateBody(world_id, ground_body_def)

	ground_box := b3.MakeBoxHull(50, 10, 50)
	ground_shape_def := b3.DefaultShapeDef()
	_ = b3.CreateHullShape(ground_id, ground_shape_def, &ground_box.base)

	boxes: [NUM_BOXES]b3.BodyId
	for i in 0..<len(boxes) {
		body_def := b3.DefaultBodyDef()
		body_def.type = .dynamicBody

		offset_x := f32((i % 2 == 0) ? .05 : -.05)
		body_def.position = {offset_x, 2. + f32(i) * 2.5, 0}
		boxes[i] = b3.CreateBody(world_id, body_def)

		dynamic_box := b3.MakeCubeHull(1)
		shape_def := b3.DefaultShapeDef()
		shape_def.density = 1
		shape_def.baseMaterial.friction = .3

		_ = b3.CreateHullShape(boxes[i], shape_def, &dynamic_box.base)
	}

	time_step:      f32 = 1. / 60.
	sub_step_count: i32 = 4

	for !rl.WindowShouldClose() {
		b3.World_Step(world_id, time_step, sub_step_count)

		rl.BeginDrawing()
		{
			defer rl.EndDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.BeginMode3D(camera)
			{
				defer rl.EndMode3D()

				rl.DrawCube({0, -2, 0}, 100, 4, 100, rl.LIGHTGRAY)
				rl.DrawCubeWires({0, -2, 0}, 100, 4, 100, rl.GRAY)

				for box in boxes {
					pos := b3.Body_GetPosition(box)
					rot := b3.Body_GetRotation(box)

					angle, axis := b3.GetAxisAngle(rot)

					gl.PushMatrix()
					{
						defer gl.PopMatrix()

						gl.Translatef(pos.x, pos.y, pos.z)
						gl.Rotatef(angle * rl.RAD2DEG, axis.x, axis.y, axis.z)

						rl.DrawCube(0, 2, 2, 2, rl.BLUE)
						rl.DrawCubeWires(0, 2, 2, 2, rl.DARKBLUE)
					}
				}

				rl.DrawGrid(20, 5)
			}

			rl.DrawFPS(10, 10)
			rl.DrawText("Box3D + Raylib 6 sample", 10, 35, 20, rl.DARKGRAY)
		}
	}

	b3.DestroyWorld(world_id)
	rl.CloseWindow()
}
