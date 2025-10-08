/*******************************************************************************************
*
*   raylib [core] example - 3d camera fps
*
*   Example complexity rating: [★★★☆] 3/4
*
*   Example originally created with raylib 5.5, last time updated with raylib 5.5
*
*   Example contributed by Agnis Aldins (@nezvers) and reviewed by Ramon Santamaria (@raysan5)
*
*   Example licensed under an unmodified zlib/libpng license, which is an OSI-certified,
*   BSD-like license that allows static linking with closed source software
*
*   Copyright (c) 2025 Agnis Aldins (@nezvers)
*
********************************************************************************************/

package raylib_examples

import "core:math/linalg"
import rl "vendor:raylib"

//----------------------------------------------------------------------------------
// Defines and Macros
//----------------------------------------------------------------------------------
// Movement constants
GRAVITY :: 32.0
MAX_SPEED :: 20.0
CROUCH_SPEED :: 5.0
JUMP_FORCE :: 12.0
MAX_ACCEL :: 150.0
// Grounded drag
FRICTION :: 0.86
// Increasing air drag, increases strafing speed
AIR_DRAG :: 0.98
// Responsiveness for turning movement direction to looked direction
CONTROL :: 15.0
CROUCH_HEIGHT :: 0.0
STAND_HEIGHT :: 1.0
BOTTOM_HEIGHT :: 0.5

NORMALIZE_INPUT :: false

//----------------------------------------------------------------------------------
// Types and Structures Definition
//----------------------------------------------------------------------------------
// Body structure
Body :: struct {
	position:   rl.Vector3,
	velocity:   rl.Vector3,
	dir:        rl.Vector3,
	isGrounded: bool,
}

//----------------------------------------------------------------------------------
// Global Variables Definition
//----------------------------------------------------------------------------------
sensitivity := rl.Vector2{0.001, 0.001}

player: Body
lookRotation: rl.Vector2
headTimer: f32
walkLerp: f32
headLerp: f32 = STAND_HEIGHT
lean: rl.Vector2

//------------------------------------------------------------------------------------
// Program main entry point
//------------------------------------------------------------------------------------
main :: proc() {
	// Initialization
	//--------------------------------------------------------------------------------------
	SCREEN_WIDTH :: 800
	SCREEN_HEIGHT :: 450

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib [core] example - 3d camera fps")

	// Initialize camera variables
	// NOTE: UpdateCameraFPS() takes care of the rest
	camera := rl.Camera {
		fovy = 60.0,
		projection = .PERSPECTIVE,
		position = { player.position.x, player.position.y + (BOTTOM_HEIGHT + headLerp), player.position.z },
	}

	update_camera_fps(&camera)	// Update camera parameters

	rl.DisableCursor() 			// Limit cursor to relative movement inside the window

	rl.SetTargetFPS(60) 		// Set our game to run at 60 frames-per-second
	//--------------------------------------------------------------------------------------

	// Main game loop
	for !rl.WindowShouldClose() { 	// Detect window close button or ESC key
		// Update
		//----------------------------------------------------------------------------------
		mouseDelta := rl.GetMouseDelta()
		lookRotation.x -= mouseDelta.x * sensitivity.x
		lookRotation.y += mouseDelta.y * sensitivity.y

		sideway := i8(rl.IsKeyDown(.D)) - i8(rl.IsKeyDown(.A))
		forward := i8(rl.IsKeyDown(.W)) - i8(rl.IsKeyDown(.S))
		crouching := rl.IsKeyDown(.LEFT_CONTROL)
		update_body(&player, lookRotation.x, sideway, forward, rl.IsKeyPressed(.SPACE), crouching)

		delta := rl.GetFrameTime()
		headLerp = rl.Lerp(headLerp, (crouching ? CROUCH_HEIGHT : STAND_HEIGHT), 20.0 * delta)
		camera.position = { player.position.x, player.position.y + (BOTTOM_HEIGHT + headLerp), player.position.z }

		if player.isGrounded && ((forward != 0) || (sideway != 0)) {
			headTimer += delta * 3.0
			walkLerp = rl.Lerp(walkLerp, 1.0, 10.0 * delta)
			camera.fovy = rl.Lerp(camera.fovy, 55.0, 5.0 * delta)
		} else {
			walkLerp = rl.Lerp(walkLerp, 0.0, 10.0 * delta)
			camera.fovy = rl.Lerp(camera.fovy, 60.0, 5.0 * delta)
		}

		lean.x = rl.Lerp(lean.x, f32(sideway) * 0.02, 10.0 * delta)
		lean.y = rl.Lerp(lean.y, f32(forward) * 0.015, 10.0 * delta)

		update_camera_fps(&camera)
		//----------------------------------------------------------------------------------

		// Draw
		//----------------------------------------------------------------------------------
		rl.BeginDrawing()

			rl.ClearBackground(rl.RAYWHITE)

			rl.BeginMode3D(camera)
				draw_level()
			rl.EndMode3D()

			// Draw info box
			rl.DrawRectangle(5, 5, 330, 75, rl.Fade(rl.SKYBLUE, 0.5))
			rl.DrawRectangleLines(5, 5, 330, 75, rl.BLUE)

			rl.DrawText("Camera controls:", 15, 15, 10, rl.BLACK)
			rl.DrawText("- Move keys: W, A, S, D, Space, Left-Ctrl", 15, 30, 10, rl.BLACK)
			rl.DrawText("- Look around: arrow keys or mouse", 15, 45, 10, rl.BLACK)
			rl.DrawText(rl.TextFormat("- Velocity Len: (%06.3f)", rl.Vector2Length(player.velocity.xy)), 15, 60, 10, rl.BLACK)

		rl.EndDrawing()
		//----------------------------------------------------------------------------------
	}

	// De-Initialization
	//--------------------------------------------------------------------------------------
	rl.CloseWindow() // Close window and OpenGL context
	//--------------------------------------------------------------------------------------
}

