package main

import "base:intrinsics"

import "core:os"
import "core:math"
import "core:fmt"
import NS "core:sys/darwin/Foundation"

import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

main :: proc() {
	err := metal_main()
	if err != nil {
		fmt.eprintln(err->localizedDescription()->odinString())
		os.exit(1)
	}
}

metal_main :: proc() -> (err: ^NS.Error) {
	@static quit := false

	app := NS.Application.sharedApplication()
	defer app->release()
	app->setActivationPolicy(.Regular) // without this window is not brought to foreground on launch
	app->finishLaunching()

	create_main_menu(app)

	screen_rect := get_main_screen_rect()
	window_size := NS.Size{800, 600}
	window_origin: NS.Point =  {
		NS.Float(math.floor(f64(screen_rect.size.width - window_size.width) / 2)),
		NS.Float(math.floor(f64(screen_rect.size.height - window_size.height) / 2)),
	}

	CustomWindowClass := NS.objc_allocateClassPair(intrinsics.objc_find_class("NSWindow"), "CustomWindow", 0)
	assert(CustomWindowClass != nil)
	keyDown :: proc "c" (self: NS.id, sel: NS.SEL, event: ^NS.Event) { /* ignore key down events */ }
	NS.class_addMethod(CustomWindowClass, intrinsics.objc_find_selector("keyDown:"), NS.IMP(keyDown), "v@:@")
	NS.objc_registerClassPair(CustomWindowClass)
	window := cast(^NS.Window)(NS.class_createInstance(CustomWindowClass, size_of(NS.Window)))
	defer window->release()
	window->initWithContentRect({window_origin, window_size}, { .Resizable, .Closable, .Titled, .Miniaturizable }, .Buffered, NS.NO)
	window->setDelegate(NS.window_delegate_register_and_alloc({
		windowWillClose = proc(^NS.Notification) {
			quit = true
		},
	}, "CustomWindowDelegate", context))
	window->setTitle(NS.MakeConstantString("Use left/right arrow keys to rotate the triangle"))
	window->setIsVisible(true)

	app->activateIgnoringOtherApps(true)


	device := MTL.CreateSystemDefaultDevice()
	defer device->release()

	fmt.println("Metal device:", device->name()->odinString())

	swapchain := CA.MetalLayer.layer()
	defer swapchain->release()

	swapchain->setDevice(device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(window->frame())

	window->contentView()->setLayer(swapchain)
	window->setOpaque(true)
	window->setBackgroundColor(nil)

	library, pso := build_shaders(device) or_return
	defer library->release()
	defer pso->release()

	vertex_positions_buffer, vertex_colors_buffer, arg_buffer := build_buffers(device, library)
	defer arg_buffer->release()

	frame_data_buffer := device->newBuffer(size_of(Frame_Data), {.StorageModeManaged})
	defer frame_data_buffer->release()

	command_queue := device->newCommandQueue()
	defer command_queue->release()

	@static angle: f32

	for !quit {
		{
			NS.scoped_autoreleasepool()
			// Use `NS.Date.distantFuture()` for `expiration` param, so that we idle without wasting any CPU while waiting for events.
			event := app->nextEventMatchingMask(NS.EventMaskAny, NS.Date.distantFuture(), NS.DefaultRunLoopMode, true)
			for event != nil {
				event_type := event->type()
				#partial switch event_type {
				case .KeyDown, .KeyUp:
					code := NS.kVK(event->keyCode())
					#partial switch code {
					case .Escape:
						quit = true
					case .LeftArrow:
						angle -= 0.02
					case .RightArrow:
						angle += 0.02
					}
					fmt.println(event_type, code, event->modifierFlags())
				case:
					fmt.println(event_type, event->locationInWindow(), event->modifierFlags())
				}
				app->sendEvent(event)

				// Once we wake up from idle, process all events in the queue before we can idle again.
				event = app->nextEventMatchingMask(NS.EventMaskAny, nil, NS.DefaultRunLoopMode, true)
			}
			app->updateWindows()
		}

		frame_data := (^Frame_Data)(frame_data_buffer->contentsPointer())
		frame_data.angle = angle
		frame_data_buffer->didModifyRange(NS.Range_Make(0, size_of(Frame_Data)))

		drawable := swapchain->nextDrawable()
		assert(drawable != nil)
		defer drawable->release()

		pass := MTL.RenderPassDescriptor.renderPassDescriptor()
		defer pass->release()

		color_attachment := pass->colorAttachments()->object(0)
		color_attachment->setClearColor(MTL.ClearColor{0.25, 0.5, 1.0, 1.0})
		color_attachment->setLoadAction(.Clear)
		color_attachment->setStoreAction(.Store)
		color_attachment->setTexture(drawable->texture())

		command_buffer := command_queue->commandBuffer()
		defer command_buffer->release()

		render_encoder := command_buffer->renderCommandEncoderWithDescriptor(pass)
		defer render_encoder->release()

		render_encoder->setRenderPipelineState(pso)
		render_encoder->setVertexBuffer(arg_buffer,        0, 0)
		render_encoder->setVertexBuffer(frame_data_buffer, 0, 1)
		render_encoder->useResource(vertex_positions_buffer, {.Read})
		render_encoder->useResource(vertex_colors_buffer, {.Read})
		render_encoder->drawPrimitives(.Triangle, 0, 3)

		render_encoder->endEncoding()

		command_buffer->presentDrawable(drawable)
		command_buffer->commit()
	}

	return nil
}

