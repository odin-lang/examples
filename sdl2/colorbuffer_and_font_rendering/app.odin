package main
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/rand"
import "vendor:sdl2"

App :: struct {
	running:           bool,
	window:            ^sdl2.Window,
	renderer:          ^sdl2.Renderer,
	render_texture:    ^sdl2.Texture,
	keystate:          [^]u8,
	ui_drawn_areas:    ^[dynamic; UI_DRAWS_PER_FRAME_LIMIT]Rect,
	ui_colorbuffer:    ^Colorbuffer,
	main_colorbuffer:  ^Colorbuffer,
	time:              u32,
	prev_time:         u32,
	dt:                f64,
	fps:               int,
	frame:             u32,
}

Colorbuffer :: struct {
	buf: []u32,
	texture: ^sdl2.Texture,
	width: int,
	height: int,
}

Rect :: struct {
	x: int,
	y: int,
	width: int,
	height: int,
}

init_sdl :: proc(app: ^App) -> bool {
	if sdl_res := sdl2.Init(sdl2.INIT_VIDEO); sdl_res < 0 {
		log.fatalf("sdl2.Init returned %v", sdl_res)
		return false
	}
	// Create window
	app.window = sdl2.CreateWindow(WINDOW_TITLE, sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED, WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_FLAGS)
	if app.window == nil {
		log.fatal("sdl2.CreateWindow failed.")
		return false
	}
	// Create renderer
	app.renderer = sdl2.CreateRenderer(app.window, -1, RENDERER_FLAGS)
	if app.renderer == nil {
		log.fatal("sdl2.CreateRenderer failed.")
		return false
	}
	// Create render texture
	app.render_texture = sdl2.CreateTexture(app.renderer, .RGBA32, .TARGET, WINDOW_WIDTH, WINDOW_HEIGHT)
	if app.render_texture == nil {
		log.fatal("sdl2.CreateTexture failed.")
		return false
	}
	// Create colorbuffer texture for UI rendering
	app.ui_colorbuffer.texture = sdl2.CreateTexture(app.renderer, .RGBA32, .STREAMING, i32(app.ui_colorbuffer.width), i32(app.ui_colorbuffer.height))
	if app.ui_colorbuffer.texture == nil {
		log.fatal("sdl2.CreateTexture failed.")
		return false
	}
	// Create main colorbuffer texture
	app.main_colorbuffer.texture = sdl2.CreateTexture(app.renderer, .RGBA32, .STREAMING, i32(app.main_colorbuffer.width), i32(app.main_colorbuffer.height))
	if app.main_colorbuffer.texture == nil {
		log.fatal("sdl2.CreateTexture failed.")
		return false
	}
	sdl2.SetTextureBlendMode(app.ui_colorbuffer.texture, .BLEND)
	app.keystate = sdl2.GetKeyboardState(nil)
	return true
}

input :: proc(app: ^App) {
	e: sdl2.Event
	for sdl2.PollEvent(&e) {
		#partial switch(e.type) {
		case .QUIT: app.running = false
		case .KEYDOWN:
			#partial switch(e.key.keysym.sym) {
			case .ESCAPE: app.running = false
			}
		}
	}
}

update :: proc(app: ^App) {
	// Update timekeeping variables
	app.time = sdl2.GetTicks()
	app.dt = f64(app.time - app.prev_time)
	if app.dt > 0.0 && app.frame % 60 == 0 {
		app.fps = int(1000.0 / app.dt)
	}
	app.dt /= 1000.0
	app.prev_time = app.time
	app.frame += 1
}

draw :: proc(app: ^App) {
	// Draw Odin logo to the main colorbuffer
	r_max: f32 = 0.8
	cos := math.cos_f32(math.PI / 6)
	sin := math.sin_f32(math.PI / 6)
	width := r_max * sin / 3
	for _ in 0 ..< 4 {
		θ := math.PI * 2 * rand.float32()
		r := rand.float32_range(r_max - width, r_max)
		offset: f32
		if rand.float32() < 0.3 || ((θ < 5 * math.PI / 6) && (θ > 4 * math.PI / 6)) || ((θ > 9 * math.PI / 6) && (θ < 10 * math.PI / 6)) {
			offset = width * rand.float32() - width * (rand.float32() > 0.5 ? 3 : 1)
			θ = 10 * math.PI / 6
			r = rand.float32_range(-r_max, r_max) * math.sin(math.acos(abs(offset) / r_max))
		}
		draw_pixel(app.main_colorbuffer, {int(RENDER_WIDTH * 0.5 * (1 + (r * math.cos(θ) + offset * cos) * (f32(RENDER_HEIGHT) / f32(RENDER_WIDTH)))), int(RENDER_HEIGHT * 0.5 * (1 + r * math.sin(θ) + offset * sin))}, rand.uint32())
	}
	// Clear UI buffer
	if len(app.ui_drawn_areas) > 0 {
		for i in 0 ..< len(app.ui_drawn_areas) {
			area := app.ui_drawn_areas[i]
			for x in area.x ..< area.x + area.width {
				for y in area.y ..< area.y + area.height {
					app.ui_colorbuffer.buf[x + y * app.ui_colorbuffer.width] = 0x00_00_00_00
				}
			}
		}
		clear(app.ui_drawn_areas)
	}
	// Draw UI
	draw_ui({2, 0}, app.fps, app.fps >= 50 ? 0xFF_32_DC_32 : (app.fps >= 30 ? 0xFF_32_DC_DC : 0xFF_32_32_DC ), app.ui_colorbuffer, app.ui_drawn_areas)
	draw_ui({2, RENDER_HEIGHT - 16 - 2}, fmt.tprintf("%vx%v", RENDER_WIDTH, RENDER_HEIGHT), 0xFF_FF_FF_FF, app.ui_colorbuffer, app.ui_drawn_areas)
	// Update buffer textures
	sdl2.UpdateTexture(app.ui_colorbuffer.texture, nil, raw_data(app.ui_colorbuffer.buf), i32(app.ui_colorbuffer.width) * 4)
	sdl2.UpdateTexture(app.main_colorbuffer.texture, nil, raw_data(app.main_colorbuffer.buf), i32(app.main_colorbuffer.width) * 4)
	// Render buffer textures
	sdl2.SetRenderTarget(app.renderer, app.render_texture)
	sdl2.SetRenderDrawColor(app.renderer, 0, 0, 0, 255)
	sdl2.RenderClear(app.renderer)
	sdl2.RenderCopy(app.renderer, app.main_colorbuffer.texture, nil, nil)
	sdl2.RenderCopy(app.renderer, app.ui_colorbuffer.texture, nil, nil) 
	sdl2.SetRenderTarget(app.renderer, nil)
	sdl2.RenderCopy(app.renderer, app.render_texture, nil, nil)
	sdl2.RenderPresent(app.renderer)
}

exit :: proc(app: ^App) {
	free(app.ui_drawn_areas)
	delete(app.ui_colorbuffer.buf)
	delete(app.main_colorbuffer.buf)
	sdl2.DestroyWindow(app.window)
	sdl2.Quit()
}