//----------------------------------------------------------------------------------
// Module Functions Definition
//----------------------------------------------------------------------------------
// Update body considering current world state
update_body :: proc(body: ^Body, rot: f32, side: i8, forward: i8, jumpPressed: bool, crouchHold: bool) {
	input: rl.Vector2 = {f32(side), f32(-forward)}

	if NORMALIZE_INPUT {
		// Slow down diagonal movement
		if (side != 0) && (forward != 0) {
			input = rl.Vector2Normalize(input)
		}
	}

	delta := rl.GetFrameTime()

	if !body.isGrounded {
		body.velocity.y -= GRAVITY * delta
	}

	if body.isGrounded && jumpPressed {
		body.velocity.y = JUMP_FORCE
		body.isGrounded = false

		// Sound can be played at this moment
		//SetSoundPitch(fxJump, 1.0f + (GetRandomValue(-100, 100)*0.001));
		//PlaySound(fxJump);
	}

	front := rl.Vector3{linalg.sin(rot), 0, linalg.cos(rot)}
	right := rl.Vector3{linalg.cos(-rot), 0, linalg.sin(-rot)}

	desiredDir := rl.Vector3 {
		input.x * right.x + input.y * front.x,
		0.0,
		input.x * right.z + input.y * front.z,
	}
	body.dir = linalg.lerp(body.dir, desiredDir, CONTROL * delta)

	decel : f32 = (body.isGrounded ? FRICTION : AIR_DRAG)
	hvel := rl.Vector3{body.velocity.x * decel, 0.0, body.velocity.z * decel}

	hvelLength := rl.Vector3Length(hvel) // Magnitude
	if hvelLength < (MAX_SPEED * 0.01) {
		hvel = rl.Vector3{0.0, 0.0, 0.0}
	}
	
	// This is what creates strafing
	speed := rl.Vector3DotProduct(hvel, body.dir)

	// Whenever the amount of acceleration to add is clamped by the maximum acceleration constant,
	// a Player can make the speed faster by bringing the direction closer to horizontal velocity angle
	// More info here: https://youtu.be/v3zT3Z5apaM?t=165
	maxSpeed: f32 = (crouchHold ? CROUCH_SPEED : MAX_SPEED)
	accel := rl.Clamp(maxSpeed - speed, 0, MAX_ACCEL * delta)
	hvel.x += body.dir.x * accel
	hvel.z += body.dir.z * accel

	body.velocity.x = hvel.x
	body.velocity.z = hvel.z

	body.position += body.velocity * delta

	// Fancy collision system against the floor
	if body.position.y <= 0.0 {
		body.position.y = 0.0
		body.velocity.y = 0.0
		body.isGrounded = true // Enable jumping
	}
}

