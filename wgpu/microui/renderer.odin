package vendor_wgpu_example_microui

import intr "base:intrinsics"

import      "core:fmt"
import      "core:math/linalg"

import mu   "vendor:microui"
import      "vendor:wgpu"

BUFFER_SIZE :: 16384

Renderer :: struct {
	instance: wgpu.Instance,
	surface:  wgpu.Surface,
	adapter:  wgpu.Adapter,
	device:   wgpu.Device,
	config:   wgpu.SurfaceConfiguration,

	module: wgpu.ShaderModule,

	atlas_texture:      wgpu.Texture,
	atlas_texture_view: wgpu.TextureView,

	pipeline_layout: wgpu.PipelineLayout,
	pipeline:        wgpu.RenderPipeline,

	const_buffer: wgpu.Buffer,

	tex_buffer:     wgpu.Buffer,
	vertex_buffer:  wgpu.Buffer,
	color_buffer:   wgpu.Buffer,
	index_buffer:   wgpu.Buffer,

	sampler: wgpu.Sampler,

	bind_group_layout: wgpu.BindGroupLayout,
	bind_group:        wgpu.BindGroup,

	queue: wgpu.Queue,

	curr_encoder: wgpu.CommandEncoder,
	curr_pass:    wgpu.RenderPassEncoder,
	curr_texture: wgpu.SurfaceTexture,
	curr_view:    wgpu.TextureView,

	tex_buf:   [BUFFER_SIZE * 8]f32,
	vert_buf:  [BUFFER_SIZE * 8]f32,
	color_buf: [BUFFER_SIZE * 16]u8,
	index_buf: [BUFFER_SIZE * 6]u32,
	prev_buf_idx: u32,
	buf_idx:      u32,
}

r_init_and_run :: proc() {
	r := &state.renderer

	r.instance = wgpu.CreateInstance(nil)
	r.surface = os_get_surface(r.instance)

	wgpu.InstanceRequestAdapter(r.instance, &{ compatibleSurface = r.surface }, { callback = handle_request_adapter })
}

@(private="file")
handle_request_adapter :: proc "c" (status: wgpu.RequestAdapterStatus, adapter: wgpu.Adapter, message: string, userdata1, userdata2: rawptr) {
	context = state.ctx
	if status != .Success || adapter == nil {
		fmt.panicf("request adapter failure: [%v] %s", status, message)
	}
	state.renderer.adapter = adapter
	wgpu.AdapterRequestDevice(adapter, nil, { callback = handle_request_device })
}

@(private="file")
handle_request_device :: proc "c" (status: wgpu.RequestDeviceStatus, device: wgpu.Device, message: string, userdata1, userdata2: rawptr) {
	context = state.ctx
	if status != .Success || device == nil {
		fmt.panicf("request device failure: [%v] %s", status, message)
	}
	state.renderer.device = device 
	on_adapter_and_device()
}

