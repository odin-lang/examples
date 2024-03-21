package microui_raylib

import c "core:c/libc"
import "core:fmt"
import u "core:unicode/utf8"

import rl "vendor:raylib"
import mu "vendor:microui"

state := struct{
	mu_ctx: mu.Context,
	log_buf:         [1<<16]byte,
	log_buf_len:     int,
	log_buf_updated: bool,
	bg: mu.Color,
	atlas_texture: rl.RenderTexture2D,

	screen_width: c.int,
	screen_height: c.int,

	previous_keys: [dynamic]rl.KeyboardKey,

}{
	screen_width = 960,
	screen_height = 540,
	bg = {90, 95, 100, 255},
}

screen_texture: rl.RenderTexture2D

current_keys: [dynamic]rl.KeyboardKey

main :: proc() {
	ctx := &state.mu_ctx

	mu.init(ctx)

	ctx.text_width = mu.default_atlas_text_width
	ctx.text_height = mu.default_atlas_text_height

	rl.InitWindow(state.screen_width, state.screen_height, "microui-raylib-odin")
	rl.SetTargetFPS(60);

	state.atlas_texture = rl.LoadRenderTexture(c.int(mu.DEFAULT_ATLAS_WIDTH), c.int(mu.DEFAULT_ATLAS_HEIGHT))

	// Create a texture from the default atlas data
	image: rl.Image = rl.GenImageColor(c.int(mu.DEFAULT_ATLAS_WIDTH), c.int(mu.DEFAULT_ATLAS_HEIGHT), rl.Color{0, 0, 0, 0})

	for alpha, i in mu.default_atlas_alpha {
		x:= c.int(i % mu.DEFAULT_ATLAS_WIDTH)
		y:= c.int(i / mu.DEFAULT_ATLAS_WIDTH)
		color:= rl.Color{255, 255, 255, alpha}
		rl.ImageDrawPixel(&image, x, y, color)
	}

	rl.BeginTextureMode(state.atlas_texture)
	{
		rl.UpdateTexture(state.atlas_texture.texture, rl.LoadImageColors(image))
	}
	rl.EndTextureMode()

	// Create texture for screen
	screen_texture = rl.LoadRenderTexture(state.screen_width, state.screen_height)

	main_loop: for !rl.WindowShouldClose() {
		//// Handle mouse input
		mouse_pos : rl.Vector2 = rl.GetMousePosition()
		mu.input_mouse_move(ctx, i32(mouse_pos.x), i32(mouse_pos.y))

		mouse_wheel_pos : rl.Vector2 = rl.GetMouseWheelMoveV()
		mu.input_scroll(ctx, i32(mouse_wheel_pos.x) * 30, i32(mouse_wheel_pos.y) * -30)

		if rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
			mu.input_mouse_down(ctx, i32(mouse_pos.x), i32(mouse_pos.y), .LEFT)
		}
		if rl.IsMouseButtonReleased(rl.MouseButton.LEFT) {
			mu.input_mouse_up(ctx, i32(mouse_pos.x), i32(mouse_pos.y), .LEFT)
		}

		if rl.IsMouseButtonPressed(rl.MouseButton.MIDDLE) {
			mu.input_mouse_down(ctx, i32(mouse_pos.x), i32(mouse_pos.y), .MIDDLE)
		}
		if rl.IsMouseButtonReleased(rl.MouseButton.MIDDLE) {
			mu.input_mouse_up(ctx, i32(mouse_pos.x), i32(mouse_pos.y), .MIDDLE)
		}

		if rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
			mu.input_mouse_down(ctx, i32(mouse_pos.x), i32(mouse_pos.y), .RIGHT)
		}
		if rl.IsMouseButtonReleased(rl.MouseButton.RIGHT) {
			mu.input_mouse_up(ctx, i32(mouse_pos.x), i32(mouse_pos.y), .RIGHT)
		}

		//// Handle Keyboard input
		// info: This tries to imitate the behaviour of the SDL version.

		get_pressed_keys ::proc() -> [dynamic]rl.KeyboardKey {
			pressed_keys : [dynamic]rl.KeyboardKey

			for key := rl.GetKeyPressed(); key != .KEY_NULL; key = rl.GetKeyPressed() {
				append(&pressed_keys, key)
			}

			return pressed_keys
		}

		current_keys = get_pressed_keys() 

		// Check which keys aren't being pressed anymore
		for i: uint = 0; i < len(state.previous_keys); i += 1 {
			key:= state.previous_keys[i]
			if array_key_pos(&current_keys, key) == -1 {
				#partial switch key {
					case rl.KeyboardKey.LEFT_SHIFT: mu.input_key_up(ctx, .SHIFT)
					case rl.KeyboardKey.RIGHT_SHIFT: mu.input_key_up(ctx, .SHIFT)
					case rl.KeyboardKey.LEFT_CONTROL: mu.input_key_up(ctx, .CTRL)
					case rl.KeyboardKey.RIGHT_CONTROL: mu.input_key_up(ctx, .CTRL)
					case rl.KeyboardKey.LEFT_ALT: mu.input_key_up(ctx, .ALT)
					case rl.KeyboardKey.RIGHT_ALT: mu.input_key_up(ctx, .ALT)
					case rl.KeyboardKey.ENTER: mu.input_key_up(ctx, .RETURN)
					case rl.KeyboardKey.KP_ENTER: mu.input_key_up(ctx, .RETURN)
					case rl.KeyboardKey.BACKSPACE: mu.input_key_up(ctx, .BACKSPACE)
					case: // other cases are handled in section "handle_text_input"
				}
			}
		}

		// Check, which keys are newly being pressed
		for i: uint = 0; i < len(current_keys); i += 1 {
			key := current_keys[i]
			
			if array_key_pos(&state.previous_keys, key) == -1 {
				#partial switch key {
					case rl.KeyboardKey.ESCAPE: break main_loop
					case rl.KeyboardKey.LEFT_SHIFT: mu.input_key_down(ctx, .SHIFT)
					case rl.KeyboardKey.RIGHT_SHIFT: mu.input_key_down(ctx, .SHIFT)
					case rl.KeyboardKey.LEFT_CONTROL: mu.input_key_down(ctx, .CTRL)
					case rl.KeyboardKey.RIGHT_CONTROL: mu.input_key_down(ctx, .CTRL)
					case rl.KeyboardKey.LEFT_ALT: mu.input_key_down(ctx, .ALT)
					case rl.KeyboardKey.RIGHT_ALT: mu.input_key_down(ctx, .ALT)
					case rl.KeyboardKey.ENTER: mu.input_key_down(ctx, .RETURN)
					case rl.KeyboardKey.KP_ENTER: mu.input_key_down(ctx, .RETURN)
					case rl.KeyboardKey.BACKSPACE: mu.input_key_down(ctx, .BACKSPACE)
					case: // other cases are handled in section "handle_text_input"
				}			
			}
		}

		// This handles text input
		handle_text_input: {
			ra := make([]rune, 1)
			ra[0] = rl.GetCharPressed()

			if ra[0] != 0 {
				str:= u.runes_to_string(ra)
				mu.input_text(ctx, str)
			}
		}

		delete(state.previous_keys)
		state.previous_keys = current_keys

		//// microui code
		mu.begin(ctx)
		{
			all_windows(ctx)
		}
		mu.end(ctx)

		//// raylib rendering
		render(ctx)
	}


	defer rl.UnloadRenderTexture(screen_texture)
	defer rl.UnloadRenderTexture(state.atlas_texture)

	defer rl.CloseWindow()
}