Frame_Data :: struct {
	angle: f32,
}

build_shaders :: proc(device: ^MTL.Device) -> (library: ^MTL.Library, pso: ^MTL.RenderPipelineState, err: ^NS.Error) {
	shader_src := `
	#include <metal_stdlib>
	using namespace metal;

	struct v2f {
		float4 position [[position]];
		half3 color;
	};

	struct Vertex_Data {
		device packed_float3* positions [[id(0)]];
		device packed_float3* colors    [[id(1)]];
	};

	struct Frame_Data {
		float angle;
	};

	v2f vertex vertex_main(device const Vertex_Data* vertex_data [[buffer(0)]],
						   device const Frame_Data*  frame_data  [[buffer(1)]],
						   uint vertex_id                        [[vertex_id]]) {
		float a = frame_data->angle;
		float3x3 rotation_matrix = float3x3(sin(a), cos(a), 0.0, cos(a), -sin(a), 0.0, 0.0, 0.0, 1.0);
		float3 position = float3(vertex_data->positions[vertex_id]);
		v2f o;
		o.position = float4(rotation_matrix * position, 1.0);
		o.color = half3(vertex_data->colors[vertex_id]);
		return o;
	}

	half4 fragment fragment_main(v2f in [[stage_in]]) {
		return half4(in.color, 1.0);
	}
	`
	shader_src_str := NS.String.alloc()->initWithOdinString(shader_src)
	defer shader_src_str->release()

	library = device->newLibraryWithSource(shader_src_str, nil) or_return

	vertex_function   := library->newFunctionWithName(NS.AT("vertex_main"))
	fragment_function := library->newFunctionWithName(NS.AT("fragment_main"))
	defer vertex_function->release()
	defer fragment_function->release()

	desc := MTL.RenderPipelineDescriptor.alloc()->init()
	defer desc->release()

	desc->setVertexFunction(vertex_function)
	desc->setFragmentFunction(fragment_function)
	desc->colorAttachments()->object(0)->setPixelFormat(.BGRA8Unorm_sRGB)

	pso = device->newRenderPipelineStateWithDescriptor(desc) or_return
	return
}

build_buffers :: proc(device: ^MTL.Device, library: ^MTL.Library) -> (vertex_positions_buffer, vertex_colors_buffer, arg_buffer: ^MTL.Buffer) {
	NUM_VERTICES :: 3
	positions := [NUM_VERTICES][3]f32{
		{-0.8,  0.8, 0.0},
		{ 0.0, -0.8, 0.0},
		{+0.8,  0.8, 0.0},
	}
	colors := [NUM_VERTICES][3]f32{
		{1.0, 0.3, 0.2},
		{0.8, 1.0, 0.0},
		{0.8, 0.0, 1.0},
	}

	vertex_positions_buffer = device->newBufferWithSlice(positions[:], {.StorageModeManaged})
	vertex_colors_buffer    = device->newBufferWithSlice(colors[:],    {.StorageModeManaged})

	vertex_function := library->newFunctionWithName(NS.AT("vertex_main"))
	defer vertex_function->release()

	arg_encoder := vertex_function->newArgumentEncoder(0)
	defer arg_encoder->release()

	arg_buffer = device->newBuffer(arg_encoder->encodedLength(), {.StorageModeManaged})
	arg_encoder->setArgumentBufferWithOffset(arg_buffer, 0)
	arg_encoder->setBuffer(vertex_positions_buffer, 0, 0)
	arg_encoder->setBuffer(vertex_colors_buffer,    0, 1)
	arg_buffer->didModifyRange(NS.Range_Make(0, arg_buffer->length()))

	return
}

create_main_menu :: proc(app: ^NS.Application) {
	main_menu := NS.Menu.alloc()->init()
	main_menu->addItem(NS.MenuItem.alloc()->init())

	main_menu_app_item := main_menu->addItemWithTitle(NS.AT("Metal"), nil, NS.AT(""))
	app_menu := NS.Menu.alloc()->init()
	app_menu->addItemWithTitle(NS.AT("Quit"), intrinsics.objc_find_selector("terminate:"), NS.AT("q"))
	main_menu_app_item->setSubmenu(app_menu)

	main_menu_edit_item := main_menu->addItemWithTitle(NS.AT("Edit"), nil, NS.AT(""))
	edit_menu := NS.Menu.alloc()->init()
	main_menu_edit_item->setSubmenu(edit_menu)

	main_menu_view_item := main_menu->addItemWithTitle(NS.AT("View"), nil, NS.AT(""))
	view_menu := NS.Menu.alloc()->init()
	view_menu->addItemWithTitle(NS.AT("Enter Full Screen"), intrinsics.objc_find_selector("toggleFullScreen:"), NS.AT("f"))
	main_menu_view_item->setSubmenu(view_menu)

	app->setMainMenu(main_menu)
}

get_main_screen_rect :: proc() -> NS.Rect {
	the_screen: NS.Screen
	main_screen := the_screen.mainScreen()

	return main_screen->visibleFrame()
}
