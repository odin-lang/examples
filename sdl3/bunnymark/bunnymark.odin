package bunnymark

import "core:log"
import "core:mem"
import "core:os"
import "core:thread"
import "core:simd"
import "core:fmt"
import "core:math"
import "core:math/rand"

import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

/*
How to run this example:

You must install sdl-shadercross, just so you can compile the shaders to the target platform from HLSL.
Replace MSL, with DXIL or SPIRV as per your system.
And then change the name of the file to load below, in #load() call.

shadercross shader.hlsl.vert -s HLSL -d MSL -o shader_vert.metal -e main
shadercross shader.hlsl.frag -s HLSL -d MSL -o shader_frag.metal -e main

Then it's just
odin run .
*/

// Embed the shaders, .metal for Macs, it can be .spv for other platforms.
frag_shader_code := #load("shader_frag.metal")
vert_shader_code := #load("shader_vert.metal")

/*
What you will learn from this example:

GPU Instancing      ✅
Bit Packing         ✅
Fixed Update Loop   ✅
Multithreading      ✅
AoS				    ✅
SoA                 ✅
SIMD                🚧
*/

BUNNIES          :: 6_00_000

// If you want to change the resolution, you must update the same
// in the shader.hlsl.vert.
// Here are some common resolutions, you can try out:
// N.B. The packed SpriteAoS struct below, doesn't support x & y beyond certain range.
// HD  - 720p  - 1280 x 720
// FHD - 1080p - 1920 x 1080
// QHD - 2k    - 2560 x 1440 (Ultra Wide)
// UHD - 4k    - 3840 x 2160 (Consumer Grade)
// DCI - 4k    - 4096 x 2160 (Digital Cinema, Wider)
SCREEN_SIZE      :: [2]i32{1280, 720}

MAX_FPS          :: f64(60)
FIXED_DELTA_TIME :: 1 / MAX_FPS
MAX_FRAME_SKIP   :: 5

W      :: 4
Vecf32 :: #simd[W]f32

Vec3   :: [3]f32
Vec2   :: [2]f32
Vec4   :: [4]f32

// Used to transfer packed data to the GPU as SSBO.
// Because sending a million sprites data across to GPU can become huge.
// Notice how this doesn't even have velocity.
// If you want to support larger resolution, try changing the packed bits around.
// You can even use bit fields! (https://odin-lang.org/docs/overview/#bit-fields)
SpriteAoS  :: struct {
	position_and_color: u32, // [x, x, x, x, x, x, x, x, x, x, x, y, y, y, y, y, y, y, s, s, s, s, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
}
// This struct will be represented as:
// {
// 	x : []f32,
// 	y : []f32,
// 	vx: []f32,
// 	vy: []f32,
// }
// by the power of #soa, by Odin.
SpriteSoA  :: struct #align(16) {
	x , y : f32,
	vx, vy: f32
}

// Used to send slices out to threads in the thread pool, so that they can loop of 100,000 entities in parallel.
ThreadTask :: struct {
	dt          :      f32,
	sprites_aos :      []SpriteAoS,
	sprites_soa : #soa []SpriteSoA
}
// Reusable resources, returned by populate bunnies, so we don't keep re instanciating them.
Buffers    :: struct {
	transfer_mem                : rawptr,
	transfer_buf                : ^sdl.GPUTransferBuffer,
	sprites_instances_buffer    : ^sdl.GPUBuffer,
	sprites_instances_byte_size : int,
}

// Globally accessible resources, just so we don't have to pass them around.
gpu      : ^sdl.GPUDevice
window   : ^sdl.Window
pipeline : ^sdl.GPUGraphicsPipeline
sampler  : ^sdl.GPUSampler

init :: proc() {
	sdl.SetLogPriorities(.VERBOSE)

	ok := sdl.Init({.VIDEO}); assert(ok)

	sdl.SetHint(sdl.HINT_RENDER_GPU_DEBUG   , "1")
	sdl.SetHint(sdl.HINT_RENDER_VULKAN_DEBUG, "1")

	window = sdl.CreateWindow("Bunnymark | FPS: 60.00 (0.02 ms) | Fixed Updates: 60.00 Hz", SCREEN_SIZE.x, SCREEN_SIZE.y, {}); assert(window != nil)
	ok     = sdl.RaiseWindow(window); assert(ok)

	gpu    = sdl.CreateGPUDevice({.MSL, .DXIL, .SPIRV}, true, nil);        assert(gpu != nil)
	ok     = sdl.ClaimWindowForGPUDevice  (gpu, window);                   assert(ok)
	ok     = sdl.SetGPUSwapchainParameters(gpu, window, .SDR, .IMMEDIATE); assert(ok)
}

