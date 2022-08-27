package main

import NS "vendor:darwin/Foundation"
import MTL "vendor:darwin/Metal"
import CA "vendor:darwin/QuartzCore"

import SDL "vendor:sdl2"

import "core:fmt"
import "core:os"
import "core:math"
import glm "core:math/linalg/glsl"


Vertex_Data :: struct {
	position: glm.vec3,
	normal:   glm.vec3,
	texcoord: glm.vec2,
}

Instance_Data :: struct #align 16 {
	transform:        glm.mat4,
	color:            glm.vec4,
	normal_transform: glm.mat3,
}

INSTANCE_WIDTH  :: 10
INSTANCE_HEIGHT :: 10
INSTANCE_DEPTH  :: 10
NUM_INSTANCES   :: INSTANCE_WIDTH*INSTANCE_HEIGHT*INSTANCE_DEPTH

Camera_Data :: struct #align 16 {
	perspective_transform:  glm.mat4,
	world_transform:        glm.mat4,
	world_normal_transform: glm.mat3,
}

build_shaders :: proc(device: ^MTL.Device) -> (library: ^MTL.Library, pso: ^MTL.RenderPipelineState, err: ^NS.Error) {
	shader_src := `
	#include <metal_stdlib>
	using namespace metal;

	struct v2f {
		float4 position [[position]];
		float3 normal;
		half3 color;
		float2 texcoord;
	};

	struct Vertex_Data {
		packed_float3 position;
		packed_float3 normal;
		packed_float2 texcoord;
	};

	struct Instance_Data {
		float4x4 transform;
		float4   color;
		float3x3 normal_transform;
	};

	struct Camera_Data {
		float4x4 perspective_transform;
		float4x4 world_transform;
		float3x3 world_normal_transform;
	};

	v2f vertex vertex_main(device const Vertex_Data*   vertex_data   [[buffer(0)]],
	                       device const Instance_Data* instance_data [[buffer(1)]],
	                       device const Camera_Data&   camera_data   [[buffer(2)]],
	                       uint vertex_id                            [[vertex_id]],
	                       uint instance_id                          [[instance_id]]) {
		v2f o;

		const device Vertex_Data&   vd = vertex_data[vertex_id];
		const device Instance_Data& id = instance_data[instance_id];

		float4 pos = float4(vd.position, 1.0);
		pos = id.transform * pos;
		pos = camera_data.perspective_transform * camera_data.world_transform * pos;
		o.position = pos;

		float3 normal = id.normal_transform * float3(vd.normal);
		normal   = camera_data.world_normal_transform * normal;
		o.normal = normal;

		o.texcoord = float2(vd.texcoord.xy);

		o.color = half3(id.color.rgb);
		return o;
	}

	half4 fragment fragment_main(v2f in                              [[stage_in]],
	                             texture2d<half, access::sample> tex [[texture(0)]]) {
		constexpr sampler s(address::repeat, filter::linear);
		half3 texel = tex.sample(s, in.texcoord).rgb;

		// assume light coming from front-top-right
		float3 l = normalize(float3(1.0, 1.0, 0.8));
		float3 n = normalize(in.normal);

		float ndotl = saturate(dot(n, l));

		half3 illum = in.color * texel * 0.1 + in.color * texel * ndotl;
		return half4(illum, 1.0);
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
	desc->setDepthAttachmentPixelFormat(.Depth16Unorm)

	pso = device->newRenderPipelineStateWithDescriptor(desc) or_return
	return
}

build_buffers :: proc(device: ^MTL.Device) -> (vertex_buffer, index_buffer, instance_buffer: ^MTL.Buffer) {
	s :: 0.5
	positions := []Vertex_Data{
		//                                         Texture
		//   Positions           Normals         Coordinates
		{{-s, -s, +s}, { 0,  0,  1}, {0, 1}},
		{{+s, -s, +s}, { 0,  0,  1}, {1, 1}},
		{{+s, +s, +s}, { 0,  0,  1}, {1, 0}},
		{{-s, +s, +s}, { 0,  0,  1}, {0, 0}},

		{{+s, -s, +s}, { 1,  0,  0}, {0, 1}},
		{{+s, -s, -s}, { 1,  0,  0}, {1, 1}},
		{{+s, +s, -s}, { 1,  0,  0}, {1, 0}},
		{{+s, +s, +s}, { 1,  0,  0}, {0, 0}},

		{{+s, -s, -s}, { 0,  0, -1}, {0, 1}},
		{{-s, -s, -s}, { 0,  0, -1}, {1, 1}},
		{{-s, +s, -s}, { 0,  0, -1}, {1, 0}},
		{{+s, +s, -s}, { 0,  0, -1}, {0, 0}},

		{{-s, -s, -s}, {-1,  0,  0}, {0, 1}},
		{{-s, -s, +s}, {-1,  0,  0}, {1, 1}},
		{{-s, +s, +s}, {-1,  0,  0}, {1, 0}},
		{{-s, +s, -s}, {-1,  0,  0}, {0, 0}},

		{{-s, +s, +s}, { 0,  1,  0}, {0, 1}},
		{{+s, +s, +s}, { 0,  1,  0}, {1, 1}},
		{{+s, +s, -s}, { 0,  1,  0}, {1, 0}},
		{{-s, +s, -s}, { 0,  1,  0}, {0, 0}},

		{{-s, -s, -s}, { 0, -1,  0}, {0, 1}},
		{{+s, -s, -s}, { 0, -1,  0}, {1, 1}},
		{{+s, -s, +s}, { 0, -1,  0}, {1, 0}},
		{{-s, -s, +s}, { 0, -1,  0}, {0, 0}},
	}
	indices := []u16{
		 0,  1,  2,  2,  3,  0, // front
		 4,  5,  6,  6,  7,  4, // right
		 8,  9, 10, 10, 11,  8, // back
		12, 13, 14, 14, 15, 12, // left
		16, 17, 18, 18, 19, 16, // top
		20, 21, 22, 22, 23, 20, // bottom
	}

	vertex_buffer   = device->newBufferWithSlice(positions[:], {.StorageModeManaged})
	index_buffer    = device->newBufferWithSlice(indices[:],   {.StorageModeManaged})
	instance_buffer = device->newBuffer(NUM_INSTANCES*size_of(Instance_Data), {.StorageModeManaged})
	return
}

build_texture :: proc(device: ^MTL.Device) -> ^MTL.Texture {
	tw, th :: 128, 128

	desc := MTL.TextureDescriptor.alloc()->init()
	defer desc->release()

	desc->setWidth(tw)
	desc->setHeight(th)
	desc->setPixelFormat(.RGBA8Unorm)
	desc->setStorageMode(.Managed)
	desc->setUsage({.ShaderRead})

	texture := device->newTextureWithDescriptor(desc)

	texture_data := make([][4]u8, tw*th, context.temp_allocator)
	for y in 0..<th {
		for x in 0..<tw {
			is_white := ((x~y) & 0b0100_0000) != 0
			c: u8 = 0xff if is_white else 0x0a
			i := y * tw + x
			texture_data[i].rgb = c
			texture_data[i].a = 0xff
		}
	}

	texture->replaceRegion(MTL.Region{{0, 0, 0}, {tw, th, 1}}, 0, raw_data(texture_data), tw*4)

	return texture
}

metal_main :: proc() -> (err: ^NS.Error) {
	SDL.SetHint(SDL.HINT_RENDER_DRIVER, "metal")
	SDL.setenv("METAL_DEVICE_WRAPPER_TYPE", "1", 0)
	SDL.Init({.VIDEO})
	defer SDL.Quit()

	window := SDL.CreateWindow("Metal in Odin - 07 Texturing",
		SDL.WINDOWPOS_CENTERED, SDL.WINDOWPOS_CENTERED,
		1024, 1024,
		{.ALLOW_HIGHDPI, .HIDDEN, .RESIZABLE},
	)
	defer SDL.DestroyWindow(window)

	window_system_info: SDL.SysWMinfo
	SDL.GetVersion(&window_system_info.version)
	SDL.GetWindowWMInfo(window, &window_system_info)
	assert(window_system_info.subsystem == .COCOA)

	native_window := (^NS.Window)(window_system_info.info.cocoa.window)

	device := MTL.CreateSystemDefaultDevice()
	defer device->release()

	fmt.println(device->name()->odinString())

	swapchain := CA.MetalLayer.layer()
	defer swapchain->release()

	swapchain->setDevice(device)
	swapchain->setPixelFormat(.BGRA8Unorm_sRGB)
	swapchain->setFramebufferOnly(true)
	swapchain->setFrame(native_window->frame())

	native_window->contentView()->setLayer(swapchain)
	native_window->setOpaque(true)
	native_window->setBackgroundColor(nil)

	library, pso := build_shaders(device) or_return
	defer library->release()
	defer pso->release()

	// Build Depth Stencil State
	depth_stencil_state: ^MTL.DepthStencilState
	depth_desc := MTL.DepthStencilDescriptor.alloc()->init()
	depth_desc->setDepthCompareFunction(.Less)
	depth_desc->setDepthWriteEnabled(true)
	depth_stencil_state = device->newDepthStencilState(depth_desc)
	depth_desc->release()

	vertex_buffer, index_buffer, instance_buffer := build_buffers(device)
	defer vertex_buffer->release()
	defer index_buffer->release()
	defer instance_buffer->release()

	camera_buffer := device->newBuffer(size_of(Camera_Data), {.StorageModeManaged})
	defer camera_buffer->release()

	depth_texture: ^MTL.Texture = nil
	defer if depth_texture != nil do depth_texture->release()

	command_queue := device->newCommandQueue()
	defer command_queue->release()

	texture := build_texture(device)
	defer texture->release()

	SDL.ShowWindow(window)
	for quit := false; !quit;  {
		for e: SDL.Event; SDL.PollEvent(&e); {
			#partial switch e.type {
			case .QUIT:
				quit = true
			case .KEYDOWN:
				if e.key.keysym.sym == .ESCAPE {
					quit = true
				}
			}
		}

		w, h: i32
		SDL.GetWindowSize(window, &w, &h)
		aspect_ratio := f32(w)/max(f32(h), 1)


		{
			@static angle: f32
			angle += 0.002

			object_position := glm.vec3{0, 0, -10}
			rt := glm.mat4Translate(object_position)
			rr1 := glm.mat4Rotate({0, 1, 0}, -angle)
			rr0 := glm.mat4Rotate({1, 0, 0}, angle*0.5)
			rt_inv := glm.mat4Translate(-object_position)
			full_obj_rot := rt * rr1 * rr0 * rt_inv


			ix, iy, iz := 0, 0, 0

			instance_data := instance_buffer->contentsAsSlice([]Instance_Data)[:NUM_INSTANCES]
			for instance, idx in &instance_data {
				if ix == INSTANCE_WIDTH {
					ix = 0
					iy += 1
				}
				if iy == INSTANCE_HEIGHT {
					iy = 0
					iz += 1
				}
				defer ix += 1

				scl :: 0.2

				scale := glm.mat4Scale({scl, scl, scl})
				zrot := glm.mat4Rotate({0, 0, 1}, angle * math.sin(f32(ix)))
				yrot := glm.mat4Rotate({0, 1, 0}, angle * math.cos(f32(iy)))

				pos := glm.vec3{
					(f32(ix) - INSTANCE_WIDTH * 0.5) * 2*scl + scl,
					(f32(iy) - INSTANCE_HEIGHT* 0.5) * 2*scl + scl,
					(f32(iz) - INSTANCE_DEPTH * 0.5) * 2*scl,
				}

				translate := glm.mat4Translate(object_position + pos)

				instance.transform = full_obj_rot * translate * yrot * zrot * scale
				instance.normal_transform = glm.mat3(instance.transform)

				r := f32(idx) / NUM_INSTANCES
				instance.color = {r, 1-r, math.sin(math.TAU * r), 1}

			}
			sz := NS.UInteger(len(instance_data)*size_of(instance_data[0]))
			instance_buffer->didModifyRange(NS.Range_Make(0, sz))
		}

		{
			camera_data := camera_buffer->contentsAsType(Camera_Data)
			camera_data.perspective_transform = glm.mat4Perspective(glm.radians_f32(45), aspect_ratio, 0.03, 500)
			camera_data.world_transform = 1
			camera_data.world_normal_transform = glm.mat3(camera_data.world_transform)

			camera_buffer->didModifyRange(NS.Range_Make(0, size_of(Camera_Data)))
		}

		if depth_texture == nil ||
		   depth_texture->width() != NS.UInteger(w) ||
		   depth_texture->height() != NS.UInteger(h) {
			desc := MTL.TextureDescriptor.texture2DDescriptorWithPixelFormat(
				pixelFormat = .Depth16Unorm,
				width = NS.UInteger(w),
				height = NS.UInteger(h),
				mipmapped = false,
			)
			defer desc->release()

			desc->setUsage({.RenderTarget})
			desc->setStorageMode(.Private)

			if depth_texture != nil {
				depth_texture->release()
			}

			depth_texture = device->newTextureWithDescriptor(desc)
		}


		drawable := swapchain->nextDrawable()
		assert(drawable != nil)
		defer drawable->release()

		pass := MTL.RenderPassDescriptor.renderPassDescriptor()
		defer pass->release()

		color_attachment := pass->colorAttachments()->object(0)
		assert(color_attachment != nil)
		color_attachment->setClearColor(MTL.ClearColor{0.1, 0.1, 0.1, 1.0})
		color_attachment->setLoadAction(.Clear)
		color_attachment->setStoreAction(.Store)
		color_attachment->setTexture(drawable->texture())

		depth_attachment := pass->depthAttachment()
		depth_attachment->setTexture(depth_texture)
		depth_attachment->setClearDepth(1.0)
		depth_attachment->setLoadAction(.Clear)
		depth_attachment->setStoreAction(.Store)

		command_buffer := command_queue->commandBuffer()
		defer command_buffer->release()

		render_encoder := command_buffer->renderCommandEncoderWithDescriptor(pass)
		defer render_encoder->release()

		render_encoder->setRenderPipelineState(pso)
		render_encoder->setDepthStencilState(depth_stencil_state)

		render_encoder->setVertexBuffer(buffer=vertex_buffer,   offset=0, index=0)
		render_encoder->setVertexBuffer(buffer=instance_buffer, offset=0, index=1)
		render_encoder->setVertexBuffer(buffer=camera_buffer,   offset=0, index=2)

		render_encoder->setFragmentTexture(texture, 0)

		render_encoder->setCullMode(.Back)
		render_encoder->setFrontFacingWinding(.CounterClockwise)
		render_encoder->drawIndexedPrimitivesWithInstanceCount(.Triangle, 6*6, .UInt16, index_buffer, 0, NUM_INSTANCES)

		render_encoder->endEncoding()

		command_buffer->presentDrawable(drawable)
		command_buffer->commit()
	}

	return nil
}

main :: proc() {
	err := metal_main()
	if err != nil {
		fmt.eprintln(err->localizedDescription()->odinString())
		os.exit(1)
	}
}
