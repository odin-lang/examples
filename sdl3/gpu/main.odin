package sdl3_gpu_example

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:strings"
import "core:time"
import "vendor:sdl3"

Mat4     :: matrix[4, 4]f32
Vec2     :: [2]f32
Vec4     :: [4]f32
Quad     :: [4]Vec2
Color    :: [4]f32

WHITE    :: Color{1, 1, 1, 1}
BG_COLOR :: Color{0.09, 0.09, 0.11, 1.0}

Draw_Mode :: enum i32 {
	MSDF     = 0,
	Squircle = 1,
	Texture  = 2,
}

// Vertex / uniform layouts (must match shaders/shader.vert & .frag)
Vertex :: struct {
	pos:   Vec2,
	uv:    Vec2,
	color: Color,
}

Vert_Uniforms :: struct {
	mvp: Mat4,
}

Frag_Uniforms :: struct {
	mode:            Draw_Mode,
	screen_px_range: f32,
	half_size:       Vec2,
	corner_radius:   f32,
	squircle_blend:  f32,
	_pad0:           f32,
	_pad1:           f32,
}

Draw_Call :: struct {
	texture:     ^sdl3.GPUTexture,
	frag:        Frag_Uniforms,
	index_off:   u32,
	index_count: u32,
}

Renderer :: struct {
	device:          ^sdl3.GPUDevice,
	window:          ^sdl3.Window,
	pipeline:        ^sdl3.GPUGraphicsPipeline,
	white_tex:       Texture,         // 1x1 white pixel, used for solid rects
	nearest_sampler: ^sdl3.GPUSampler,
	linear_sampler:  ^sdl3.GPUSampler,

	// CPU-side batch, rebuilt every frame.
	verts:           [dynamic]Vertex,
	idxs:            [dynamic]u16,
	calls:           [dynamic]Draw_Call,

	// GPU-side buffers, grown (re-created) on demand.
	vbo:             ^sdl3.GPUBuffer,
	ibo:             ^sdl3.GPUBuffer,
	vbo_cap:         int,
	ibo_cap:         int,

	w, h:            u32,
}

Texture :: struct {
	gpu:  ^sdl3.GPUTexture,
	size: Vec2,
}

Glyph :: struct {
	advance:    f32,
	has_bounds: bool,
	plane:      Vec4, // em units, relative to baseline
	uv:         Quad,   // uv coords
}

Font :: struct {
	texture:          Texture,
	atlas_w, atlas_h: f32,
	distance_range:   f32,
	atlas_size_px:    f32, // px-per-em the atlas was generated at
	variants:         []Font_Variant,
}

Font_Variant :: struct {
	glyphs:      map[rune]Glyph,
	line_height: f32, // em units
	ascender:    f32,
	descender:   f32,
}

Bounds :: struct {
	left, bottom, right, top: f32,
}

/*
Font generated using:

msdf-atlas-gen -font DejaVuSans.ttf ^
	  -and -font DejaVuSans-Oblique.ttf ^
	  -and -font DejaVuSans-Bold.ttf ^
	  -type mtsdf -size 128 -pxrange 8 -coloringstrategy inktrap -errorcorrection auto-full ^
	  -imageout font.png -json font.json || exit /b 1

NOTE: Kerning pairs aren't yet loaded, nor handled during drawing.
*/
Atlas_JSON :: struct {
	atlas: struct {
		distance_range: f32 `json:"distanceRange"`,
		size:           f32,
		width:          f32,
		height:         f32,
	},
	variants: []struct {
		metrics: struct {
			line_height: f32 `json:"lineHeight"`,
			ascender:    f32,
			descender:   f32,
		},
		glyphs: []struct {
			unicode:     int,
			advance:     f32,
			plane_bounds: Bounds `json:"planeBounds"`,
			atlas_bounds: Bounds `json:"atlasBounds"`,
		},
	},
}

