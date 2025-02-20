package microui_SDL3_odin

import "core:fmt"
import "core:strings"
import mu "vendor:microui"
import SDL "vendor:sdl3"

State :: struct {
	mu_ctx:          mu.Context,
	bg:              mu.Color,
	atlas_texture:   ^SDL.Texture,
	window:          ^SDL.Window,
	renderer:        ^SDL.Renderer,
	log_buf:         [1 << 16]byte,
	log_buf_len:     int,
	log_buf_updated: bool,
}

state := State {
	window   = {},
	renderer = {},
	bg       = {90, 95, 100, 255},
}

main :: proc() {

	if !SDL.Init({.VIDEO}) {
		fmt.eprintln(SDL.GetError())
		return
	}
	defer SDL.Quit()

	if !SDL.CreateWindowAndRenderer(
		title = "microui-odin",
		width = 640,
		height = 480,
		window_flags = nil,
		window = &state.window,
		renderer = &state.renderer,
	) {
		fmt.eprintln("CreateWindowAndRenderer:", SDL.GetError())
		return
	}

	if state.window == nil {
		fmt.eprintln(SDL.GetError())
		return
	}
	defer SDL.DestroyWindow(state.window)

	if state.renderer == nil {
		fmt.eprintln("SDL.CreateRenderer:", SDL.GetError())
		return
	}
	defer SDL.DestroyRenderer(state.renderer)

	state.atlas_texture = SDL.CreateTexture(
		state.renderer,
		.RGBA32,
		.TARGET,
		mu.DEFAULT_ATLAS_WIDTH,
		mu.DEFAULT_ATLAS_HEIGHT,
	)
	assert(state.atlas_texture != nil)

	if !SDL.SetTextureBlendMode(state.atlas_texture, {.BLEND}) {
		fmt.eprintln("SDL.SetTextureBlendMode:", SDL.GetError())
		return
	}

	pixels := make([][4]u8, mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT)
	for alpha, i in mu.default_atlas_alpha {
		pixels[i].rgb = 0xff
		pixels[i].a = alpha
	}

	if !SDL.UpdateTexture(state.atlas_texture, nil, raw_data(pixels), 4 * mu.DEFAULT_ATLAS_WIDTH) {
		fmt.eprintln("SDL.UpdateTexture:", SDL.GetError())
		return
	}

	ctx := &state.mu_ctx
	mu.init(
		ctx = ctx, 
		set_clipboard = proc(user_data: rawptr, text: string) -> (ok: bool) {
			cstr := strings.clone_to_cstring(text)
			SDL.SetClipboardText(cstr)
			delete(cstr)
			return true
		}, 
		get_clipboard = proc(user_data: rawptr) -> (text: string, ok: bool) {
			if SDL.HasClipboardText() {
				text = string(cstring(SDL.GetClipboardText()))
				ok = true
			}
			return
		},
		clipboard_user_data = nil,
	)

	ctx.text_width = mu.default_atlas_text_width
	ctx.text_height = mu.default_atlas_text_height

	Resize_Data :: struct {
		ctx:      ^mu.Context,
		renderer: ^SDL.Renderer,
	}

	_ = SDL.AddEventWatch(
		filter = proc "c" (data: rawptr, event: ^SDL.Event) -> bool {
			if event.type == .WINDOW_RESIZED {
				resize_data := (^Resize_Data)(data)
				render(resize_data.ctx, resize_data.renderer)
			}
			return true
		}, 
		userdata = &Resize_Data { ctx = ctx, renderer = state.renderer },
	)

	_ = SDL.StartTextInput(state.window)
	defer _ = SDL.StopTextInput(state.window)

	main_loop: for {
		free_all(context.temp_allocator)

		for e: SDL.Event; SDL.PollEvent(&e);  /**/{

			#partial switch e.type {
			case .QUIT:
				break main_loop

			case .MOUSE_MOTION:	mu.input_mouse_move(ctx, i32(e.motion.x), i32(e.motion.y))
			case .MOUSE_WHEEL:	mu.input_scroll(ctx, i32(e.wheel.x * 30), i32(e.wheel.y * -30))
			case .TEXT_INPUT:	mu.input_text(ctx, string(e.text.text))

			case .MOUSE_BUTTON_DOWN, .MOUSE_BUTTON_UP:
				fn := mu.input_mouse_down if e.type == .MOUSE_BUTTON_DOWN else mu.input_mouse_up

				switch e.button.button {
				case SDL.BUTTON_LEFT:	fn(ctx, i32(e.button.x), i32(e.button.y), .LEFT)
				case SDL.BUTTON_MIDDLE:	fn(ctx, i32(e.button.x), i32(e.button.y), .MIDDLE)
				case SDL.BUTTON_RIGHT:	fn(ctx, i32(e.button.x), i32(e.button.y), .RIGHT)
				}

			case .KEY_DOWN, .KEY_UP:
				fn := mu.input_key_down if e.type == .KEY_DOWN else mu.input_key_up

				if e.type == .KEY_UP && e.key.key == SDL.K_ESCAPE {	
					_ = SDL.PushEvent(&SDL.Event{type = .QUIT})	
				}

				switch e.key.key {
				case SDL.K_LSHIFT:		fn(ctx, .SHIFT)
				case SDL.K_RSHIFT:		fn(ctx, .SHIFT)
				case SDL.K_LCTRL:		fn(ctx, .CTRL)
				case SDL.K_RCTRL:		fn(ctx, .CTRL)
				case SDL.K_LALT:		fn(ctx, .ALT)
				case SDL.K_RALT:		fn(ctx, .ALT)
				case SDL.K_RETURN:		fn(ctx, .RETURN)
				case SDL.K_KP_ENTER:	fn(ctx, .RETURN)
				case SDL.K_BACKSPACE:	fn(ctx, .BACKSPACE)
				case SDL.K_LEFT:		fn(ctx, .LEFT)
				case SDL.K_RIGHT:		fn(ctx, .RIGHT)
				case SDL.K_HOME:		fn(ctx, .HOME)
				case SDL.K_END:			fn(ctx, .END)
				case SDL.K_A:			fn(ctx, .A)
				case SDL.K_X:			fn(ctx, .X)
				case SDL.K_C:			fn(ctx, .C)
				case SDL.K_V:			fn(ctx, .V)
				}
			}
		}

		mu.begin(ctx)
		all_windows(ctx)
		mu.end(ctx)

		render(ctx, state.renderer)
	}
}