setup_pipeline :: proc() {
	vert_shader  := sdl.CreateGPUShader(
		gpu,
		{
			code_size = len(vert_shader_code),
			code = raw_data(vert_shader_code),
			entrypoint           = "main0",
			format               = {.MSL},
			stage                = .VERTEX,
			num_uniform_buffers  = 1,    // for UBO
			num_samplers         = 0,
			num_storage_buffers  = 1,    // for SSBO
			num_storage_textures = 0,
			props                = 0
		},
	)
	frag_shader := sdl.CreateGPUShader(
		gpu,
		{
			code_size            = len(frag_shader_code),
			code                 = raw_data(frag_shader_code),
			entrypoint           = "main0",
			format               = {.MSL},
			stage                = .FRAGMENT,
			num_uniform_buffers  = 0,
			num_samplers         = 1,
			num_storage_buffers  = 0,
			num_storage_textures = 0,
			props                = 0
		},
	)

	pipeline = sdl.CreateGPUGraphicsPipeline(
		gpu,
		{
			fragment_shader = frag_shader,
			vertex_shader   = vert_shader,
			primitive_type  = .TRIANGLESTRIP,
			rasterizer_state = {
				fill_mode                  = .FILL,
	            cull_mode                  = .NONE,               // ✅ disable face culling
	            front_face                 = .COUNTER_CLOCKWISE,  // not critical when culling=NONE
	            depth_bias_constant_factor = 0.0,
	            depth_bias_slope_factor    = 0.0,
			},
	        depth_stencil_state = {
	            enable_depth_test  = false,                       // ✅ disable depth testing
	            enable_depth_write = false,                       // ✅ don't write to depth buffer
	            compare_op         = .NEVER,
	        },
			target_info = {
				num_color_targets               = 1,
				color_target_descriptions       = &(sdl.GPUColorTargetDescription {
					format                      = sdl.GetGPUSwapchainTextureFormat(gpu, window),
					blend_state                 = (sdl.GPUColorTargetBlendState){
						enable_blend            = true,
						alpha_blend_op          = sdl.GPUBlendOp.ADD,
						color_blend_op          = sdl.GPUBlendOp.ADD,
						color_write_mask        = {.R, .G, .B},
						enable_color_write_mask = true,
						src_color_blendfactor   = sdl.GPUBlendFactor.ONE,
						src_alpha_blendfactor   = sdl.GPUBlendFactor.ONE,
						dst_color_blendfactor   = sdl.GPUBlendFactor.ONE_MINUS_SRC_ALPHA,
						dst_alpha_blendfactor   = sdl.GPUBlendFactor.ONE_MINUS_SRC_ALPHA,
					}
				}),
				has_depth_stencil_target = false,
				depth_stencil_format     = .INVALID                // ✅ no depth buffer
			},
		},
	)

	sdl.ReleaseGPUShader(gpu, vert_shader)
	sdl.ReleaseGPUShader(gpu, frag_shader)

	sampler = sdl.CreateGPUSampler(gpu, {
		min_filter     = .NEAREST,
		mag_filter     = .NEAREST,
		mipmap_mode    = .NEAREST,
		address_mode_u = .CLAMP_TO_EDGE,
		address_mode_v = .CLAMP_TO_EDGE,
		address_mode_w = .CLAMP_TO_EDGE,
	})
}