destroy_renderer :: proc(r: ^Renderer) {
	delete(r.verts)
	delete(r.idxs)
	delete(r.calls)
}

destroy_font :: proc(font: Font) {
	for variant in font.variants {
		delete(variant.glyphs)
	}
	delete(font.variants)
}

read_file_or_die :: proc(path: string, allocator := context.allocator) -> []u8 {
	data, err := os.read_entire_file(path, allocator)
	fmt.assertf(err == nil, "Failed to read file: %s", path)
	return data
}

load_shader :: proc(r: ^Renderer, path: string, stage: sdl3.GPUShaderStage, num_samplers, num_uniform_buffers: u32) -> ^sdl3.GPUShader {
	code := read_file_or_die(path)
	defer delete(code)

	info := sdl3.GPUShaderCreateInfo{
		code_size            = len(code),
		code                 = raw_data(code),
		entrypoint           = "main",
		format               = {.SPIRV},
		stage                = stage,
		num_samplers         = num_samplers,
		num_storage_textures = 0,
		num_storage_buffers  = 0,
		num_uniform_buffers  = num_uniform_buffers,
	}

	shader := sdl3.CreateGPUShader(r.device, info)
	fmt.assertf(shader != nil, "CreateGPUShader failed for %s: %s", path, sdl3.GetError())
	return shader
}

renderer_init :: proc(window: ^sdl3.Window) -> Renderer {
	r: Renderer
	r.window = window

	r.device = sdl3.CreateGPUDevice({.SPIRV}, true, nil)
	fmt.assertf(r.device != nil, "CreateGPUDevice failed: %s", sdl3.GetError())
	fmt.assertf(sdl3.ClaimWindowForGPUDevice(r.device, window), "ClaimWindowForGPUDevice failed: %s", sdl3.GetError())

	// Shaders compiled using:
	// glslc -fshader-stage=vertex   shader.vert -o shader.vert.spv
	// glslc -fshader-stage=fragment shader.frag -o shader.frag.spv
	vert_shader := load_shader(&r, "res/shader.vert.spv", .VERTEX,   0, 1)
	frag_shader := load_shader(&r, "res/shader.frag.spv", .FRAGMENT, 1, 1)

	vertex_attrs := []sdl3.GPUVertexAttribute{
		{location = 0, buffer_slot = 0, format = .FLOAT2, offset = u32(offset_of(Vertex, pos))},
		{location = 1, buffer_slot = 0, format = .FLOAT2, offset = u32(offset_of(Vertex, uv))},
		{location = 2, buffer_slot = 0, format = .FLOAT4, offset = u32(offset_of(Vertex, color))},
	}

	vertex_buffers := []sdl3.GPUVertexBufferDescription{
		{slot = 0, pitch = u32(size_of(Vertex)), input_rate = .VERTEX, instance_step_rate = 0},
	}

	color_target := sdl3.GPUColorTargetDescription{
		format = sdl3.GetGPUSwapchainTextureFormat(r.device, window),
		blend_state = sdl3.GPUColorTargetBlendState{
			enable_blend            = true,
			src_color_blendfactor   = .SRC_ALPHA,
			dst_color_blendfactor   = .ONE_MINUS_SRC_ALPHA,
			color_blend_op          = .ADD,
			src_alpha_blendfactor   = .ONE,
			dst_alpha_blendfactor   = .ONE_MINUS_SRC_ALPHA,
			alpha_blend_op          = .ADD,
		},
	}

	pipeline_info := sdl3.GPUGraphicsPipelineCreateInfo{
		vertex_shader   = vert_shader,
		fragment_shader = frag_shader,
		vertex_input_state = sdl3.GPUVertexInputState{
			vertex_buffer_descriptions = raw_data(vertex_buffers),
			num_vertex_buffers         = u32(len(vertex_buffers)),
			vertex_attributes          = raw_data(vertex_attrs),
			num_vertex_attributes      = u32(len(vertex_attrs)),
		},
		primitive_type = .TRIANGLELIST,
		rasterizer_state = sdl3.GPURasterizerState{
			fill_mode = .FILL,
			cull_mode = .NONE,
		},
		target_info = sdl3.GPUGraphicsPipelineTargetInfo{
			color_target_descriptions = &color_target,
			num_color_targets         = 1,
		},
	}

	r.pipeline = sdl3.CreateGPUGraphicsPipeline(r.device, pipeline_info)
	fmt.assertf(r.pipeline != nil, "CreateGPUGraphicsPipeline failed: %s", sdl3.GetError())

	// Shaders are only needed to build the pipeline.
	sdl3.ReleaseGPUShader(r.device, vert_shader)
	sdl3.ReleaseGPUShader(r.device, frag_shader)

	r.nearest_sampler = sdl3.CreateGPUSampler(r.device, sdl3.GPUSamplerCreateInfo{
		min_filter = .NEAREST, mag_filter = .NEAREST, mipmap_mode = .NEAREST,
		address_mode_u = .CLAMP_TO_EDGE, address_mode_v = .CLAMP_TO_EDGE, address_mode_w = .CLAMP_TO_EDGE,
	})
	r.linear_sampler = sdl3.CreateGPUSampler(r.device, sdl3.GPUSamplerCreateInfo{
		min_filter = .LINEAR, mag_filter = .LINEAR, mipmap_mode = .LINEAR,
		address_mode_u = .CLAMP_TO_EDGE, address_mode_v = .CLAMP_TO_EDGE, address_mode_w = .CLAMP_TO_EDGE,
	})

	white_pixel := [4]u8{255, 255, 255, 255}
	r.white_tex = create_texture_from_pixels(&r, raw_data(white_pixel[:]), 1, 1)

	return r
}

