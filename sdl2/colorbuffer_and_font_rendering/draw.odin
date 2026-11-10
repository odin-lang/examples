package main
import "core:math"

draw_pixel :: proc(colorbuffer: ^Colorbuffer, pos: [2]int, color: u32) {
	if pos.x >= 0 && pos.x < colorbuffer.width && pos.y >= 0 && pos.y < colorbuffer.height {
		colorbuffer.buf[int(pos.x + pos.y * colorbuffer.width)] = color
	}
}

draw_line :: proc(colorbuffer: ^Colorbuffer, pos: [2][2]int, color: u32) {
	dx: f32 = f32(pos[1].x - pos[0].x)
	dy: f32 = f32(pos[1].y - pos[0].y)
	step := math.abs(dx) >= math.abs(dy) ? math.abs(dx) : math.abs(dy)
	dx /= step
	dy /= step
	x: f32 = f32(pos[0].x)
	y: f32 = f32(pos[0].y)
	for _ in 0 ..= int(step) {
		draw_pixel(colorbuffer, {int(math.round_f32(x)), int(math.round_f32(y))}, color)
		x += dx
		y += dy
	}
}

draw_u128 :: proc(colorbuffer: ^Colorbuffer, bits: u128, pos: [2]int, color: u32) {
	for i in 0 ..< 8 {
		for j in 0 ..< 16 {
			bit := u128(0x80000000000000000000000000000000) >> u128(j+i*16)
			if bits & bit == bit {
				draw_pixel(colorbuffer, {pos.x + i, pos.y + j}, color)
			}
		}
	}
}

draw_ui :: proc {
	draw_ui_int,
	draw_ui_string,
}

draw_ui_int :: proc(pos: [2]int, m: int, color: u32, ui_colorbuffer: ^Colorbuffer, ui_drawn_areas: ^[dynamic; UI_DRAWS_PER_FRAME_LIMIT]Rect) {
	num_digits: int = 1
	for n := math.abs(m); n >= 10; n /= 10 {
		num_digits += 1
	}
	draw_ui_add_drawn_area(ui_drawn_areas, pos.x, pos.y, num_digits * (CHAR_WIDTH + CHAR_SPACING),  CHAR_HEIGHT)
	for i, n := num_digits, m; i > 0; i, n = i - 1, n / 10 {
		draw_u128(ui_colorbuffer, font_char(n % 10), {pos.x + (i-1) * (CHAR_WIDTH + CHAR_SPACING), pos.y}, color)
	}
}

draw_ui_string :: proc(pos: [2]int, txt: string, color: u32, ui_colorbuffer: ^Colorbuffer, ui_drawn_areas: ^[dynamic; UI_DRAWS_PER_FRAME_LIMIT]Rect) {
	draw_ui_add_drawn_area(ui_drawn_areas, pos.x, pos.y, len(txt) * (CHAR_WIDTH + CHAR_SPACING),  CHAR_HEIGHT)
	for c, i in txt { 
		if c != ' ' {
			draw_u128(ui_colorbuffer, font_char(c), {pos.x + i * (CHAR_WIDTH + CHAR_SPACING), pos.y}, color)
		}
	}
}

draw_ui_add_drawn_area :: proc(ui_drawn_areas: ^[dynamic; UI_DRAWS_PER_FRAME_LIMIT]Rect, x0, y0, width, height: int) {
	if (len(ui_drawn_areas) < cap(ui_drawn_areas)) { 
		append(ui_drawn_areas, Rect{x0, y0, width, height})
	}
}
