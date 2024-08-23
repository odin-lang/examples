package src

/*
Original Source: https://github.com/orca-app/orca/blob/main/samples/breakout/src/main.c

Can be run using in the local folder
1. odin.exe build main.odin -file -target:orca_wasm32 -out:module.wasm 
2. orca bundle --name orca_output --resource-dir data module.wasm
3. orca_output\bin\orca_output.exe
*/

import "base:runtime"
import "core:log"
import "core:fmt"
import "core:math"
import oc "core:sys/orca"

ctx: runtime.Context

NUM_BLOCKS_PER_ROW :: 7
NUM_BLOCKS :: 42 // 7 * 6
NUM_BLOCKS_TO_WIN :: NUM_BLOCKS - 2
BLOCKS_WIDTH :: f32(810.0)
BLOCK_HEIGHT :: f32(30.0)
BLOCKS_PADDING :: f32(15.0)
BLOCKS_BOTTOM :: f32(300.0)
PADDLE_MAX_LAUNCH_ANGLE :: 0.7

BLOCK_WIDTH :: (BLOCKS_WIDTH - ((NUM_BLOCKS_PER_ROW + 1) * BLOCKS_PADDING)) / NUM_BLOCKS_PER_ROW

// This is upside down from how it will actually be drawn.
velocity := oc.vec2{5, 5}

//odinfmt: disable
blockHealth := [NUM_BLOCKS]int {
	0,
	1,
	1,
	1,
	1,
	1,
	0,
	1,
	1,
	1,
	1,
	1,
	1,
	1,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	2,
	3,
	3,
	3,
	3,
	3,
	3,
	3,
	3,
	3,
	3,
	3,
	3,
	3,
	3,
}
score := 0

leftDown := false
rightDown := false

frameSize := oc.vec2{100, 100}

surface: oc.surface
renderer: oc.canvas_renderer
canvas: oc.canvas_context

waterImage: oc.image
brickImage: oc.image
ballImage: oc.image
font: oc.font

paddleColor := oc.color{{1, 0, 0, 1}, .RGB}
paddle := oc.rect{300, 50, 200, 24}
ball := oc.rect{200, 200, 20, 20}

flip_y :: proc "contextless" (r: oc.rect) -> oc.mat2x3 {
	return {1, 0, 0, 0, -1, 2 * r.y + r.w}
}

flip_y_at :: proc "contextless" (pos: oc.vec2) -> oc.mat2x3 {
	return {1, 0, 0, 0, -1, 2 * pos.y}
}

main :: proc() {
	context.logger = oc.create_odin_logger()
	ctx = context

	oc.window_set_title("Breakout")

	renderer = oc.canvas_renderer_create()
	surface = oc.canvas_surface_create(renderer)
	canvas = oc.canvas_context_create()

	waterImage = oc.image_create_from_path(renderer, "/underwater.jpg", false)
	brickImage = oc.image_create_from_path(renderer, "/brick.png", false)
	ballImage = oc.image_create_from_path(renderer, "/ball.png", false)

	if oc.image_is_nil(waterImage) {
		oc.log_error("couldn't load water image\n")
	}
	if oc.image_is_nil(brickImage) {
		oc.log_error("couldn't load brick image\n")
	}
	if oc.image_is_nil(ballImage) {
		oc.log_error("couldn't load ball image\n")
	}

	ranges := [5]oc.unicode_range {
		oc.UNICODE_BASIC_LATIN,
		oc.UNICODE_C1_CONTROLS_AND_LATIN_1_SUPPLEMENT,
		oc.UNICODE_LATIN_EXTENDED_A,
		oc.UNICODE_LATIN_EXTENDED_B,
		oc.UNICODE_SPECIALS,
	}

	font = oc.font_create_from_path("/Literata-SemiBoldItalic.ttf", 5, &ranges[0])
}

// @(export)
// oc_on_terminate :: proc "c" () {
// 	if score == NUM_BLOCKS_TO_WIN {
// 		oc.log_info("you win!\n")
// 	} else {
// 		oc.log_info("goodbye world!\n")
// 	}
// }

@(export)
oc_on_resize :: proc "c" (width, height: u32) {
	context = ctx
	log.infof("frame resize %v, %v", width, height)
	frameSize.x = f32(width)
	frameSize.y = f32(height)
}

@(export)
oc_on_key_down :: proc "c" (scan: oc.scan_code, key: oc.key_code) {
	// oc.log_info("key down: %i", key)
	oc.log_ext(.INFO, "keydown", "breakout.odin", 112, "key up: %i", key)

	if key == .LEFT {
		leftDown = true
	}

	if key == .RIGHT {
		rightDown = true
	}
}