create_texture_from_pixels :: proc(r: ^Renderer, pixels: [^]u8, w, h: i32) -> (res: Texture) {
	tex_info := sdl3.GPUTextureCreateInfo{
		type                 = .D2,
		format               = .R8G8B8A8_UNORM,
		usage                = sdl3.GPUTextureUsageFlags{.SAMPLER},
		width                = u32(w),
		height               = u32(h),
		layer_count_or_depth = 1,
		num_levels           = 1,
	}
	tex := sdl3.CreateGPUTexture(r.device, tex_info)

	byte_size := u32(w * h * 4)
	transfer := sdl3.CreateGPUTransferBuffer(r.device, sdl3.GPUTransferBufferCreateInfo{
		usage = .UPLOAD, size = byte_size,
	})

	mapped := ([^]u8)(sdl3.MapGPUTransferBuffer(r.device, transfer, false))
	copy(mapped[:byte_size], pixels[:byte_size])
	sdl3.UnmapGPUTransferBuffer(r.device, transfer)

	cmd := sdl3.AcquireGPUCommandBuffer(r.device)
	copy_pass := sdl3.BeginGPUCopyPass(cmd)

	src := sdl3.GPUTextureTransferInfo{transfer_buffer = transfer, offset = 0}
	dst := sdl3.GPUTextureRegion{texture = tex, w = u32(w), h = u32(h), d = 1}
	sdl3.UploadToGPUTexture(copy_pass, src, dst, false)

	sdl3.EndGPUCopyPass(copy_pass)
	assert(sdl3.SubmitGPUCommandBuffer(cmd))

	sdl3.ReleaseGPUTransferBuffer(r.device, transfer)
	return Texture{gpu = tex, size = {f32(w), f32(h)}}
}

load_texture :: proc(r: ^Renderer, path: string) -> (res: Texture) {
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)

	surface := sdl3.LoadPNG(cpath)
	fmt.assertf(r.pipeline != nil, "failed to load image %s: %s", path, sdl3.GetError())
	defer sdl3.DestroySurface(surface)

	converted := sdl3.ConvertSurface(surface, .ABGR8888)
	defer sdl3.DestroySurface(converted)

	pixels := ([^]u8)(converted.pixels)
	return create_texture_from_pixels(r, pixels, converted.w, converted.h)
}

