/*
	Simple game about enemies chasing and shooting you in 2D space.

	Original repo: https://github.com/wbogocki/Odin-Play

	To play:
		- Move with WSAD or arrow keys
		- Jump with Shift + direction
*/

package chase_in_space

import "core:fmt"
import "core:math/linalg"
import "vendor:sdl2"

Game :: struct {
	renderer: ^sdl2.Renderer,
	keyboard: []u8,
	time:     f64,
	dt:       f64,
	entities: [dynamic]Entity,
}

EntityType :: enum {
	PLAYER,
	ENEMY,
	PROJECTILE,
}

Entity :: struct {
	type:           EntityType,
	hp:             int,
	pos:            [2]f32,
	vel:            [2]f32,
	reload_counter: f32,
	bullet_decay:   f32,
	dash_counter:   f32,
}

render_entity :: proc(entity: ^Entity, game: ^Game) {
	switch entity.type {
	case .PLAYER:
		sdl2.SetRenderDrawColor(game.renderer, 255, 0, 255, 0)
		sdl2.RenderDrawRectF(
			game.renderer,
			&sdl2.FRect{x = entity.pos.x, y = entity.pos.y, w = 10, h = 10},
		)
	case .ENEMY:
		sdl2.SetRenderDrawColor(game.renderer, 0, 255, 255, 0)
		sdl2.RenderDrawRectF(
			game.renderer,
			&sdl2.FRect{x = entity.pos.x, y = entity.pos.y, w = 10, h = 10},
		)
	case .PROJECTILE:
		sdl2.SetRenderDrawColor(game.renderer, 0, 255, 255, 0)
		sdl2.RenderDrawPointF(game.renderer, entity.pos.x, entity.pos.y)
	}
}

find_entity :: proc(type: EntityType, game: ^Game) -> ^Entity {
	for _, i in game.entities {
		if game.entities[i].type == type {
			return &game.entities[i]
		}
	}
	return nil
}

update_entity :: proc(entity: ^Entity, game: ^Game) {
	dt := f32(game.dt)
	switch entity.type {
	case .PLAYER:
		dir := [2]f32{0, 0}
		if b8(game.keyboard[sdl2.SCANCODE_UP   ]) | b8(game.keyboard[sdl2.SCANCODE_W]) { dir.y -= 1 }
		if b8(game.keyboard[sdl2.SCANCODE_DOWN ]) | b8(game.keyboard[sdl2.SCANCODE_S]) { dir.y += 1 }
		if b8(game.keyboard[sdl2.SCANCODE_LEFT ]) | b8(game.keyboard[sdl2.SCANCODE_A]) { dir.x -= 1 }
		if b8(game.keyboard[sdl2.SCANCODE_RIGHT]) | b8(game.keyboard[sdl2.SCANCODE_D]) { dir.x += 1 }
		dir = linalg.normalize0(dir)
		entity.pos += dir * 0.2 * dt
		// Dash
		if b8(game.keyboard[sdl2.SCANCODE_LSHIFT]) && entity.dash_counter == 0 && dir != 0 {
			entity.vel = dir * 5.0
			entity.dash_counter += 150
		} else {
			entity.dash_counter = max(entity.dash_counter - dt, 0)
		}
		entity.pos += entity.vel * dt
		entity.vel -= entity.vel * 0.9999 / dt
		// Keep it in the map
		entity.pos.x = clamp(entity.pos.x, 0, 640 - 10)
		entity.pos.y = clamp(entity.pos.y, 0, 480 - 10)
	case .ENEMY:
		// Towards player
		player := find_entity(.PLAYER, game)
		if player == nil { return }
		dir := player.pos - entity.pos
		dir = linalg.normalize0(dir)
		entity.pos += dir * 0.12 * dt
		// Away from other enemies
		for _, i in game.entities {
			if game.entities[i].type == .ENEMY && entity != &game.entities[i] {
				edir := entity.pos - game.entities[i].pos
				dis  := linalg.length(edir)
				if dis > 0 {
					entity.pos += edir * (1. / (dis * dis)) * 0.1 * dt
				}
			}
		}
		// Shoot
		if entity.reload_counter <= 0 {
			append(
				&game.entities,
				Entity{
					type = .PROJECTILE,
					pos = entity.pos,
					vel = 0.5 * dir,
					hp = 1,
					bullet_decay = 750,
				},
			)
			entity.reload_counter = 1000
		} else {
			entity.reload_counter -= dt
		}
	case .PROJECTILE:
		entity.pos += entity.vel * dt
		entity.bullet_decay -= 1.0 * dt
		if entity.bullet_decay < 0 {
			entity.hp = 0
		} else {
			player := find_entity(.PLAYER, game)
			if player == nil { return }
			if player.pos.x < entity.pos.x && entity.pos.x < player.pos.x + 10 && player.pos.y < entity.pos.y &&
			   entity.pos.y < player.pos.y + 10 {
				player.hp -= 1
				fmt.printf("HIT (HP: {})\n", player.hp)
				entity.hp = 0
			}
		}
	}
}