@(private="file")
on_adapter_and_device :: proc() {
	r := &state.renderer

	width, height := os_get_render_bounds()

	r.config = wgpu.SurfaceConfiguration {
		device      = r.device,
		usage       = { .RenderAttachment },
		format      = .BGRA8Unorm,
		width       = width,
		height      = height,
		presentMode = .Fifo,
		alphaMode   = .Opaque,
	}

	r.const_buffer = wgpu.DeviceCreateBuffer(r.device, &{
		label = "Constant buffer",
		usage = { .Uniform, .CopyDst },
		size  = size_of(matrix[4, 4]f32),
	})

	r.atlas_texture = wgpu.DeviceCreateTexture(r.device, &{
		usage = { .TextureBinding, .CopyDst },
		dimension = ._2D,
		size = { mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT, 1 },
		format = .R8Unorm,
		mipLevelCount = 1,
		sampleCount = 1,
	})
	r.atlas_texture_view = wgpu.TextureCreateView(r.atlas_texture, nil)

	r.sampler = wgpu.DeviceCreateSampler(r.device, &{
		addressModeU  = .ClampToEdge,
		addressModeV  = .ClampToEdge,
		addressModeW  = .ClampToEdge,
		magFilter     = .Nearest,
		minFilter     = .Nearest,
		mipmapFilter  = .Nearest,
		lodMinClamp   = 0,
		lodMaxClamp   = 32,
		compare       = .Undefined,
		maxAnisotropy = 1,
	})

	r.vertex_buffer = wgpu.DeviceCreateBuffer(r.device, &{
		label = "Vertex Buffer",
		usage = { .Vertex, .CopyDst },
		size  = size_of(r.vert_buf),
	})

	r.tex_buffer = wgpu.DeviceCreateBuffer(r.device, &{
		label = "Texture Buffer",
		usage = { .Vertex, .CopyDst },
		size  = size_of(r.tex_buf),
	})

	r.color_buffer = wgpu.DeviceCreateBuffer(r.device, &{
		label = "Color Buffer",
		usage = { .Vertex, .CopyDst },
		size  = size_of(r.color_buf),
	})

	r.index_buffer = wgpu.DeviceCreateBuffer(r.device, &{
		label = "Index Buffer",
		usage = { .Index, .CopyDst },
		size  = size_of(r.index_buf),
	})

	r.bind_group_layout = wgpu.DeviceCreateBindGroupLayout(r.device, &{
		entryCount = 3,
		entries = raw_data([]wgpu.BindGroupLayoutEntry{
			{
				binding = 0,
				visibility = { .Fragment },
				sampler = {
					type = .Filtering,
				},
			},
			{
				binding = 1,
				visibility = { .Fragment },
				texture = {
					sampleType = .Float,
					viewDimension = ._2D,
					multisampled = false,
				},
			},
			{
				binding = 2,
				visibility = { .Vertex },
				buffer = {
					type = .Uniform,
					minBindingSize = size_of(matrix[4, 4]f32),
				},
			},
		}),
	})

	r.bind_group = wgpu.DeviceCreateBindGroup(r.device, &{
		layout = r.bind_group_layout,
		entryCount = 3,
		entries = raw_data([]wgpu.BindGroupEntry{
			{
				binding = 0,
				sampler = r.sampler,
			},
			{
				binding = 1,
				textureView = r.atlas_texture_view,
			},
			{
				binding = 2,
				buffer = r.const_buffer,
				size = size_of(matrix[4, 4]f32),
			},
		}),
	})

	r.module = wgpu.DeviceCreateShaderModule(r.device, &{
		nextInChain = &wgpu.ShaderSourceWGSL{
			sType = .ShaderSourceWGSL,
			code  = #load("shader.wgsl"),
		},
	})

	r.pipeline_layout = wgpu.DeviceCreatePipelineLayout(r.device, &{
		bindGroupLayoutCount = 1,
		bindGroupLayouts = &r.bind_group_layout,
	})
	r.pipeline = wgpu.DeviceCreateRenderPipeline(r.device, &{
		layout = r.pipeline_layout,
		vertex = {
			module = r.module,
			entryPoint = "vs_main",
			bufferCount = 3,
			buffers = raw_data([]wgpu.VertexBufferLayout{
				{
					stepMode = .Vertex,
					arrayStride = 8,
					attributeCount = 1,
					attributes = &wgpu.VertexAttribute{
						format = .Float32x2,
						shaderLocation = 0,
					},
				},
				{
					stepMode = .Vertex,
					arrayStride = 8,
					attributeCount = 1,
					attributes = &wgpu.VertexAttribute{
						format = .Float32x2,
						shaderLocation = 1,
					},
				},
				{
					stepMode = .Vertex,
					arrayStride = 4,
					attributeCount = 1,
					attributes = &wgpu.VertexAttribute{
						format = .Uint32,
						shaderLocation = 2,
					},
				},
			}),
		},
		fragment = &{
			module = r.module,
			entryPoint = "fs_main",
			targetCount = 1,
			targets = &wgpu.ColorTargetState{
				format = .BGRA8Unorm,
				blend = &{
					alpha = {
						srcFactor = .SrcAlpha,
						dstFactor = .OneMinusSrcAlpha,
						operation = .Add,
					},
					color = {
						srcFactor = .SrcAlpha,
						dstFactor = .OneMinusSrcAlpha,
						operation = .Add,
					},
				},
				writeMask = wgpu.ColorWriteMaskFlags_All,
			},
		},
		primitive = {
			topology  = .TriangleList,
			cullMode  = .None,
		},
		multisample = {
			count = 1,
			mask = 0xFFFFFFFF,
		},
	})

	r.queue = wgpu.DeviceGetQueue(r.device)

	wgpu.QueueWriteTexture(
		r.queue,
		&{ texture = r.atlas_texture },
		&mu.default_atlas_alpha,
		mu.DEFAULT_ATLAS_WIDTH*mu.DEFAULT_ATLAS_HEIGHT,
		&{
			bytesPerRow  = mu.DEFAULT_ATLAS_WIDTH,
			rowsPerImage = mu.DEFAULT_ATLAS_HEIGHT,
		},
		&{ mu.DEFAULT_ATLAS_WIDTH, mu.DEFAULT_ATLAS_HEIGHT, 1 },
	)

	r_write_consts()

	wgpu.SurfaceConfigure(r.surface, &r.config)

	os_run()
}

