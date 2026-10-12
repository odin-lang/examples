package main
import gl "vendor:OpenGL"

font_draw :: proc {
	font_draw_u32,
	font_draw_string,
}

font_draw_u32 :: proc(pos: [2]f32, num: u32, color: [3]f32 = 1, font_chars: ^[FONT_MAX_CHARS]u32, sp_font: u32, scale: f32 = 1) {
	count: u32 = 1
	for n := num; n >= 10; n /= 10 {
		count += 1
	}
	for i, n := count - 1, num; n > 0; i-= 1 {
		n, font_chars[i] = n / 10, (16 + n % 10) | (i << 16)
	}
	if count > 0 {
		font_draw_call(font_chars, sp_font, count, pos, scale, color)
	}
}

font_draw_string :: proc(pos: [2]f32, txt: string, color: [3]f32 = 1, font_chars: ^[FONT_MAX_CHARS]u32, sp_font: u32, scale: f32 = 1) {
	count, col, line: u32
	prev: rune
	for r in string(txt) {
		if u32(r) == 10 {
			col, line = 0, line + 1
		} else if n := (u32(r) < 32 || u32(r) > 127) ? 63 - 32 : u32(r) - 32; count < FONT_MAX_CHARS {
			if r == 'n' && prev == '\\' {
				col, count, line = 0, count - 1, line + 1
			} else {
				col, count, font_chars[count] = col + 1, count + 1, n | (line << 8) | (col << 16)
			}
			prev = r
		}
	}
	if count > 0 {
		font_draw_call(font_chars, sp_font, count, pos, scale, color)
	}
}

font_draw_call :: proc(font_chars: ^[FONT_MAX_CHARS]u32, sp_font: u32, count: u32, pos: [2]f32, scale: f32, color: [3]f32) {
	gl_shader_set_vec3(sp_font, "color", color)
	gl_shader_set_float(sp_font, "scale", scale)
	gl_shader_set_vec2(sp_font, "pos", pos)
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, int(count) * size_of(u32), raw_data(font_chars))
	gl.DrawArraysInstanced(gl.TRIANGLE_FAN, 0, 4, i32(count))
}