destroy_texture :: proc(r: ^Renderer, tex: Texture) {
	ensure(r != nil)
	if tex.gpu != nil {
		return
	}
	sdl3.ReleaseGPUTexture(r.device, tex.gpu)
}

renderer_begin_frame :: proc(r: ^Renderer) {
	clear(&r.verts)
	clear(&r.idxs)
	clear(&r.calls)
}

push_call :: proc(r: ^Renderer, tex: ^sdl3.GPUTexture, frag: Frag_Uniforms, index_count: int) {
	n := len(r.calls)
	if n > 0 {
		last := &r.calls[n - 1]
		if last.texture == tex && last.frag == frag {
			last.index_count += u32(index_count)
			return
		}
	}
	append(&r.calls, Draw_Call{
		texture     = tex,
		frag        = frag,
		index_off   = u32(len(r.idxs) - index_count),
		index_count = u32(index_count),
	})
}

make_quad :: proc(pos, size: Vec2) -> (q: Quad) {
	return {pos, pos + Vec2{size.x, 0}, pos + size, pos + Vec2{0, size.y}}
}

push_quad_verts :: proc(r: ^Renderer, pos: Quad, uv: [4]Vec2, color: Color) {
	base := u16(len(r.verts))
	append(&r.verts, Vertex{pos[0], uv[0], color})
	append(&r.verts, Vertex{pos[1], uv[1], color})
	append(&r.verts, Vertex{pos[2], uv[2], color})
	append(&r.verts, Vertex{pos[3], uv[3], color})
	append(&r.idxs, base + 0, base + 1, base + 2)
	append(&r.idxs, base + 0, base + 2, base + 3)
}

draw_squircle :: proc(r: ^Renderer, pos, size: Vec2, corner_radius: f32, blend: f32, color: Color = WHITE) {
	half := size * 0.5
	quad := make_quad(pos, size)
	uv   := make_quad(-half, size)
	push_quad_verts(r, quad, uv, color)
	push_call(r, r.white_tex.gpu, Frag_Uniforms{
		mode           = .Squircle,
		half_size      = half,
		corner_radius  = clamp(corner_radius, 0, min(half.x, half.y)),
		squircle_blend = clamp(blend, 0, 1),
	}, 6)
}

draw_rect :: proc(r: ^Renderer, pos, size: Vec2, color: Color) {
	draw_squircle(r, pos, size, 0, 0, color)
}

draw_texture :: proc(r: ^Renderer, tex: Texture, pos, size: Vec2, color: Color = WHITE, uv0: Vec2 = {0, 0}, uv1: Vec2 = {1, 1}) {
	ensure(r != nil)
	if tex.gpu == nil {
		// Draw magenta rect is texture is missing
		draw_rect(r, pos, size, {1, 0, 1, 0.5})
		return
	}
	quad := make_quad(pos, size)
	uv   := make_quad(uv0, uv1)
	push_quad_verts(r, quad, uv, color)
	push_call(r, tex.gpu, Frag_Uniforms{mode = .Texture}, 6)
}