r_resize :: proc() {
	r := &state.renderer

	width, height := os_get_render_bounds()
	r.config.width, r.config.height = width, height
	wgpu.SurfaceConfigure(r.surface, &r.config)

	r_write_consts()
}

r_write_consts :: proc() {
	r := &state.renderer

	// Transformation matrix to convert from screen to device pixels and scale based on DPI.
	dpi := os_get_dpi()
	width, height := os_get_render_bounds()
	fw, fh := f32(width), f32(height)
	transform := linalg.matrix_ortho3d(0, fw, fh, 0, -1, 1) * linalg.matrix4_scale(dpi)

	wgpu.QueueWriteBuffer(r.queue, r.const_buffer, 0, &transform, size_of(transform))
}

r_clear :: proc(color: mu.Color) -> bool {
	r := &state.renderer

	r.buf_idx = 0
	r.prev_buf_idx = 0

	r.curr_texture = wgpu.SurfaceGetCurrentTexture(r.surface)
	switch r.curr_texture.status {
	case .SuccessOptimal, .SuccessSuboptimal:
	// All good, could handle suboptimal here.
	case .Timeout, .Outdated, .Lost:
		if r.curr_texture.texture != nil {
			wgpu.TextureRelease(r.curr_texture.texture)
		}
		r_resize()
		return false
	case .OutOfMemory, .DeviceLost, .Error:
		fmt.panicf("get_current_texture status=%v", r.curr_texture.status)
	}

	r.curr_view = wgpu.TextureCreateView(r.curr_texture.texture, nil)

	r.curr_encoder = wgpu.DeviceCreateCommandEncoder(r.device, nil)

	r.curr_pass = wgpu.CommandEncoderBeginRenderPass(r.curr_encoder, &{
		colorAttachmentCount = 1,
		colorAttachments = raw_data([]wgpu.RenderPassColorAttachment{
			{
				view = r.curr_view,
				loadOp = .Clear,
				storeOp = .Store,
				clearValue = {f64(color.r)/255, f64(color.g)/255, f64(color.b)/255, f64(color.a)/255},
				depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
			},
		}),
	})

	r_bind()

	return true
}

r_bind :: proc() {
	r := &state.renderer

	wgpu.RenderPassEncoderSetPipeline(r.curr_pass, r.pipeline)
	wgpu.RenderPassEncoderSetBindGroup(r.curr_pass, 0, r.bind_group)
	wgpu.RenderPassEncoderSetVertexBuffer(r.curr_pass, 0, r.vertex_buffer, 0, size_of(r.vert_buf))
	wgpu.RenderPassEncoderSetVertexBuffer(r.curr_pass, 1, r.tex_buffer,    0, size_of(r.tex_buf))
	wgpu.RenderPassEncoderSetVertexBuffer(r.curr_pass, 2, r.color_buffer,  0, size_of(r.color_buf))
	wgpu.RenderPassEncoderSetIndexBuffer(r.curr_pass, r.index_buffer, .Uint32, 0, size_of(r.index_buf))
}

r_flush :: proc() {
	r := &state.renderer

	if r.buf_idx == 0 || r.buf_idx == r.prev_buf_idx { return }

	delta := uint(r.buf_idx - r.prev_buf_idx)
	wgpu.RenderPassEncoderDrawIndexed(r.curr_pass, u32(delta * 6), 1, r.prev_buf_idx*6, 0, 0)

	r.prev_buf_idx = r.buf_idx
}

r_full_flush :: proc() {
	r := &state.renderer

	r_submit()

	r.buf_idx = 0
	r.prev_buf_idx = 0

	r.curr_encoder = wgpu.DeviceCreateCommandEncoder(r.device, nil)
	r.curr_pass = wgpu.CommandEncoderBeginRenderPass(r.curr_encoder, &{
		colorAttachmentCount = 1,
		colorAttachments = &wgpu.RenderPassColorAttachment{
			view = r.curr_view,
			loadOp = .Load,
			storeOp = .Store,
		},
	})

	r_bind()
}

r_submit :: proc() {
	r := &state.renderer

	r_flush()

	wgpu.QueueWriteBuffer(r.queue, r.vertex_buffer, 0, &r.vert_buf,  uint(r.buf_idx*8*size_of(f32)))
	wgpu.QueueWriteBuffer(r.queue, r.tex_buffer,    0, &r.tex_buf,   uint(r.buf_idx*8*size_of(f32)))
	wgpu.QueueWriteBuffer(r.queue, r.color_buffer,  0, &r.color_buf, uint(r.buf_idx*16))
	wgpu.QueueWriteBuffer(r.queue, r.index_buffer,  0, &r.index_buf, uint(r.buf_idx*6*size_of(u32)))

	wgpu.RenderPassEncoderEnd(r.curr_pass)
	wgpu.RenderPassEncoderRelease(r.curr_pass)

	command_buffer := wgpu.CommandEncoderFinish(r.curr_encoder, nil)
	wgpu.QueueSubmit(r.queue, { command_buffer })

	wgpu.CommandBufferRelease(command_buffer)
	wgpu.CommandEncoderRelease(r.curr_encoder)
}

