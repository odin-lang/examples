package box2d

import b2 "vendor:box2d"
import rl "vendor:raylib"

// Original: https://github.com/erincatto/box2d-raylib

Entity :: struct {
	body_id: b2.BodyId,
	extent:  b2.Vec2,
	texture: rl.Texture,
}

draw_entity :: proc(entity: Entity) {
	// The boxes were created centered on the bodies, but raylib draws textures starting at the top left corner.
	// Body_GetWorldPoint gets the top left corner of the box accounting for rotation.
	p        := b2.Body_GetWorldPoint(entity.body_id, -entity.extent)
	rotation := b2.Body_GetRotation(entity.body_id)
	radians  := b2.Rot_GetAngle(rotation)

	rl.DrawTextureEx(entity.texture, p, rl.RAD2DEG * radians, 1., rl.WHITE)

	// I used these circles to ensure the coordinates are correct
	// rl.DrawCircleV(p, 5., rl.BLACK)
	// p = b2.Body_GetWorldPoint(entity.body_id, 0)
	// rl.DrawCircleV(p, 5., rl.BLUE)
	// p = b2.Body_GetWorldPoint(entity.body_id, entity.extent)
	// rl.DrawCircleV(p, 5., rl.RED)
}

GROUND_COUNT :: 14
BOX_COUNT    :: 10

main :: proc() {
	width  := i32(1920)
	height := i32(1080)
	rl.InitWindow(width, height, "box2d-raylib")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	// 128 pixels per meter is appropriate for this scene. The boxes are 128 pixels wide.
	length_units_per_meter := f32(128.)
	b2.SetLengthUnitsPerMeter(length_units_per_meter)

	world_def := b2.DefaultWorldDef()

	// Realistic gravity is achieved by multiplying gravity by the length unit.
	world_def.gravity.y = 9.8 * length_units_per_meter
	world_id := b2.CreateWorld(world_def)

	ground_texture := rl.LoadTexture("ground.png")
	defer rl.UnloadTexture(ground_texture)

	box_texture := rl.LoadTexture("box.png")
	defer rl.UnloadTexture(box_texture)

	ground_extent := b2.Vec2{.5 * f32(ground_texture.width), .5 * f32(ground_texture.height)}
	box_extent    := b2.Vec2{.5 * f32(box_texture.width),    .5 * f32(box_texture.height)}

	// These polygons are centered on the origin and when they are added to a body they
	// will be centered on the body position.
	ground_polygon := b2.MakeBox(ground_extent.x, ground_extent.y)
	box_polygon    := b2.MakeBox(box_extent.x,    box_extent.y)

	ground_entities: [GROUND_COUNT]Entity
	for &entity, i in ground_entities {
		body_def := b2.DefaultBodyDef()
		body_def.position = {(2. * f32(i) + 2.) * ground_extent.x, f32(height) - ground_extent.y - 100.}

		// I used this rotation to test the world to screen transformation
		// body_def.rotation = b2.MakeRot(.25 * b2.PI * f32(i))

		entity.body_id = b2.CreateBody(world_id, body_def)
		entity.extent  = ground_extent
		entity.texture = ground_texture
		shape_def := b2.DefaultShapeDef()
		_ = b2.CreatePolygonShape(entity.body_id, shape_def, ground_polygon)
	}

	box_entities: [BOX_COUNT]Entity
	box_index: int
	for i in 1..=4 {
		y := f32(height) - box_extent.y - 100. - (2.5 * f32(i) + 2.) * box_extent.y - 20.

		for j in i..=4 {
			x := .5 * f32(width) + (3. * f32(j) - f32(i) - 3.) * box_extent.x

			body_def := b2.DefaultBodyDef()
			body_def.type     = .dynamicBody
			body_def.position = {x, y}

			entity := &box_entities[box_index]
			entity.body_id = b2.CreateBody(world_id, body_def)
			entity.texture = box_texture
			entity.extent  = box_extent
			shape_def := b2.DefaultShapeDef()
			_ = b2.CreatePolygonShape(entity.body_id, shape_def, box_polygon)

			box_index += 1
		}
	}
	assert(box_index == BOX_COUNT)

	pause: bool
	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.P) {
			pause = !pause
		}

		if !pause {
			delta_time := rl.GetFrameTime()
			b2.World_Step(world_id, delta_time, 4)
		}

		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.DARKGRAY)

		message :: "Hello Box2D!"
		font_size := i32(36)
		text_width := rl.MeasureText(message, font_size)
		rl.DrawText(message, (width - text_width) / 2, 50, font_size, rl.LIGHTGRAY)

		for entity in ground_entities {
			draw_entity(entity)
		}

		for entity in box_entities {
			draw_entity(entity)
		}
	}
}