load_font :: proc(r: ^Renderer, png_path, json_path: string) -> (res: Font) {
	res.texture = load_texture(r, png_path)

	data := read_file_or_die(json_path)
	defer delete(data)

	parsed: Atlas_JSON
	err := json.unmarshal(data, &parsed)
	fmt.assertf(err == nil, "Failed to parse font JSON %s: %v", json_path, err)

	res.atlas_w        = parsed.atlas.width
	res.atlas_h        = parsed.atlas.height
	res.distance_range = parsed.atlas.distance_range
	res.atlas_size_px  = parsed.atlas.size

	fmt.assertf(len(parsed.variants) > 0, "Font JSONs %s has %v variants", json_path, len(parsed.variants))

	res.variants = make([]Font_Variant, len(parsed.variants))

	for &variant, i in res.variants {
		parsed_variant := parsed.variants[i]
		variant.line_height = parsed_variant.metrics.line_height
		variant.ascender    = parsed_variant.metrics.ascender
		variant.descender   = parsed_variant.metrics.descender
		variant.glyphs      = make(map[rune]Glyph)

		for g in parsed_variant.glyphs {
			glyph: Glyph
			glyph.advance = g.advance
			if g.plane_bounds != {} {
				glyph.plane = transmute(Vec4)g.plane_bounds
				glyph.has_bounds = true
			}
			if g.atlas_bounds != {} {
				atlas := transmute(Vec4)g.atlas_bounds

				u0 := atlas.x / res.atlas_w
				v0 := 1.0 - (atlas.w / res.atlas_h)
				u1 := atlas.z / res.atlas_w
				v1 := 1.0 - (atlas.y / res.atlas_h)

				glyph.uv = {{u0, v0}, {u1, v0}, {u1, v1}, {u0, v1}}
			}
			variant.glyphs[rune(g.unicode)] = glyph
		}
	}

	for v in parsed.variants {
		delete(v.glyphs)
	}
	delete(parsed.variants)

	return res
}

measure :: proc(font: ^Font, face_id: int, text: string, font_size: f32) -> (res: Vec2) {
	variant    := font.variants[face_id]
	line_count := f32(1)
	width      := f32(0)

	for ch in text {
		if ch == '\n' {
			line_count += 1
			res.x = max(res.x, width)
			width = 0
			continue
		}

		glyph, _ := variant.glyphs[ch]
		width += glyph.advance * font_size
	}

	res.x = width
	res.y = variant.line_height * font_size * line_count

	return
}

draw_text :: proc(r: ^Renderer, font: ^Font, face_id: int, text: string, pos: Vec2, font_size: f32, color: Color = WHITE) {
	cursor := Vec2{pos.x, pos.y + font_size} // baseline of the first line
	screen_px_range := font.distance_range * (font_size / font.atlas_size_px)
	variant := font.variants[face_id]

	start_index_count := 0

	for ch in text {
		if ch == '\n' {
			cursor.x = pos.x
			cursor.y += variant.line_height * font_size
			continue
		}

		glyph, found := variant.glyphs[ch]
		if !found || !glyph.has_bounds {
			if found {
				cursor.x += glyph.advance * font_size
			}
			continue
		}

		x0 := cursor.x + glyph.plane.x * font_size
		y0 := cursor.y - glyph.plane.w * font_size
		x1 := cursor.x + glyph.plane.z * font_size
		y1 := cursor.y - glyph.plane.y * font_size

		push_quad_verts(r,
			{{x0, y0}, {x1, y0}, {x1, y1}, {x0, y1}},
			glyph.uv,
			color)

		start_index_count += 6
		cursor.x += glyph.advance * font_size
	}

	if start_index_count > 0 {
		push_call(r, font.texture.gpu, Frag_Uniforms{
			mode            = .MSDF,
			screen_px_range = screen_px_range,
		}, start_index_count)
	}
}

ensure_buffer_capacity :: proc(r: ^Renderer, buf: ^^sdl3.GPUBuffer, cap: ^int, needed_bytes: int, usage: sdl3.GPUBufferUsageFlags) {
	if needed_bytes <= cap^ {
		return
	}
	if buf^ != nil {
		sdl3.ReleaseGPUBuffer(r.device, buf^)
	}
	new_cap := max(needed_bytes, cap^ * 2, 4096)
	buf^ = sdl3.CreateGPUBuffer(r.device, sdl3.GPUBufferCreateInfo{usage = usage, size = u32(new_cap)})
	cap^ = new_cap
}