r_present :: proc() {
	r := &state.renderer

	r_submit()

	wgpu.SurfacePresent(r.surface)

	wgpu.TextureViewRelease(r.curr_view)
	wgpu.TextureRelease(r.curr_texture.texture)
}

r_render :: proc() {
	if !r_clear(state.bg) {
		return
	}

	command_backing: ^mu.Command
	for variant in mu.next_command_iterator(&state.mu_ctx, &command_backing) {
		switch cmd in variant {
		case ^mu.Command_Text: r_draw_text(cmd.str, cmd.pos, cmd.color)
		case ^mu.Command_Rect: r_draw_rect(cmd.rect, cmd.color)
		case ^mu.Command_Icon: r_draw_icon(cmd.id, cmd.rect, cmd.color)
		case ^mu.Command_Clip: r_set_clip_rect(cmd.rect)
		case ^mu.Command_Jump: unreachable() 
		}
	}

	r_present()
}

push_quad :: proc(dst, src: mu.Rect, color: mu.Color) #no_bounds_check {
	r := &state.renderer

	if (r.buf_idx == BUFFER_SIZE) {
		r_full_flush()
	}

	textvert_idx := r.buf_idx * 8
	color_idx    := r.buf_idx * 16
	element_idx  := u32(r.buf_idx * 4)
	index_idx    := r.buf_idx * 6

	r.buf_idx += 1

	x := f32(src.x) / mu.DEFAULT_ATLAS_WIDTH
	y := f32(src.y) / mu.DEFAULT_ATLAS_HEIGHT
	w := f32(src.w) / mu.DEFAULT_ATLAS_WIDTH
	h := f32(src.h) / mu.DEFAULT_ATLAS_HEIGHT
	copy(r.tex_buf[textvert_idx:], []f32{
		x,     y,
		x + w, y,
		x,     y + h,
		x + w, y + h,
	})

	dx, dy, dw, dh := f32(dst.x), f32(dst.y), f32(dst.w), f32(dst.h)
	copy(r.vert_buf[textvert_idx:], []f32{
		dx,      dy,
		dx + dw, dy,
		dx,      dy + dh,
		dx + dw, dy + dh,
	})

	color := color
	intr.mem_copy_non_overlapping(raw_data(r.color_buf[color_idx + 0:]),  &color, 4)
	intr.mem_copy_non_overlapping(raw_data(r.color_buf[color_idx + 4:]),  &color, 4)
	intr.mem_copy_non_overlapping(raw_data(r.color_buf[color_idx + 8:]),  &color, 4)
	intr.mem_copy_non_overlapping(raw_data(r.color_buf[color_idx + 12:]), &color, 4)

	copy(r.index_buf[index_idx:], []u32{
		element_idx + 0,
		element_idx + 1,
		element_idx + 2,
		element_idx + 2,
		element_idx + 3,
		element_idx + 1,
	})
}

r_draw_rect :: proc(rect: mu.Rect, color: mu.Color) {
	push_quad(rect, mu.default_atlas[mu.DEFAULT_ATLAS_WHITE], color)
}

r_draw_text :: proc(text: string, pos: mu.Vec2, color: mu.Color) {
	dst := mu.Rect{ pos.x, pos.y, 0, 0 }
	for ch in text {
		if ch&0xc0 != 0x80 {
			r := min(int(ch), 127)
			src := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
			dst.w = src.w
			dst.h = src.h
			push_quad(dst, src, color)
			dst.x += dst.w
		}
	}
}

r_draw_icon :: proc(id: mu.Icon, rect: mu.Rect, color: mu.Color) {
	src := mu.default_atlas[id]
	x := rect.x + (rect.w - src.w) / 2
	y := rect.y + (rect.h - src.h) / 2
	push_quad({x, y, src.w, src.h}, src, color)
}

r_set_clip_rect :: proc(rect: mu.Rect) {
	r := &state.renderer
	r_flush()

	x := min(u32(rect.x), r.config.width)
	y := min(u32(rect.y), r.config.height)
	w := min(u32(rect.w), r.config.width-x)
	h := min(u32(rect.h), r.config.height-y)
	wgpu.RenderPassEncoderSetScissorRect(r.curr_pass, x, y, w, h)
}