render :: proc "contextless" (ctx: ^mu.Context, renderer: ^SDL.Renderer) {
	render_texture :: proc "contextless" (
		renderer: ^SDL.Renderer,
		dst: ^SDL.FRect,
		src: mu.Rect,
		color: mu.Color,
	) {
		dst.w = f32(src.w)
		dst.h = f32(src.h)

		SDL.SetTextureAlphaMod(state.atlas_texture, color.a)
		SDL.SetTextureColorMod(state.atlas_texture, color.r, color.g, color.b)

		SDL.RenderTexture(
			renderer = renderer,
			texture = state.atlas_texture,
			srcrect = &SDL.FRect { 
				f32(src.x), 
				f32(src.y), 
				f32(src.w), 
				f32(src.h),
			},
			dstrect = dst,
		)
	}

	viewport_rect := &SDL.Rect{}

	SDL.GetCurrentRenderOutputSize(renderer, &viewport_rect.w, &viewport_rect.h)
	SDL.SetRenderViewport(renderer, viewport_rect^)
	SDL.SetRenderClipRect(renderer, viewport_rect^)
	SDL.SetRenderDrawColor(renderer, state.bg.r, state.bg.g, state.bg.b, state.bg.a)
	SDL.RenderClear(renderer)

	command_backing: ^mu.Command
	for variant in mu.next_command_iterator(ctx, &command_backing) {

		switch cmd in variant {
		case ^mu.Command_Text:
			dst := SDL.FRect{f32(cmd.pos.x), f32(cmd.pos.y), f32(0), f32(0)}

			for ch in cmd.str {
				if ch & 0xc0 != 0x80 {
					r := min(int(ch), 127)
					src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
					render_texture(renderer, &dst, src, cmd.color)
					dst.x += dst.w
				}
			}

		case ^mu.Command_Rect:
			SDL.SetRenderDrawColor(renderer, cmd.color.r, cmd.color.g, cmd.color.b, cmd.color.a)
			SDL.RenderFillRect(
				renderer = renderer,
				rect = SDL.FRect {
					f32(cmd.rect.x),
					f32(cmd.rect.y),
					f32(cmd.rect.w),
					f32(cmd.rect.h),
				},
			)

		case ^mu.Command_Icon:
			src := mu.default_atlas[cmd.id]
			x := cmd.rect.x + (cmd.rect.w - src.w) / 2
			y := cmd.rect.y + (cmd.rect.h - src.h) / 2
			render_texture(renderer, &SDL.FRect{f32(x), f32(y), f32(0), f32(0)}, src, cmd.color)

		case ^mu.Command_Clip:
			SDL.SetRenderClipRect(
				renderer = renderer,
				rect = SDL.Rect { 
					cmd.rect.x, 
					cmd.rect.y, 
					cmd.rect.w, 
					cmd.rect.h,
				},
			)

		case ^mu.Command_Jump: 
			unreachable()
		}
	}

	SDL.RenderPresent(renderer)
}