upload_buffer :: proc(r: ^Renderer, dst: ^sdl3.GPUBuffer, data: []$T) {
	if len(data) == 0 {
		return
	}
	size := len(data) * size_of(T)

	transfer := sdl3.CreateGPUTransferBuffer(r.device, sdl3.GPUTransferBufferCreateInfo{usage = .UPLOAD, size = u32(size)})
	mapped   := ([^]T)(sdl3.MapGPUTransferBuffer(r.device, transfer, false))
	copy(mapped[:len(data)], data[:])
	sdl3.UnmapGPUTransferBuffer(r.device, transfer)

	cmd := sdl3.AcquireGPUCommandBuffer(r.device)
	copy_pass := sdl3.BeginGPUCopyPass(cmd)
	src := sdl3.GPUTransferBufferLocation{transfer_buffer = transfer, offset = 0}
	dst_region := sdl3.GPUBufferRegion{buffer = dst, offset = 0, size = u32(size)}
	sdl3.UploadToGPUBuffer(copy_pass, src, dst_region, false)
	sdl3.EndGPUCopyPass(copy_pass)
	assert(sdl3.SubmitGPUCommandBuffer(cmd))

	sdl3.ReleaseGPUTransferBuffer(r.device, transfer)
}

// Uploads the current batch and issues every draw call in one render pass.
renderer_flush :: proc(r: ^Renderer) {
	vbytes := len(r.verts) * size_of(Vertex)
	ibytes := len(r.idxs)  * size_of(u16)

	ensure_buffer_capacity(r, &r.vbo, &r.vbo_cap, vbytes, sdl3.GPUBufferUsageFlags{.VERTEX})
	ensure_buffer_capacity(r, &r.ibo, &r.ibo_cap, ibytes, sdl3.GPUBufferUsageFlags{.INDEX})

	if len(r.verts) > 0 {
		upload_buffer(r, r.vbo, r.verts[:])
	}
	if len(r.idxs) > 0 {
		upload_buffer(r, r.ibo, r.idxs[:])
	}

	cmd := sdl3.AcquireGPUCommandBuffer(r.device)

	swap_tex: ^sdl3.GPUTexture
	if !sdl3.WaitAndAcquireGPUSwapchainTexture(cmd, r.window, &swap_tex, &r.w, &r.h) {
		fmt.eprintfln("WaitAndAcquireGPUSwapchainTexture failed: %s", sdl3.GetError())
		assert(sdl3.SubmitGPUCommandBuffer(cmd))
		return
	}
	if swap_tex == nil {
		assert(sdl3.SubmitGPUCommandBuffer(cmd))
		return
	}

	color_target := sdl3.GPUColorTargetInfo{
		texture     = swap_tex,
		load_op     = .CLEAR,
		clear_color = sdl3.FColor(BG_COLOR),
		store_op    = .STORE,
	}

	pass := sdl3.BeginGPURenderPass(cmd, &color_target, 1, nil)
	sdl3.BindGPUGraphicsPipeline(pass, r.pipeline)

	vbuf_binding := sdl3.GPUBufferBinding{buffer = r.vbo, offset = 0}
	sdl3.BindGPUVertexBuffers(pass, 0, &vbuf_binding, 1)
	ibuf_binding := sdl3.GPUBufferBinding{buffer = r.ibo, offset = 0}
	sdl3.BindGPUIndexBuffer(pass, ibuf_binding, ._16BIT)

	vert_u := Vert_Uniforms{mvp = linalg.matrix_ortho3d(0, f32(r.w), f32(r.h), 0, -1, 1)}
	sdl3.PushGPUVertexUniformData(cmd, 0, &vert_u, size_of(vert_u))

	for &call in r.calls {
		sampler := r.nearest_sampler if call.frag.mode == .Squircle else r.linear_sampler
		binding := sdl3.GPUTextureSamplerBinding{texture = call.texture, sampler = sampler}
		sdl3.BindGPUFragmentSamplers(pass, 0, &binding, 1)

		sdl3.PushGPUFragmentUniformData(cmd, 0, &call.frag, size_of(Frag_Uniforms))
		sdl3.DrawGPUIndexedPrimitives(pass, call.index_count, 1, call.index_off, 0, 0)
	}

	sdl3.EndGPURenderPass(pass)
	assert(sdl3.SubmitGPUCommandBuffer(cmd))
}