u8_slider :: proc(ctx: ^mu.Context, val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
	mu.push_id(ctx, uintptr(val))

	@static tmp: mu.Real
	tmp = mu.Real(val^)
	res = mu.slider(ctx, &tmp, mu.Real(lo), mu.Real(hi), 0, "%.0f", {.ALIGN_CENTER})
	val^ = u8(tmp)
	mu.pop_id(ctx)
	return
}

write_log :: proc(str: string) {
	state.log_buf_len += copy(state.log_buf[state.log_buf_len:], str)
	state.log_buf_len += copy(state.log_buf[state.log_buf_len:], "\n")
	state.log_buf_updated = true
}

read_log :: proc() -> string {
	return string(state.log_buf[:state.log_buf_len])
}
reset_log :: proc() {
	state.log_buf_updated = true
	state.log_buf_len = 0
}


all_windows :: proc(ctx: ^mu.Context)
{
	@static opts := mu.Options{.NO_CLOSE}

	if mu.window(ctx, "Demo Window", {40, 40, 300, 450}, opts) {
		if .ACTIVE in mu.header(ctx, "Window Info") {
			win := mu.get_current_container(ctx)
			mu.layout_row(ctx, {54, -1}, 0)
			mu.label(ctx, "Position:")
			mu.label(ctx, fmt.tprintf("%d, %d", win.rect.x, win.rect.y))
			mu.label(ctx, "Size:")
			mu.label(ctx, fmt.tprintf("%d, %d", win.rect.w, win.rect.h))
		}

		if .ACTIVE in mu.header(ctx, "Window Options") {
			mu.layout_row(ctx, {120, 120, 120}, 0)
			for opt in mu.Opt {
				state := opt in opts
				if .CHANGE in mu.checkbox(ctx, fmt.tprintf("%v", opt), &state)  {
					if state {
						opts += {opt}
					} else {
						opts -= {opt}
					}
				}
			}
		}

		if .ACTIVE in mu.header(ctx, "Test Buttons", {.EXPANDED}) {
			mu.layout_row(ctx, {86, -110, -1})
			mu.label(ctx, "Test buttons 1:")
			if .SUBMIT in mu.button(ctx, "Button 1") { write_log("Pressed button 1") }
			if .SUBMIT in mu.button(ctx, "Button 2") { write_log("Pressed button 2") }
			mu.label(ctx, "Test buttons 2:")
			if .SUBMIT in mu.button(ctx, "Button 3") { write_log("Pressed button 3") }
			if .SUBMIT in mu.button(ctx, "Button 4") { write_log("Pressed button 4") }
		}

		if .ACTIVE in mu.header(ctx, "Tree and Text", {.EXPANDED}) {
			mu.layout_row(ctx, {140, -1})
			mu.layout_begin_column(ctx)
			if .ACTIVE in mu.treenode(ctx, "Test 1") {
				if .ACTIVE in mu.treenode(ctx, "Test 1a") {
					mu.label(ctx, "Hello")
					mu.label(ctx, "world")
				}
				if .ACTIVE in mu.treenode(ctx, "Test 1b") {
					if .SUBMIT in mu.button(ctx, "Button 1") { write_log("Pressed button 1") }
					if .SUBMIT in mu.button(ctx, "Button 2") { write_log("Pressed button 2") }
				}
			}
			if .ACTIVE in mu.treenode(ctx, "Test 2") {
				mu.layout_row(ctx, {53, 53})
				if .SUBMIT in mu.button(ctx, "Button 3") { write_log("Pressed button 3") }
				if .SUBMIT in mu.button(ctx, "Button 4") { write_log("Pressed button 4") }
				if .SUBMIT in mu.button(ctx, "Button 5") { write_log("Pressed button 5") }
				if .SUBMIT in mu.button(ctx, "Button 6") { write_log("Pressed button 6") }
			}
			if .ACTIVE in mu.treenode(ctx, "Test 3") {
				@static checks := [3]bool{true, false, true}
				mu.checkbox(ctx, "Checkbox 1", &checks[0])
				mu.checkbox(ctx, "Checkbox 2", &checks[1])
				mu.checkbox(ctx, "Checkbox 3", &checks[2])

			}
			mu.layout_end_column(ctx)

			mu.layout_begin_column(ctx)
			mu.layout_row(ctx, {-1})
			mu.text(ctx,
				"Lorem ipsum dolor sit amet, consectetur adipiscing "+
				"elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus "+
				"ipsum, eu varius magna felis a nulla.",
		        )
			mu.layout_end_column(ctx)
		}

		if .ACTIVE in mu.header(ctx, "Background Colour", {.EXPANDED}) {
			mu.layout_row(ctx, {-78, -1}, 68)
			mu.layout_begin_column(ctx)
			{
				mu.layout_row(ctx, {46, -1}, 0)
				mu.label(ctx, "Red:");   u8_slider(ctx, &state.bg.r, 0, 255)
				mu.label(ctx, "Green:"); u8_slider(ctx, &state.bg.g, 0, 255)
				mu.label(ctx, "Blue:");  u8_slider(ctx, &state.bg.b, 0, 255)
			}
			mu.layout_end_column(ctx)

			r := mu.layout_next(ctx)
			mu.draw_rect(ctx, r, state.bg)
			mu.draw_box(ctx, mu.expand_rect(r, 1), ctx.style.colors[.BORDER])
			mu.draw_control_text(ctx, fmt.tprintf("#%02x%02x%02x", state.bg.r, state.bg.g, state.bg.b), r, .TEXT, {.ALIGN_CENTER})
		}
	}	



	if mu.window(ctx, "Log Window", {350, 40, 300, 200}, opts) {
		mu.layout_row(ctx, {-1}, -28)
		mu.begin_panel(ctx, "Log")
		mu.layout_row(ctx, {-1}, -1)
		mu.text(ctx, read_log())
		if state.log_buf_updated {
			panel := mu.get_current_container(ctx)
			panel.scroll.y = panel.content_size.y
			state.log_buf_updated = false
		}
		mu.end_panel(ctx)

		@static buf: [128]byte
		@static buf_len: int
		submitted := false
		mu.layout_row(ctx, {-70, -1})
		if .SUBMIT in mu.textbox(ctx, buf[:], &buf_len) {
			mu.set_focus(ctx, ctx.last_id)
			submitted = true
		}
		if .SUBMIT in mu.button(ctx, "Submit") {
			submitted = true
		}
		if submitted {
			write_log(string(buf[:buf_len]))
			buf_len = 0
		}
	}

	if mu.window(ctx, "Style Window", {350, 250, 300, 240}) {
		@static colors := [mu.Color_Type]string{
			.TEXT         = "text",
			.BORDER       = "border",
			.WINDOW_BG    = "window bg",
			.TITLE_BG     = "title bg",
			.TITLE_TEXT   = "title text",
			.PANEL_BG     = "panel bg",
			.BUTTON       = "button",
			.BUTTON_HOVER = "button hover",
			.BUTTON_FOCUS = "button focus",
			.BASE         = "base",
			.BASE_HOVER   = "base hover",
			.BASE_FOCUS   = "base focus",
			.SCROLL_BASE  = "scroll base",
			.SCROLL_THUMB = "scroll thumb",
		}

		sw := i32(f32(mu.get_current_container(ctx).body.w) * 0.14)
		mu.layout_row(ctx, {80, sw, sw, sw, sw, -1})
		for label, col in colors {
			mu.label(ctx, label)
			u8_slider(ctx, &ctx.style.colors[col].r, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].g, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].b, 0, 255)
			u8_slider(ctx, &ctx.style.colors[col].a, 0, 255)
			mu.draw_rect(ctx, mu.layout_next(ctx), ctx.style.colors[col])
		}
	}	
}
	