@(export)
oc_on_key_up :: proc "c" (scan: oc.scan_code, key: oc.key_code) {
	// oc.log_info("key up: %i", key)
	oc.log_ext(.INFO, "keyup", "breakout.odin", 126, "key up: %i", key)

	if key == .LEFT {
		leftDown = false
	}

	if key == .RIGHT {
		rightDown = false
	}
}

block_rect :: proc "contextless" (i: int) -> oc.rect {
	row := f32(i / NUM_BLOCKS_PER_ROW)
	col := f32(i % NUM_BLOCKS_PER_ROW)

	return {
		BLOCKS_PADDING + (BLOCKS_PADDING + BLOCK_WIDTH) * col,
		BLOCKS_BOTTOM + (BLOCKS_PADDING + BLOCK_HEIGHT) * row,
		BLOCK_WIDTH,
		BLOCK_HEIGHT,
	}
}

// Returns a cardinal direction 1-8 for the collision with the block, or zero
// if no collision. 1 is straight up and directions proceed clockwise.
check_collision :: proc "contextless" (block: oc.rect) -> int {
	// Note that all the logic for this game has the origin in the bottom left.
	ballx2 := ball.x + ball.w
	bally2 := ball.y + ball.h
	blockx2 := block.x + block.w
	blocky2 := block.y + block.h

	if ballx2 < block.x || blockx2 < ball.x || bally2 < block.y || blocky2 < ball.y {
		// Ball is fully outside block
		return 0
	}

	// If moving right, the ball can bounce off its top right corner, right
	// side, or bottom right corner. Corner bounces occur if the block's bottom
	// left corner is in the ball's top right quadrant, or if the block's top
	// left corner is in the ball's bottom left quadrant. Otherwise, an edge
	// bounce occurs if the block's left edge falls in either of the ball's
	// right quadrants.
	//
	// This logic generalizes to other directions.
	//
	// We assume significant tunneling can't happen.

	ballCenter := oc.vec2{ball.x + ball.w / 2, ball.y + ball.h / 2}

	// Moving right
	if velocity.x > 0 {
		// Ball's top right corner
		if ballCenter.x <= block.x &&
		   block.x <= ballx2 &&
		   ballCenter.y <= block.y &&
		   block.y <= bally2 {
			return 2
		}

		// Ball's bottom right corner
		if ballCenter.x <= block.x &&
		   block.x <= ballx2 &&
		   ball.y <= blocky2 &&
		   blocky2 <= ballCenter.y {
			return 4
		}

		// Ball's right edge
		if ballCenter.x <= block.x && block.x <= ballx2 {
			return 3
		}
	}

	// Moving up
	if velocity.y > 0 {
		// Ball's top left corner
		if ball.x <= blockx2 &&
		   blockx2 <= ballCenter.x &&
		   ballCenter.y <= block.y &&
		   block.y <= bally2 {
			return 8
		}

		// Ball's top right corner
		if ballCenter.x <= block.x &&
		   block.x <= ballx2 &&
		   ballCenter.y <= block.y &&
		   block.y <= bally2 {
			return 2
		}

		// Ball's top edge
		if ballCenter.y <= block.y && block.y <= bally2 {
			return 1
		}
	}

	// Moving left
	if velocity.x < 0 {
		// Ball's bottom left corner
		if ball.x <= blockx2 &&
		   blockx2 <= ballCenter.x &&
		   ball.y <= blocky2 &&
		   blocky2 <= ballCenter.y {
			return 6
		}

		// Ball's top left corner
		if ball.x <= blockx2 &&
		   blockx2 <= ballCenter.x &&
		   ballCenter.y <= block.y &&
		   block.y <= bally2 {
			return 8
		}

		// Ball's left edge
		if ball.x <= blockx2 && blockx2 <= ballCenter.x {
			return 7
		}
	}

	// Moving down
	if velocity.y < 0 {
		// Ball's bottom right corner
		if ballCenter.x <= block.x &&
		   block.x <= ballx2 &&
		   ball.y <= blocky2 &&
		   blocky2 <= ballCenter.y {
			return 4
		}

		// Ball's bottom left corner
		if ball.x <= blockx2 &&
		   blockx2 <= ballCenter.x &&
		   ball.y <= blocky2 &&
		   blocky2 <= ballCenter.y {
			return 6
		}

		// Ball's bottom edge
		if ball.y <= blocky2 && blocky2 <= ballCenter.y {
			return 5
		}
	}

	return 0
}