// Update camera for FPS behaviour
update_camera_fps :: proc(camera: ^rl.Camera) {
	UP :: rl.Vector3{0.0, 1.0, 0.0}
	TARGET_OFFSET :: rl.Vector3{0.0, 0.0, -1.0}

	// Left and right
	yaw := rl.Vector3RotateByAxisAngle(TARGET_OFFSET, UP, lookRotation.x)

	// Clamp view up
	maxAngleUp := rl.Vector3Angle(UP, yaw)
	maxAngleUp -= 0.001 // Avoid numerical errors
	if -lookRotation.y > maxAngleUp {
		lookRotation.y = -maxAngleUp
	}

	// Clamp view down
	maxAngleDown := rl.Vector3Angle(-UP, yaw)
	maxAngleDown *= -1.0 // Downwards angle is negative
	maxAngleDown += 0.001 // Avoid numerical errors
	if -lookRotation.y < maxAngleDown {
		lookRotation.y = -maxAngleDown
	}

	// Up and down
	right := rl.Vector3Normalize(rl.Vector3CrossProduct(yaw, UP))

	// Rotate view vector around right axis
	pitchAngle := -lookRotation.y - lean.y
	pitchAngle = rl.Clamp(pitchAngle, -rl.PI / 2 + 0.0001, rl.PI / 2 - 0.0001) // Clamp angle so it doesn't go past straight up or straight down
	pitch := rl.Vector3RotateByAxisAngle(yaw, right, pitchAngle)

	// Head animation
	// Rotate up direction around forward axis
	headSin := linalg.sin(headTimer * rl.PI)
	headCos := linalg.cos(headTimer * rl.PI)
	STEP_ROTATION :: 0.01
	camera.up = rl.Vector3RotateByAxisAngle(UP, pitch, headSin * STEP_ROTATION + lean.x)

	// Camera BOB
	BOB_SIDE :: 0.1
	BOB_UP :: 0.15
	bobbing := right * (headSin * BOB_SIDE)
	bobbing.y = abs(headCos * BOB_UP)

	camera.position = camera.position + (bobbing * walkLerp)
	camera.target = camera.position + pitch
}

// Draw game level
draw_level :: proc() {
	FLOOR_EXTENT :: 25
	TILE_SIZE :: 5.0
	TILE_COLOR_1 :: rl.Color{150, 200, 200, 255}

	// Floor tiles
	for y in -FLOOR_EXTENT..< FLOOR_EXTENT {
		for x in -FLOOR_EXTENT..< FLOOR_EXTENT {
			if (y & 1 != 0) && (x & 1 != 0) {
				rl.DrawPlane(rl.Vector3{f32(x) * TILE_SIZE, 0.0, f32(y) * TILE_SIZE}, rl.Vector2{TILE_SIZE, TILE_SIZE}, TILE_COLOR_1)
			} else if (y & 1 == 0) && (x & 1 == 0) {
				rl.DrawPlane(rl.Vector3{f32(x) * TILE_SIZE, 0.0, f32(y) * TILE_SIZE}, rl.Vector2{TILE_SIZE, TILE_SIZE}, rl.LIGHTGRAY)
			}
		}
	}

	TOWER_SIZE :: rl.Vector3{16.0, 32.0, 16.0}
	TOWER_COLOR :: rl.Color{150, 200, 200, 255}

	towerPos := rl.Vector3{16.0, 16.0, 16.0}
	rl.DrawCubeV(towerPos, TOWER_SIZE, TOWER_COLOR)
	rl.DrawCubeWiresV(towerPos, TOWER_SIZE, rl.DARKBLUE)

	towerPos.x *= -1
	rl.DrawCubeV(towerPos, TOWER_SIZE, TOWER_COLOR)
	rl.DrawCubeWiresV(towerPos, TOWER_SIZE, rl.DARKBLUE)

	towerPos.z *= -1
	rl.DrawCubeV(towerPos, TOWER_SIZE, TOWER_COLOR)
	rl.DrawCubeWiresV(towerPos, TOWER_SIZE, rl.DARKBLUE)

	towerPos.x *= -1
	rl.DrawCubeV(towerPos, TOWER_SIZE, TOWER_COLOR)
	rl.DrawCubeWiresV(towerPos, TOWER_SIZE, rl.DARKBLUE)

	// Red sun
	rl.DrawSphere({300.0, 300.0, 0.0}, 100, rl.Color{255, 0, 0, 255})
}