load_bunny_texture :: proc() -> (texture: ^sdl.GPUTexture) {
	// Load the "./assets/bunnys.png", to see multicolored bunnies.
	// N.B. You must uncomment some lines in `shader.hlsl.vert` file to see those bunnies properly.
	surface := img.Load("./assets/wabbit_alpha.png"); assert(surface != nil)
	premultiply_surface_alpha_bitwise(surface)
	defer sdl.DestroySurface(surface)

	pixels_byte_size := surface.w * surface.h * 4

	texture = sdl.CreateGPUTexture(gpu, {
		type                 = .D2,
		format               = .R8G8B8A8_UNORM,
		usage                = {.SAMPLER},
		width                = u32(surface.w),
		height               = u32(surface.h),
		layer_count_or_depth = 1,
		num_levels           = 1,
	})

	tex_transfer_buf := sdl.CreateGPUTransferBuffer(gpu, {
		usage = .UPLOAD,
		size  = u32(pixels_byte_size)
	})

	tex_transfer_mem := sdl.MapGPUTransferBuffer(gpu, tex_transfer_buf, false)
	mem.copy(tex_transfer_mem, surface.pixels, int(pixels_byte_size))
	sdl.UnmapGPUTransferBuffer(gpu, tex_transfer_buf)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
	copy_pass    := sdl.BeginGPUCopyPass(copy_cmd_buf)

	sdl.UploadToGPUTexture(copy_pass,
		{ transfer_buffer = tex_transfer_buf },
		{ texture = texture, w = u32(surface.w), h = u32(surface.h), d = 1 },
		false
	)

	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf); assert(ok)

	sdl.ReleaseGPUTransferBuffer(gpu, tex_transfer_buf)

	return texture
}

populate_bunnies :: proc(sprites_soa: ^#soa[]SpriteSoA, sprites_aos: ^[]SpriteAoS) -> Buffers {
	for i in 0..<BUNNIES {
		x := rand.float32_range(0, f32(SCREEN_SIZE.x))
		y := rand.float32_range(0, f32(SCREEN_SIZE.y))

		sprites_aos[i].position_and_color = 0 | u32(x) << 21 | u32(y) << 11 | u32(sdl.rand(5)) << 7

		sprites_soa.x [i] = x
		sprites_soa.y [i] = y
		sprites_soa.vx[i] = rand.float32_range(-18, 20) + 2
		sprites_soa.vy[i] = rand.float32_range(-16, 20) + 4
	}

	sprites_instances_byte_size := BUNNIES * size_of(SpriteAoS)

	sprites_instances_buffer := sdl.CreateGPUBuffer(gpu, {
		usage = {.GRAPHICS_STORAGE_READ},
		size  = u32(sprites_instances_byte_size)
	})
	transfer_buf := sdl.CreateGPUTransferBuffer(gpu, {
		usage = .UPLOAD,
		size  = u32(sprites_instances_byte_size)
	})
	transfer_mem := sdl.MapGPUTransferBuffer(gpu, transfer_buf, true)
	mem.copy(transfer_mem, raw_data(sprites_aos[:]), sprites_instances_byte_size)

	copy_cmd_buf := sdl.AcquireGPUCommandBuffer(gpu)
	copy_pass    := sdl.BeginGPUCopyPass(copy_cmd_buf)
	sdl.UploadToGPUBuffer(copy_pass,
		{ transfer_buffer = transfer_buf },
		{ buffer          = sprites_instances_buffer,
		  size            = u32(sprites_instances_byte_size) },
		true
	)
	sdl.EndGPUCopyPass(copy_pass)
	ok := sdl.SubmitGPUCommandBuffer(copy_cmd_buf); assert(ok)

	return {
		transfer_buf                = transfer_buf,
		transfer_mem                = transfer_mem,
		sprites_instances_buffer    = sprites_instances_buffer,
		sprites_instances_byte_size = sprites_instances_byte_size,
	}
}

simulate :: proc(t: thread.Task) {
	data := cast(^ThreadTask)t.data

	vxs  := data.sprites_soa.vx
	vys  := data.sprites_soa.vy

	for i := 0; i < len(data.sprites_aos); i += 100 {
		#unroll for j in 0..<100 {
			idx := i + j
			if idx >= len(data.sprites_aos) do break

			packed := data.sprites_aos[idx].position_and_color

			x := i32(packed >> 21 & 0x7FF)
			y := i32(packed >> 11 & 0x3FF)
			s := i32(packed >>  7 & 0xF  )

			// Apply velocity
		    x += i32(vxs[idx])
		    y += i32(vys[idx])

		    // Bounce X
		    if x < 0 {
			    x        = -x
			    vxs[idx] = -vxs[idx]
			} else if x > SCREEN_SIZE.x {
			    x        = 2 * SCREEN_SIZE.x - x
			    vxs[idx] = -vxs[idx]
			}

		    // Bounce Y
		    if y < 0 {
		        y        = -y
		        vys[idx] = -vys[idx]
		    } else if y > SCREEN_SIZE.y {
		        y        = 2 * SCREEN_SIZE.y - y
		        vys[idx] = -vys[idx]
		    }

			packed = u32((i32(x) << 21) | (i32(y) << 11) | (i32(s) << 8))

			data.sprites_aos[idx].position_and_color = packed
		}
	}
}