render :: proc(ctx: ^mu.Context) {
	render_texture :: proc(renderer: ^rl.RenderTexture2D, dst: ^rl.Rectangle, src: mu.Rect, color: rl.Color) {
		dst.width = f32(src.w)
		dst.height = f32(src.h)

		rl.BeginTextureMode(renderer^)
		{
			rl.DrawTextureRec(state.atlas_texture.texture, mu_to_rl_Rect(src), rl.Vector2{dst.x, dst.y}, color)
		}
		rl.EndTextureMode()
	}

	command_backing: ^mu.Command

	rl.BeginTextureMode(screen_texture)
	{
		rl.EndScissorMode()
		rl.ClearBackground(mu_to_rl_color(state.bg))
	}
	rl.EndTextureMode()		

	for variant in mu.next_command_iterator(ctx, &command_backing) {		
		switch cmd in variant {
			case ^mu.Command_Text:
				dst := rl.Rectangle{f32(cmd.pos.x), f32(cmd.pos.y), 0, 0}
				for ch in cmd.str do if ch&0xc0 != 0x80 {
					r := min(int(ch), 127)
					src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
					render_texture(&screen_texture, &dst, src, mu_to_rl_color(cmd.color))
					dst.x += dst.width					
				}
			case ^mu.Command_Rect:
				rl.BeginTextureMode(screen_texture)
				{
					rl.DrawRectangle(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h, mu_to_rl_color(cmd.color))
				}
				rl.EndTextureMode()	
			case ^mu.Command_Icon:
				src := mu.default_atlas[cmd.id]
				x := cmd.rect.x + (cmd.rect.w - src.w)/2
				y := cmd.rect.y + (cmd.rect.h - src.h)/2
				render_texture(&screen_texture, &rl.Rectangle {f32(x), f32(y), 0, 0}, src, mu_to_rl_color(cmd.color))
			case ^mu.Command_Clip:
				rl.BeginTextureMode(screen_texture)
				{
					rl.BeginScissorMode(cmd.rect.x, cmd.rect.y, cmd.rect.w, cmd.rect.h)
				}
				rl.EndTextureMode()
			case ^mu.Command_Jump:
				unreachable()
		}
	}

	rl.BeginDrawing()
	{
		rl.ClearBackground(rl.RAYWHITE)
		rl.DrawTextureRec(screen_texture.texture, rl.Rectangle {0, 0, f32(state.screen_width), -f32(state.screen_height)}, rl.Vector2 {0,0}, rl.WHITE)
	}
	rl.EndDrawing()
}

//// Helper functions

// finds the key pos in a key array
array_key_pos :: proc(key_array: ^[dynamic]rl.KeyboardKey, key: rl.KeyboardKey) -> int {
	for i:= len(key_array)-1; i >=0; i -= 1 {
		if key_array[i] == key {return i}
	}
	return -1
}

// convert microui color to raylib color
mu_to_rl_color :: proc(in_color: mu.Color) -> (out_color: rl.Color) {
	return {in_color.r, in_color.g, in_color.b, in_color.a}
}

// convert microui Rect to raylib Rectangle
mu_to_rl_Rect :: proc(in_rect : mu.Rect) -> (out_rect: rl.Rectangle) {
	return {f32(in_rect.x), f32(in_rect.y), f32(in_rect.w), f32(in_rect.h)}
} 