_main :: proc() {
	fmt.assertf(sdl3.Init(sdl3.InitFlags{.VIDEO}), "SDL_Init failed: %s", sdl3.GetError())
	defer sdl3.Quit()

	window := sdl3.CreateWindow("SDL3 GPU - Odin", 1280, 720, sdl3.WindowFlags{.RESIZABLE})
	fmt.assertf(window != nil, "CreateWindow failed: %s", sdl3.GetError())
	defer sdl3.DestroyWindow(window)

	r := renderer_init(window)
	defer {
		destroy_texture(&r, r.white_tex)
		destroy_renderer(&r)
	}

	photo := load_texture(&r, "res/emblem.png")
	defer destroy_texture(&r, photo)

	font := load_font(&r, "res/font.png", "res/font.json")
	defer destroy_font(font)

	running   := true
	minimized := .MINIMIZED in sdl3.GetWindowFlags(window)

	handle_event :: proc(event: ^sdl3.Event, running, minimized: ^bool) {
		#partial switch event.type {
		case .QUIT:
			running^ = false
		case .KEY_DOWN:
			if event.key.key == sdl3.K_ESCAPE {
				running^ = false
			}
		case .WINDOW_MINIMIZED:
			minimized^ = true
		case .WINDOW_RESTORED:
			minimized^ = false
		}
	}

	dt:      time.Duration
	face_id: int
	angle:   f32

	for running {
		if minimized {
			// Nothing is being presented, so WaitAndAcquireGPUSwapchainTexture
			// can't pace us against vsync here. Block on SDL_WaitEvent instead.
			event: sdl3.Event
			if sdl3.WaitEventTimeout(&event, 100) {
				handle_event(&event, &running, &minimized)
			}
			continue
		}

		start := time.tick_now()
		defer dt = time.tick_since(start)

		event: sdl3.Event
		for sdl3.PollEvent(&event) {
			handle_event(&event, &running, &minimized)
		}

		renderer_begin_frame(&r)

		if angle += (f32(dt) / 1e9 * math.PI); angle > math.TAU {
			angle = math.mod(angle, math.TAU)
			face_id += 1
			if face_id >= len(font.variants) {
				face_id = 0
			}
		}

		size   := Vec2{160, 160}
		pos    := Vec2{1280 / 2 - size.x  / 2, size.y + 60}
		radius := f32(24)

		draw_rect(&r,           pos - {0, 180}, size,              {0.95, 0.25, 0.95, 1.0})
		draw_squircle(&r,       pos - {180, 0}, size, radius, 1.0, {0.95, 0.25, 0.25, 1.0})
		draw_squircle(&r,       pos,            size, radius, 0.5, {0.25, 0.95, 0.25, 1.0})
		draw_texture(&r, photo, pos + {180, 0}, size)

		radius += math.sin(angle) * 12
		factor := f32(0.5) + math.sin(angle) * 0.5

		draw_squircle(&r, pos + {0, size.y + 20}, size, radius, factor, {0.95, 0.95, 0.25, 1.0})

		font_size := f32(64) + math.sin(angle) * 32
		extents   := measure(&font, face_id, "Hellope, World!", font_size)
		draw_text(&r, &font, face_id, "Hellope, World!", {1280 / 2, 650} - extents / 2, font_size, WHITE)

		renderer_flush(&r)
	}
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	_main()

	for _, leak in track.allocation_map {
		fmt.eprintfln("%v leaked %m", leak.location, leak.size)
	}
}