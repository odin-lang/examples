package main
import "core:log"
import "core:mem"
import "vendor:glfw"

WINDOW_TITLE             :: "opengl_model_loading_and_font_rendering"
GL_VERSION_MAJOR         :: 4
GL_VERSION_MINOR         :: 3
WINDOW_WIDTH             :: 1280
WINDOW_HEIGHT            :: 720
OPTION_VSYNC             :: false
OPTION_ANTI_ALIAS        :: true
OPTION_GAMMA_CORRECTION  :: true
SHADER_SOLID_VERT        :: "./glsl/solid.vert"
SHADER_SOLID_FRAG        :: "./glsl/solid.frag"
SHADER_LIGHT_VERT        :: "./glsl/light.vert"
SHADER_LIGHT_FRAG        :: "./glsl/light.frag"
SHADER_FONT_VERT         :: "./glsl/font.vert"
SHADER_FONT_FRAG         :: "./glsl/font.frag"
NUM_POINT_LIGHTS         :: 1
CAM_CLIP_NEAR            :: 0.1
CAM_CLIP_FAR             :: 100
FONT_PATH                :: "./assets/font.png"
FONT_WIDTH               :: 8
FONT_HEIGHT              :: 16
FONT_MAX_CHARS           :: 12000
FONT_SPACING             :: 2
BACKGROUND_COLOR         : [3]f32 : 0.2

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
		primitives    = new([Primitive]Mesh),
		meshes        = make([dynamic]Mesh),
		materials     = make([dynamic]Material),
		models        = make([dynamic]Model),
		dir_light     = directional_light_new(),
		point_light   = point_light_new(),
		camera        = camera_new(),
	}
	init(&app)
	load_scene(&app, .Default)

	// Main Loop
	for !glfw.WindowShouldClose(app.window) {
		input(&app)
		update(&app)
		render(&app)
		glfw.PollEvents()
		free_all(context.temp_allocator)
	}
   
	// Exit the program
	exit(&app)
}