u8_slider :: proc(ctx: ^mu.Context, val: ^u8, lo, hi: u8) -> (res: mu.Result_Set) {
	mu.push_id(ctx, uintptr(val))

	@(static) tmp: mu.Real
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

all_windows :: proc(ctx: ^mu.Context) {
	@(static) opts := mu.Options{.NO_CLOSE}

	if mu.window(ctx, "Demo Window", {10, 10, 300, 450}, opts) {
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
				if .CHANGE in mu.checkbox(ctx, fmt.tprintf("%v", opt), &state) {
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
			if .SUBMIT in mu.button(ctx, "Button 1") {write_log("Pressed button 1")}
			if .SUBMIT in mu.button(ctx, "Button 2") {write_log("Pressed button 2")}
			mu.label(ctx, "Test buttons 2:")
			if .SUBMIT in mu.button(ctx, "Button 3") {write_log("Pressed button 3")}
			if .SUBMIT in mu.button(ctx, "Button 4") {write_log("Pressed button 4")}
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
					if .SUBMIT in mu.button(ctx, "Button 1") {write_log("Pressed button 1")}
					if .SUBMIT in mu.button(ctx, "Button 2") {write_log("Pressed button 2")}
				}
			}
			if .ACTIVE in mu.treenode(ctx, "Test 2") {
				mu.layout_row(ctx, {53, 53})
				if .SUBMIT in mu.button(ctx, "Button 3") {write_log("Pressed button 3")}
				if .SUBMIT in mu.button(ctx, "Button 4") {write_log("Pressed button 4")}
				if .SUBMIT in mu.button(ctx, "Button 5") {write_log("Pressed button 5")}
				if .SUBMIT in mu.button(ctx, "Button 6") {write_log("Pressed button 6")}
			}
			if .ACTIVE in mu.treenode(ctx, "Test 3") {
				@(static) checks := [3]bool{true, false, true}
				mu.checkbox(ctx, "Checkbox 1", &checks[0])
				mu.checkbox(ctx, "Checkbox 2", &checks[1])
				mu.checkbox(ctx, "Checkbox 3", &checks[2])

			}
			mu.layout_end_column(ctx)

			mu.layout_begin_column(ctx)
			mu.layout_row(ctx, {-1})
			mu.text(
				ctx,
				"Lorem ipsum dolor sit amet, consectetur adipiscing " +
				"elit. Maecenas lacinia, sem eu lacinia molestie, mi risus faucibus " +
				"ipsum, eu varius magna felis a nulla.",
			)
			mu.layout_end_column(ctx)
		}

		if .ACTIVE in mu.header(ctx, "Background Colour", {.EXPANDED}) {
			mu.layout_row(ctx, {-78, -1}, 68)
			mu.layout_begin_column(ctx)
			{
				mu.layout_row(ctx, {46, -1}, 0)
				mu.label(ctx, "Red:");u8_slider(ctx, &state.bg.r, 0, 255)
				mu.label(ctx, "Green:");u8_slider(ctx, &state.bg.g, 0, 255)
				mu.label(ctx, "Blue:");u8_slider(ctx, &state.bg.b, 0, 255)
			}
			mu.layout_end_column(ctx)

			r := mu.layout_next(ctx)
			mu.draw_rect(ctx, r, state.bg)
			mu.draw_box(ctx, mu.expand_rect(r, 1), ctx.style.colors[.BORDER])
			mu.draw_control_text(
				ctx,
				fmt.tprintf("#%02x%02x%02x", state.bg.r, state.bg.g, state.bg.b),
				r,
				.TEXT,
				{.ALIGN_CENTER},
			)
		}
	}

	if mu.window(ctx, "Log Window", {320, 10, 300, 200}, opts) {
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

		@(static) buf: [128]byte
		@(static) buf_len: int
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

	if mu.window(ctx, "Style Window", {320, 220, 300, 240}) {
		@(static) colors := [mu.Color_Type]string {
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
			.SELECTION_BG = "selection bg",
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