@(export)
oc_on_frame_refresh :: proc "c" () {
	context = ctx

	scratch := oc.scratch_begin()
	defer oc.scratch_end(scratch)

	if leftDown {
		paddle.x -= 10
	} else if rightDown {
		paddle.x += 10
	}
	paddle.x = clamp(paddle.x, 0, frameSize.x - paddle.w)

	ball.x += velocity.x
	ball.y += velocity.y
	ball.x = clamp(ball.x, 0, frameSize.x - ball.w)
	ball.y = clamp(ball.y, 0, frameSize.y - ball.h)

	if ball.x + ball.w >= frameSize.x {
		velocity.x = -velocity.x
	}
	if ball.x <= 0 {
		velocity.x = -velocity.x
	}
	if ball.y + ball.h >= frameSize.y {
		velocity.y = -velocity.y
	}

	if ball.y <= paddle.y + paddle.h &&
	   ball.x + ball.w >= paddle.x &&
	   ball.x <= paddle.x + paddle.w &&
	   velocity.y < 0 {
		t := ((ball.x + ball.w / 2) - paddle.x) / paddle.w
		launchAngle := math.lerp(f32(-PADDLE_MAX_LAUNCH_ANGLE), f32(PADDLE_MAX_LAUNCH_ANGLE), t)
		speed := math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
		velocity = (oc.vec2){math.sin(launchAngle) * speed, math.cos(launchAngle) * speed}
		ball.y = paddle.y + paddle.h

		oc.log_info("PONG!")
	}

	if ball.y <= 0 {
		ball.x = frameSize.x / 2. - ball.w
		ball.y = frameSize.y / 2. - ball.h
	}

	for i in 0 ..< NUM_BLOCKS {
		if blockHealth[i] <= 0 {
			continue
		}

		r := block_rect(i)
		result := check_collision(r)
		if result != 0 {
			log.infof("Collision! direction=%v", result)
			blockHealth[i] -= 1

			if blockHealth[i] == 0 {
				score += 1
			}

			vx := velocity.x
			vy := velocity.y

			switch (result) {
			case 1, 5:
				velocity.y = -vy
			case 3, 7:
				velocity.x = -vx
			case 2, 6:
				velocity.x = -vy
				velocity.y = -vx
			case 4, 8:
				velocity.x = vy
				velocity.y = vx
			}
		}
	}

	if score == NUM_BLOCKS_TO_WIN {
		oc.request_quit()
	}

	oc.canvas_context_select(canvas)

	oc.set_color_rgba(10.0 / 255.0, 31.0 / 255.0, 72.0 / 255.0, 1)
	oc.clear()

	oc.image_draw(waterImage, (oc.rect){0, 0, frameSize.x, frameSize.y})

	yUp := oc.mat2x3{1, 0, 0, 0, -1, frameSize.y}

	oc.matrix_multiply_push(yUp)
	{
		for i in 0 ..< NUM_BLOCKS {
			if blockHealth[i] <= 0 {
				continue
			}

			r := block_rect(i)

			oc.set_image(brickImage)
			oc.set_color_rgba(0.9, 0.9, 0.9, 1)
			oc.rounded_rectangle_fill(r.x, r.y, r.w, r.h, 4)
			oc.set_image(oc.image_nil())

			oc.set_color_rgba(0.6, 0.6, 0.6, 1)
			oc.set_width(2)
			oc.rounded_rectangle_stroke(r.x, r.y, r.w, r.h, 4)

			fontSize := 18
			text := fmt.tprintf("%d", blockHealth[i])
			textRect := oc.font_text_metrics(font, f32(fontSize), text).ink

			textPos := oc.vec2 {
				r.x + r.w / 2 - textRect.w / 2 - textRect.x,
				r.y + r.h / 2 - textRect.h / 2 - textRect.y - textRect.h, //NOTE: we render with y-up so we need to flip bounding box coordinates.
			}

			oc.set_color_rgba(0.9, 0.9, 0.9, 1)
			oc.circle_fill(r.x + r.w / 2, r.y + r.h / 2, r.h / 2.5)

			oc.set_color_rgba(0, 0, 0, 1)
			oc.set_font(font)
			oc.set_font_size(18)
			oc.move_to(textPos.x, textPos.y)
			oc.matrix_multiply_push(flip_y_at(textPos))
			{
				oc.text_outlines(text)
				oc.fill()
			}
			oc.matrix_pop()
		}

		oc.set_color(paddleColor)
		oc.rounded_rectangle_fill(paddle.x, paddle.y, paddle.w, paddle.h, 4)

		oc.matrix_multiply_push(flip_y(ball))
		{
			oc.image_draw(ballImage, ball)
		}
		oc.matrix_pop()

		// draw score text
		{
			oc.move_to(20, 20)
			text := fmt.tprintf(
				"Destroy all %d blocks to win! Current score: %d",
				NUM_BLOCKS_TO_WIN,
				score,
			)
			textPos := oc.vec2{20, 20}
			oc.matrix_multiply_push(flip_y_at(textPos))
			{
				oc.set_color_rgba(0.9, 0.9, 0.9, 1)
				oc.text_outlines(text)
				oc.fill()
			}
			oc.matrix_pop()
		}
	}
	oc.matrix_pop()

	oc.canvas_render(renderer, canvas, surface)
	oc.canvas_present(renderer, surface)
}
