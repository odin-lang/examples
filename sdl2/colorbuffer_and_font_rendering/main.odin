package main
import "core:log"
import "core:mem"
import "vendor:sdl2"

RENDERER_FLAGS           :: sdl2.RendererFlags{.ACCELERATED, .PRESENTVSYNC, .TARGETTEXTURE}
WINDOW_TITLE             :: "sdl2_colorbuffer_and_font_rendering"
WINDOW_FLAGS             :: sdl2.WindowFlags{.SHOWN}
WINDOW_WIDTH             :: 1280
WINDOW_HEIGHT            :: 720
RENDER_WIDTH             :: 1280
RENDER_HEIGHT            :: 720
UI_DRAWS_PER_FRAME_LIMIT :: 100

main :: proc() {
	// Tracking allocator and logger set up
	context.logger = log.create_console_logger()
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)
	defer {
		for _, entry in tracking_allocator.allocation_map {
			log.errorf("%v: Leaked %v bytes", entry.location, entry.size)
		}
		mem.tracking_allocator_destroy(&tracking_allocator)
	}

	// Program initialization
	app := App{
		running = true,
		ui_colorbuffer = &Colorbuffer{ buf = new([RENDER_WIDTH * RENDER_HEIGHT]u32)[:], width = RENDER_WIDTH, height = RENDER_HEIGHT },
		ui_drawn_areas = new([dynamic; UI_DRAWS_PER_FRAME_LIMIT]Rect),
		main_colorbuffer = &Colorbuffer{ buf = new([RENDER_WIDTH * RENDER_HEIGHT]u32)[:], width = RENDER_WIDTH, height = RENDER_HEIGHT },
	}
	if !init_sdl(&app) {
		log.panic("SDL initialization failed.")
	}

	// Main loop
	for app.running {
		input(&app)
		update(&app)
		draw(&app)
		free_all(context.temp_allocator)
	}
	
	// Exit the program
	exit(&app)
}