simulate_soa :: proc(t: thread.Task) {
	data := cast(^ThreadTask)t.data

	// Already reaches AoS perf, by looping over arrays separately (x, y: u32, vx, vy: f32)
	xs  := data.sprites_soa.x
	ys  := data.sprites_soa.y
	vxs := data.sprites_soa.vx
	vys := data.sprites_soa.vy

	dt  := data.dt
	n   := len(data.sprites_soa)

	for i in 0..<n {
		xs[i] += vxs[i] * dt

		if xs[i] < 0 {
		    xs[i]  = -xs[i]
		    vxs[i] = -vxs[i]
		} else if xs[i] > f32(SCREEN_SIZE.x) {
		    xs[i]  = 2 * f32(SCREEN_SIZE.x) - xs[i]
		    vxs[i] = -vxs[i]
		}
	}
	for i in 0..<n {
		 ys[i] += vys[i] * dt

		if ys[i] < 0 {
		    ys[i]  = -ys[i]
		    vys[i] = -vys[i]
		} else if ys[i] > f32(SCREEN_SIZE.y) {
		    ys[i]  = 2 * f32(SCREEN_SIZE.y) - ys[i]
		    vys[i] = -vys[i]
		}
	}
	for i in 0..<n {
		packed := data.sprites_aos[i].position_and_color
		s      := i32(packed >>  7 & 0xF)
		data.sprites_aos[i].position_and_color = (u32(xs[i]) << 21) | (u32(ys[i]) << 11) | (u32(s) << 7)
	}
}

simulate_soa_simd :: proc(t: thread.Task) {
	data := cast(^ThreadTask)t.data

	xs   := data.sprites_soa.x
	ys   := data.sprites_soa.y
	vxs  := data.sprites_soa.vx
	vys  := data.sprites_soa.vy

	n    := len(data.sprites_soa)

    screen_x := Vecf32(SCREEN_SIZE.x)
    screen_y := Vecf32(SCREEN_SIZE.y) 
    zero     := Vecf32(0.0)
    two      := Vecf32(2.0)

    index    := iota(Vecf32)
    mask     := simd.lanes_lt(index, Vecf32(n))

	// X Axis
	i := 0
	for ; i+4 <= n; i += 4 {
		// load lanes from slices
        x  := simd.from_slice(Vecf32,  xs[i : i + W])
        vx := simd.from_slice(Vecf32, vxs[i : i + W])

        x = simd.add(x, vx)

        // compute bounce masks (per-lane)
        mask_lt  := simd.lanes_lt(x, zero)                  // x < 0
        vx        = simd.select(mask_lt, +simd.abs(vx), vx)

        mask_gt  := simd.lanes_gt(x, screen_x)              // x > screen_x
        vx        = simd.select(mask_gt, -simd.abs(vx), vx)

        mask_any := mask_lt | mask_gt                       // lanes that bounced

        simd.masked_store(&xs [i], x, mask)
        simd.masked_store(&vxs[i], vx, mask_any)
	}

	// Tail for X
	for ; i < n; i += 1 {
		xs[i] += vxs[i]

		if xs[i] < 0 {
			xs[i]  = -xs[i]
			vxs[i] = -vxs[i]
		} else if xs[i] > f32(SCREEN_SIZE.x) {
			xs[i]  = 2 * f32(SCREEN_SIZE.x) - xs[i]
			vxs[i] = -vxs[i]
		}
	}

	// Y Axis
	i = 0
	for ; i+4 <= n; i += 4 {
		y  := simd.from_slice(Vecf32,  ys[i : i + W])
        vy := simd.from_slice(Vecf32, vys[i : i + W])

        y = simd.add(y, vy)

        // compute bounce masks (per-lane)
        mask_lt  := simd.lanes_lt(y, zero)                  // y < 0
        vy        = simd.select(mask_lt, +simd.abs(vy), vy)

        mask_gt  := simd.lanes_gt(y, screen_y)              // y > screen_y
        vy        = simd.select(mask_gt, -simd.abs(vy), vy)

        mask_any := mask_lt | mask_gt                       // lanes that bounced

        simd.masked_store(&ys [i], y, mask)
        simd.masked_store(&vys[i], vy, mask_any)
	}

	// Tail for Y
	for ; i < n; i += 1 {
		ys[i] += vys[i]

		if ys[i] < 0 {
			ys[i]  = -ys[i]
			vys[i] = -vys[i]
		} else if ys[i] > f32(SCREEN_SIZE.y) {
			ys[i]  = 2 * f32(SCREEN_SIZE.y) - ys[i]
			vys[i] = -vys[i]
		}
	}

	// Pack-Em-up
	for i in 0..<n {
		data.sprites_aos[i].position_and_color =
			(u32(xs[i]) << 21) | (u32(ys[i]) << 11) | (u32(3) << 8)
	}
}

