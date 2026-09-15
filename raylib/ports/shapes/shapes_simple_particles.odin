/*******************************************************************************************
*
*   raylib [shapes] example - simple particles
*
*   Example complexity rating: [★★☆☆] 2/4
*
*   Example originally created with raylib 5.6, last time updated with raylib 5.6
*
*   Example contributed by Jordi Santonja (@JordSant)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2025 Jordi Santonja (@JordSant)
*
********************************************************************************************/
package raylib_examples

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 450
MAX_PARTICLES :: 3000

Particle_Type :: enum {
	WATER,
	SMOKE,
	FIRE,
}

PARTICLE_TYPE_NAMES :: [Particle_Type]cstring {
	.WATER = "WATER",
	.SMOKE = "SMOKE",
	.FIRE  = "FIRE",
}

Particle :: struct {
	type:      Particle_Type,
	position:  rl.Vector2,
	velocity:  rl.Vector2,
	radius:    f32,
	color:     rl.Color,
	life_time: f32,
	alive:     bool,
}

Circular_Buffer :: struct {
	head:   int,
	tail:   int,
	buffer: [MAX_PARTICLES]Particle,
}


cb: Circular_Buffer
emission_rate: int = -2
current_type: Particle_Type = .WATER
emitter_position: rl.Vector2
type_names := PARTICLE_TYPE_NAMES

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------

main :: proc() {

	// Initialization
	//--------------------------------------------------------------------------------------
	
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [shapes] example - simple particles (Odin)")
	defer rl.CloseWindow()

	rl.SetTargetFPS(60)

	emitter_position = {f32(SCREEN_WIDTH) / 2.0, f32(SCREEN_HEIGHT) / 2.0}
	
	//--------------------------------------------------------------------------------------

	// Main "game" loop
	
	for !rl.WindowShouldClose() {
		// Update
		//----------------------------------------------------------------------------------
		update()
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		draw()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	// No resources to unload
	//--------------------------------------------------------------------------------------
}

//----------------------------------------------------------------------------------
// Module Functions Definition
//----------------------------------------------------------------------------------
update :: proc() {
	
	if emission_rate < 0 {
		if rand.int31() % i32(-emission_rate) == 0 {
			emit_particle()
		}
	} else {
		for i := 0; i <= emission_rate; i += 1 {
			emit_particle()
		}
	}

	
	update_particles()

	// Remove dead particles from the circular buffer
	update_circular_buffer()

	
	if rl.IsKeyPressed(.UP) { emission_rate += 1 }
	if rl.IsKeyPressed(.DOWN) { emission_rate -= 1 }

	
	if rl.IsKeyPressed(.RIGHT) {
		current_type = Particle_Type((int(current_type) + 1) % len(Particle_Type))
	}
	if rl.IsKeyPressed(.LEFT) {
		current_type = Particle_Type(
			(int(current_type) + len(Particle_Type) - 1) % len(Particle_Type),
		)
	}

	
	if rl.IsMouseButtonDown(.LEFT) {
		emitter_position = rl.GetMousePosition()
	}
}

draw :: proc() {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground(rl.RAYWHITE)


	draw_particles()


	rl.DrawRectangle(5, 5, 315, 75, rl.Fade(rl.SKYBLUE, 0.5))
	rl.DrawRectangleLines(5, 5, 315, 75, rl.BLUE)

	rl.DrawText("CONTROLS:", 15, 15, 10, rl.BLACK)
	rl.DrawText("UP/DOWN: Change Particle Emission Rate", 15, 35, 10, rl.BLACK)
	rl.DrawText("LEFT/RIGHT: Change Particle Type (Water, Smoke, Fire)", 15, 55, 10, rl.BLACK)

	if emission_rate < 0 {
		rl.DrawText(
			rl.TextFormat(
				"Particles every %d frames | Type: %s",
				-emission_rate,
				type_names[current_type],
			),
			15,
			95,
			10,
			rl.DARKGRAY,
		)
	} else {
		rl.DrawText(
			rl.TextFormat(
				"%d Particles per frame | Type: %s",
				emission_rate + 1,
				type_names[current_type],
			),
			15,
			95,
			10,
			rl.DARKGRAY,
		)
	}

	rl.DrawFPS(SCREEN_WIDTH - 80, 10)
}

emit_particle :: proc() {
	particle := add_to_circular_buffer()
	if particle == nil { return }


	particle.position = emitter_position
	particle.alive = true
	particle.life_time = 0.0
	particle.type = current_type

	speed := f32(rand.int31() % 10) / 5.0

	switch current_type {
	case .WATER:
		particle.radius = 5.0
		particle.color = rl.BLUE
	case .SMOKE:
		particle.radius = 7.0
		particle.color = rl.GRAY
	case .FIRE:
		particle.radius = 10.0
		particle.color = rl.YELLOW
		speed /= 10.0
	}

	direction := f32(rand.int31() % 360)
	rad := direction * math.RAD_PER_DEG
	particle.velocity = {speed * math.cos(rad), speed * math.sin(rad)}
}

add_to_circular_buffer :: proc() -> ^Particle {
	// Check if buffer is full
	next_head := (cb.head + 1) % MAX_PARTICLES
	if next_head == cb.tail { return nil }

	// Add new particle to the head position and advance head
	particle := &cb.buffer[cb.head]
	cb.head = next_head
	return particle
}

update_particles :: proc() {
	i := cb.tail
	for i != cb.head {
		p := &cb.buffer[i]


		p.life_time += 1.0 / 60.0

		switch p.type {
		case .WATER:
			p.position.x += p.velocity.x
			p.velocity.y += 0.2 
			p.position.y += p.velocity.y
		// Smoke expands and fades
		case .SMOKE:
			p.position.x += p.velocity.x
			p.velocity.y -= 0.05 
			p.position.y += p.velocity.y
			p.radius += 0.5 

			if p.color.a > 4 {
				p.color.a -= 4
			} else {
				p.alive = false
			}

		case .FIRE:
			// Make fire look more natural by adding horizontal oscillation.
			// Real flame does not rise in a straight line
			p.position.x += p.velocity.x + math.cos(p.life_time * 215.0)
			p.velocity.y -= 0.05 // Upwards
			p.position.y += p.velocity.y
			p.radius -= 0.15 // Fire shrinks


			if p.color.g > 3 {
				p.color.g -= 3
			} else {
				p.alive = false
			}

			if p.radius <= 0.02 {
				p.alive = false
			}
		}

		// Disable particle when out of screen
		if p.position.x < -p.radius ||
		   p.position.x > f32(SCREEN_WIDTH) + p.radius ||
		   p.position.y < -p.radius ||
		   p.position.y > f32(SCREEN_HEIGHT) + p.radius {
			p.alive = false
		}

		i = (i + 1) % MAX_PARTICLES
	}
}

// Update circular buffer: advance tail over dead particles
update_circular_buffer :: proc() {
	for cb.tail != cb.head && !cb.buffer[cb.tail].alive {
		cb.tail = (cb.tail + 1) % MAX_PARTICLES
	}
}

draw_particles :: proc() {
	i := cb.tail
	for i != cb.head {
		p := &cb.buffer[i]
		if p.alive {
			rl.DrawCircleV(p.position, p.radius, p.color)
		}
		i = (i + 1) % MAX_PARTICLES
	}
}