get_time :: proc() -> f64 {
	return f64(sdl2.GetPerformanceCounter()) * 1000 / f64(sdl2.GetPerformanceFrequency())
}

main :: proc() {
	assert(sdl2.Init(sdl2.INIT_VIDEO) == 0, sdl2.GetErrorString())
	defer sdl2.Quit()

	window := sdl2.CreateWindow(
		"Odin Game",
		sdl2.WINDOWPOS_CENTERED,
		sdl2.WINDOWPOS_CENTERED,
		640,
		480,
		sdl2.WINDOW_SHOWN,
	)
	assert(window != nil, sdl2.GetErrorString())
	defer sdl2.DestroyWindow(window)

	// Must not do VSync because we run the tick loop on the same thread as rendering.
	renderer := sdl2.CreateRenderer(window, -1, sdl2.RENDERER_ACCELERATED)
	assert(renderer != nil, sdl2.GetErrorString())
	defer sdl2.DestroyRenderer(renderer)

	tickrate := 240.0
	ticktime := 1000.0 / tickrate

	game := Game {
		renderer = renderer,
		time     = get_time(),
		dt       = ticktime,
		entities = make([dynamic]Entity),
	}
	defer delete(game.entities)

	append(&game.entities, Entity{type = .PLAYER, pos = { 50.0, 400.0}, hp = 10})
	append(&game.entities, Entity{type = .ENEMY , pos = { 50.0,  50.0}, hp =  1})
	append(&game.entities, Entity{type = .ENEMY , pos = {100.0, 100.0}, hp =  1})
	append(&game.entities, Entity{type = .ENEMY , pos = {200.0, 200.0}, hp =  1})

	dt := 0.0

	for {
		event: sdl2.Event
		for sdl2.PollEvent(&event) {
			#partial switch event.type {
			case .QUIT:
				return
			case .KEYDOWN:
				if event.key.keysym.scancode == sdl2.SCANCODE_ESCAPE {
					return
				}
			}
		}

		time := get_time()
		dt += time - game.time

		game.keyboard = sdl2.GetKeyboardStateAsSlice()
		game.time = time

		// Running on the same thread as rendering so in the end still limited by the rendering FPS.
		for dt >= ticktime {
			dt -= ticktime

			for _, i in game.entities {
				update_entity(&game.entities[i], &game)
			}

			for i := 0; i < len(game.entities); {
				if game.entities[i].hp <= 0 {
					ordered_remove(&game.entities, i)
				} else {
					i += 1
				}
			}
		}

		sdl2.SetRenderDrawColor(renderer, 0, 0, 0, 0)
		sdl2.RenderClear(renderer)
		for _, i in game.entities {
			render_entity(&game.entities[i], &game)
		}
		sdl2.RenderPresent(renderer)
	}
}