main :: proc() {
	// ---- Arena Allocator Init ----
	arena_mem, err := mem.make_aligned([]byte, BUNNIES * size_of(SpriteSoA) + BUNNIES * size_of(SpriteAoS) + mem.DYNAMIC_ARENA_BLOCK_SIZE_DEFAULT, 16); assert(err == mem.Allocator_Error.None)
	arena: mem.Arena
	mem.arena_init(&arena, arena_mem)
	arena_alloc    := mem.arena_allocator(&arena)
	defer delete(arena_mem)
	// ---- Arena Allocator Init ----

	// ---- App Init ----
	init()
	setup_pipeline()
	bunny_texture := load_bunny_texture()

	sprites_soa := make(#soa[]SpriteSoA, BUNNIES, arena_alloc)
	sprites_aos := make(    []SpriteAoS, BUNNIES, arena_alloc)

	buffers     := populate_bunnies(&sprites_soa, &sprites_aos)

	defer sdl.UnmapGPUTransferBuffer  (gpu, buffers.transfer_buf)
	defer sdl.ReleaseGPUTransferBuffer(gpu, buffers.transfer_buf)
	// ---- App Init ----

	// ---- Multithreading Init ----
	start_id, end_id := 0, 0

	thread_count := os.processor_core_count()
	chunks       := int(math.ceil(f64(BUNNIES) / f64(thread_count)))
	data         : ^ThreadTask

	pool: thread.Pool
	thread.pool_init(&pool, context.allocator, thread_count)
	thread.pool_start(&pool)
	defer thread.pool_destroy(&pool)
	// ---- Multithreading Init ----

	copy_cmd_buf  : ^sdl.GPUCommandBuffer
	copy_pass     : ^sdl.GPUCopyPass
	swapchain_tex : ^sdl.GPUTexture
	cmd_buf       : ^sdl.GPUCommandBuffer
	render_pass   : ^sdl.GPURenderPass
	color_target  :  sdl.GPUColorTargetInfo

	ok            : bool
	text          : cstring

	prev_counter              := sdl.GetPerformanceCounter()
	delta_ticks, curr_counter : u64
	updates, fixed_updates    : int
	accumulator, new_time, last_time, dt, alpha: f64 = 0, 0, 0, 0, 0

	frame_count               : u16
	time_accumulator          : f64
	updates_per_sec           : f64
	fps_smoothed, current_fps : f64 = 60, 60

	main_loop: for {
		curr_counter = sdl.GetPerformanceCounter()
		delta_ticks  = curr_counter - prev_counter
		prev_counter = curr_counter

		dt = f64(delta_ticks) / f64(sdl.GetPerformanceFrequency())

		ev: sdl.Event
		for sdl.PollEvent(&ev) {
			#partial switch ev.type {
			case .QUIT:
				break main_loop
			case .KEY_DOWN:
				if ev.key.scancode == .ESCAPE do break main_loop
			}
		}

		accumulator += dt
		updates      = 0

		// ------ Fixed Update Loop ------
		for ;accumulator >= FIXED_DELTA_TIME && updates < MAX_FRAME_SKIP; accumulator -= FIXED_DELTA_TIME {
			updates       += 1
			fixed_updates += 1

			for i in 0..<thread_count {
				start_id = i * chunks
				end_id   = math.min(start_id + chunks, BUNNIES)
				if start_id >= BUNNIES do break

				data              = new(ThreadTask)
				data.dt           = f32(FIXED_DELTA_TIME) * 20
				data.sprites_soa  = sprites_soa[start_id:end_id]
				data.sprites_aos  = sprites_aos[start_id:end_id]

				// thread.pool_add_task(&pool, context.allocator, simulate,          data, i)
				thread.pool_add_task(&pool, context.allocator, simulate_soa,      data, i)
				// thread.pool_add_task(&pool, context.allocator, simulate_soa_simd, data, i)
			}

		    thread.pool_finish(&pool)

		    // This freezes the screen while trying to quit, even though it runs a bit faster.
		    // Adding boundary collision slows it down to the same speed as Multi Threaded one.
			// for i := 0; i < BUNNIES; i += 100 {
			// 	#unroll for j in 0..<100 {
			// 		idx := i + j
			// 		if idx >= BUNNIES do break

			// 		packed = sprites_instances[idx].position_and_color

			// 		x = packed >> 21 & 0x7FF
			// 		y = packed >> 11 & 0x3FF
			// 		c = packed >>  8 & 0x7
			// 		x = x < u32(SCREEN_SIZE.x) ? x + u32(sdl.rand(20)) : 0
			// 		y = y < u32(SCREEN_SIZE.y) ? y + u32(sdl.rand(20)) : 0

			// 		packed = (x << 21) | (y << 11) | (c << 8)

			// 		sprites_instances[idx].position_and_color = packed
			// 	}
			// }

			mem.copy(buffers.transfer_mem, raw_data(sprites_aos), buffers.sprites_instances_byte_size)

			copy_cmd_buf = sdl.AcquireGPUCommandBuffer(gpu)
			copy_pass    = sdl.BeginGPUCopyPass(copy_cmd_buf)
			sdl.UploadToGPUBuffer(copy_pass,
				{ transfer_buffer = buffers.transfer_buf },
				{ buffer          = buffers.sprites_instances_buffer,
				  size            = u32(buffers.sprites_instances_byte_size) },
				true
			)
			sdl.EndGPUCopyPass(copy_pass)
			ok = sdl.SubmitGPUCommandBuffer(copy_cmd_buf); assert(ok)
		}

		if updates >= MAX_FRAME_SKIP {
			accumulator = 0.0
		}
		alpha   = accumulator / FIXED_DELTA_TIME

		cmd_buf = sdl.AcquireGPUCommandBuffer(gpu)
		ok      = sdl.WaitAndAcquireGPUSwapchainTexture(
			cmd_buf,
			window,
			&swapchain_tex,
			nil,
			nil,
		); assert(ok)

		if swapchain_tex != nil {
			color_target = sdl.GPUColorTargetInfo {
				texture     = swapchain_tex,
				load_op     = .CLEAR,
				clear_color = {1, 1, 1, 1},
				store_op    = .STORE,
				cycle 		= false,
			}
			render_pass = sdl.BeginGPURenderPass(cmd_buf, &color_target, 1, nil)

			sdl.BindGPUGraphicsPipeline    (render_pass, pipeline)
			sdl.BindGPUVertexStorageBuffers(render_pass, 0, &buffers.sprites_instances_buffer, 1)
			sdl.BindGPUFragmentSamplers    (render_pass, 0, &(sdl.GPUTextureSamplerBinding {
				texture = bunny_texture,
				sampler = sampler,
			}), 1)
			sdl.DrawGPUPrimitives(render_pass, 4, BUNNIES, 0, 0)
			sdl.EndGPURenderPass (render_pass)
		}

		ok = sdl.SubmitGPUCommandBuffer(cmd_buf); assert(ok)

		frame_count      += 1
		time_accumulator += dt
		if time_accumulator >= 1 {
			current_fps     = f64(frame_count) / time_accumulator
			fps_smoothed    = 0.9 * fps_smoothed + 0.1 * current_fps
			updates_per_sec = f64(fixed_updates) / time_accumulator

			text = fmt.caprintf("Bunnymark | FPS: %.2f (%.2f ms) | Fixed Updates: %.2f Hz", current_fps, dt, updates_per_sec)
			sdl.SetWindowTitle(window, text)

			frame_count      = 0
			fixed_updates    = 0
			time_accumulator = 0
		}
	}
}

premultiply_surface_alpha_bitwise :: proc(surf: ^sdl.Surface) {
    pixels := cast(^u32) surf.pixels; assert(surf.format == .ABGR8888)

    for i in 0..< surf.w * surf.h {
    	p := mem.ptr_offset(pixels, i)

    	a := p^ >> 24 & 0xFF
    	b := p^ >> 16 & 0xFF
    	g := p^ >> 8  & 0xFF
    	r := p^       & 0xFF

    	unchanged_alpha := a
        a /= 255.0

        p^ = unchanged_alpha << 24 | b * a << 16 | g * a << 8 | r * a
    }
}

iota :: proc ($V: typeid/#simd[$N]$E) -> (result: V) {
	for i in 0..<N {
		result = simd.replace(result, i, E(i))
	}
	return
}
