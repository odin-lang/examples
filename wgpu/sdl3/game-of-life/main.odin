// Conway's Game of Life - WebGPU/ODIN Implementation
// Ported to SDL3/WASM Odin from : https://codelabs.developers.google.com/your-first-webgpu-app#0
// by Jason Coleman, 2025
// ==============================================
// GPU-accelerated cellular automaton running on both desktop (SDL3) and web (WASM).
//
// Architecture:
//  - Single file contains all GPU initialisation, pipelines, buffers, simulation, and rendering
//  - Platform-specific code separated in os_desktop.odin and os_web.odin (selected by build tags)
//  - Compute shader implements Game of Life rules with ping-pong buffers
//  - Fixed 5 Hz simulation update rate (200ms intervals)
//
// Build:
//  Desktop: odin build . -out:game-of-life -vet -strict-style -vet-tabs -disallow-do -warnings-as-errors
//  Web:     odin build . -target:js_wasm32 -out:web/game_of_life.wasm
//
package main

import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:time"
import "vendor:wgpu"

//=============================================================================
// Configuration Constants
//=============================================================================

WIDTH :: 512
HEIGHT :: 512
GRID_SIZE :: 32
WORKGROUP_SIZE :: 8
UPDATE_INTERVAL_MILLISECONDS :: 200.0 // 5 Hz update rate

//=============================================================================
// Application State
//=============================================================================

App_State :: struct {
	// Context
	ctx: runtime.Context,
	
	// WebGPU core
	instance: wgpu.Instance,
	surface:  wgpu.Surface,
	adapter:  wgpu.Adapter,
	device:   wgpu.Device,
	queue:    wgpu.Queue,
	config:   wgpu.SurfaceConfiguration,
	
	// Pipelines & layouts
	pipeline_layout:   wgpu.PipelineLayout,
	bind_group_layout: wgpu.BindGroupLayout,
	render_module:     wgpu.ShaderModule,
	compute_module:    wgpu.ShaderModule,
	render_pipeline:   wgpu.RenderPipeline,
	compute_pipeline:  wgpu.ComputePipeline,
	
	// Buffers
	vertex_buffer:      wgpu.Buffer,
	vertex_count:       u32,
	vertex_buffer_size: u64,
	uniform_buffer:     wgpu.Buffer,
	cell_state_storage: [2]wgpu.Buffer,
	bind_groups:        [2]wgpu.BindGroup,
	
	// Simulation state
	step_index:  u64,
	did_compute: bool,
	do_update:   bool,
	
	// Timing
	last_tick:   time.Tick,
	accumulator: time.Duration,
}

state: App_State

//=============================================================================
// Entry Point
//=============================================================================

main :: proc() {
	state.ctx = context
	os_init()
	init_gpu()
}

//=============================================================================
// GPU Initialisation
//=============================================================================

init_gpu :: proc() {
	state.instance = wgpu.CreateInstance(nil)
	if state.instance == nil {
		panic("WebGPU is not supported")
	}
	
	state.surface = os_get_surface(state.instance)
	
	// Platform-specific initialisation (os_desktop.odin or os_web.odin)
	os_request_adapter_and_device()
}

// Called by platform code after device is acquired
complete_gpu_init :: proc(device: wgpu.Device) {
	state.device = device
	state.queue = wgpu.DeviceGetQueue(state.device)
	
	// Configure surface
	width, height := os_get_framebuffer_size()
	state.config = wgpu.SurfaceConfiguration {
		device      = state.device,
		usage       = {.RenderAttachment},
		format      = .BGRA8Unorm,
		width       = width,
		height      = height,
		presentMode = .Fifo,
		alphaMode   = .Opaque,
	}
	wgpu.SurfaceConfigure(state.surface, &state.config)
	
	// Create all GPU resources
	create_bind_group_layout()
	create_render_pipeline()
	create_compute_pipeline()
	create_buffers_and_bind_groups()
	
	// Initialize timing
	state.last_tick = time.tick_now()
	state.accumulator = 0
	
	// Start platform loop
	os_run()
}

on_device_error :: proc "c" (
	device: ^wgpu.Device,
	errorType: wgpu.ErrorType,
	message: string,
	userdata1, userdata2: rawptr,
) {
	context = state.ctx
	panic(message)
}

//=============================================================================
// Pipeline Creation
//=============================================================================

create_bind_group_layout :: proc() {
	// Binding 0: uniform vec2f (grid size)
	b0 := wgpu.BindGroupLayoutEntry {
		binding    = 0,
		visibility = {.Vertex, .Fragment, .Compute},
		buffer     = {type = .Uniform, minBindingSize = size_of(f32) * 2},
	}
	
	// Binding 1: read-only storage (cell state input)
	b1 := wgpu.BindGroupLayoutEntry {
		binding    = 1,
		visibility = {.Vertex, .Compute},
		buffer     = {type = .ReadOnlyStorage},
	}
	
	// Binding 2: storage (cell state output - compute only)
	b2 := wgpu.BindGroupLayoutEntry {
		binding    = 2,
		visibility = {.Compute},
		buffer     = {type = .Storage},
	}
	
	entries := [3]wgpu.BindGroupLayoutEntry{b0, b1, b2}
	
	state.bind_group_layout = wgpu.DeviceCreateBindGroupLayout(
		state.device,
		&{label = "Cell State Bind Group Layout", entryCount = 3, entries = &entries[0]},
	)
	
	layouts := [1]wgpu.BindGroupLayout{state.bind_group_layout}
	state.pipeline_layout = wgpu.DeviceCreatePipelineLayout(
		state.device,
		&{bindGroupLayoutCount = 1, bindGroupLayouts = &layouts[0]},
	)
}

create_render_pipeline :: proc() {
	// Vertex buffer for cell quad
	verts := []f32{-0.8, -0.8, 0.8, -0.8, 0.8, 0.8, -0.8, -0.8, 0.8, 0.8, -0.8, 0.8}
	
	state.vertex_count = u32(len(verts) / 2)
	state.vertex_buffer_size = u64(len(verts) * size_of(f32))
	
	state.vertex_buffer = wgpu.DeviceCreateBuffer(
		state.device,
		&{label = "Cell Quad Vertices", usage = {.Vertex, .CopyDst}, size = state.vertex_buffer_size},
	)
	
	wgpu.QueueWriteBuffer(state.queue, state.vertex_buffer, 0, raw_data(verts), len(verts) * size_of(f32))
	
	// Load shader
	state.render_module = wgpu.DeviceCreateShaderModule(
		state.device,
		&{
			label       = "Render Shader",
			nextInChain = &wgpu.ShaderSourceWGSL{sType = .ShaderSourceWGSL, code = #load("shaders/render.wgsl")},
		},
	)
	
	// Create pipeline
	state.render_pipeline = wgpu.DeviceCreateRenderPipeline(
		state.device,
		&{
			label  = "Cell Render Pipeline",
			layout = state.pipeline_layout,
			vertex = {
				module      = state.render_module,
				entryPoint  = "vertexMain",
				bufferCount = 1,
				buffers     = &wgpu.VertexBufferLayout {
					arrayStride    = size_of(f32) * 2,
					stepMode       = .Vertex,
					attributes     = &wgpu.VertexAttribute{shaderLocation = 0, format = .Float32x2},
					attributeCount = 1,
				},
			},
			fragment = &{
				module      = state.render_module,
				entryPoint  = "fragmentMain",
				targetCount = 1,
				targets     = &wgpu.ColorTargetState{format = .BGRA8Unorm, writeMask = wgpu.ColorWriteMaskFlags_All},
			},
			primitive   = {topology = .TriangleList},
			multisample = {count = 1, mask = 0xFFFFFFFF},
		},
	)
}

create_compute_pipeline :: proc() {
	state.compute_module = wgpu.DeviceCreateShaderModule(
		state.device,
		&{
			label       = "Compute Shader",
			nextInChain = &wgpu.ShaderSourceWGSL{sType = .ShaderSourceWGSL, code = #load("shaders/compute.wgsl")},
		},
	)
	
	state.compute_pipeline = wgpu.DeviceCreateComputePipeline(
		state.device,
		&{
			label   = "Game of Life Compute Pipeline",
			layout  = state.pipeline_layout,
			compute = {module = state.compute_module, entryPoint = "computeMain"},
		},
	)
}

//=============================================================================
// Buffer Creation
//=============================================================================

create_buffers_and_bind_groups :: proc() {
	// Uniform buffer (grid size)
	grid_data := [2]f32{GRID_SIZE, GRID_SIZE}
	state.uniform_buffer = wgpu.DeviceCreateBuffer(
		state.device,
		&{label = "Grid Uniform", usage = {.Uniform, .CopyDst}, size = size_of(grid_data)},
	)
	wgpu.QueueWriteBuffer(state.queue, state.uniform_buffer, 0, &grid_data[0], size_of(grid_data))
	
	// Storage buffers (ping-pong for cell states)
	cell_count := GRID_SIZE * GRID_SIZE
	cell_bytes := u64(size_of(u32) * cell_count)
	
	for i in 0 ..< 2 {
		state.cell_state_storage[i] = wgpu.DeviceCreateBuffer(
			state.device,
			&{
				label = i == 0 ? "Cell State A" : "Cell State B",
				usage = {.Storage, .CopyDst},
				size  = cell_bytes,
			},
		)
	}
	
	// Initialise both buffers with random data
	{
		cells: [GRID_SIZE * GRID_SIZE]u32
		context = runtime.default_context()
		rand.reset(u64(time.now()._nsec))
		
		for i in 0 ..< GRID_SIZE * GRID_SIZE {
			cells[i] = cast(u32)rand.int31_max(2)
		}
		
		wgpu.QueueWriteBuffer(state.queue, state.cell_state_storage[0], 0, &cells, uint(cell_bytes))
		wgpu.QueueWriteBuffer(state.queue, state.cell_state_storage[1], 0, &cells, uint(cell_bytes))
	}
	
	// Create bind groups (ping-pong)
	for i in 0 ..< 2 {
		read_buffer := state.cell_state_storage[i]
		write_buffer := state.cell_state_storage[(i + 1) % 2]
		
		entries := [3]wgpu.BindGroupEntry{
			{binding = 0, buffer = state.uniform_buffer, size = size_of(f32) * 2},
			{binding = 1, buffer = read_buffer, size = cell_bytes},
			{binding = 2, buffer = write_buffer, size = cell_bytes},
		}
		
		state.bind_groups[i] = wgpu.DeviceCreateBindGroup(
			state.device,
			&{
				label      = i == 0 ? "Bind Group 0" : "Bind Group 1",
				layout     = state.bind_group_layout,
				entryCount = 3,
				entries    = &entries[0],
			},
		)
	}
}

//=============================================================================
// Simulation Logic
//=============================================================================

update_simulation :: proc(dt: f32) {
	// Convert dt to Duration (web uses seconds, desktop uses milliseconds)
	dt_duration: time.Duration
	when ODIN_OS == .JS {
		dt_duration = time.Duration(f64(dt) * f64(time.Second))
	} else {
		dt_duration = time.Duration(f64(dt) * f64(time.Millisecond))
	}
	
	state.accumulator += dt_duration
	accumulator_ms := time.duration_milliseconds(state.accumulator)
	state.do_update = accumulator_ms >= UPDATE_INTERVAL_MILLISECONDS
	
	if state.do_update {
		state.accumulator = 0
	}
}

run_compute_pass :: proc(encoder: wgpu.CommandEncoder) {
	state.did_compute = false
	
	if !state.do_update {
		return
	}
	
	cpass := wgpu.CommandEncoderBeginComputePass(encoder)
	defer wgpu.ComputePassEncoderRelease(cpass)
	
	wgpu.ComputePassEncoderSetPipeline(cpass, state.compute_pipeline)
	wgpu.ComputePassEncoderSetBindGroup(cpass, 0, state.bind_groups[state.step_index % 2])
	
	workgroups := u32((GRID_SIZE + WORKGROUP_SIZE - 1) / WORKGROUP_SIZE)
	wgpu.ComputePassEncoderDispatchWorkgroups(cpass, workgroups, workgroups, 1)
	wgpu.ComputePassEncoderEnd(cpass)
	
	state.did_compute = true
}

//=============================================================================
// Rendering
//=============================================================================

resize :: proc "c" () {
	context = state.ctx
	state.config.width, state.config.height = os_get_framebuffer_size()
	wgpu.SurfaceConfigure(state.surface, &state.config)
}

frame :: proc "c" (dt: f32) {
	context = state.ctx
	
	update_simulation(dt)
	
	// Get surface texture
	surface_texture := wgpu.SurfaceGetCurrentTexture(state.surface)

	switch surface_texture.status {
	case .SuccessOptimal, .SuccessSuboptimal:
		// OK
	case .Timeout, .Outdated, .Lost:
		if surface_texture.texture != nil {
			wgpu.TextureRelease(surface_texture.texture)
		}
		resize()
		return
	case .OutOfMemory, .DeviceLost, .Error:
		fmt.panicf("[Game of Life] surface error: %v", surface_texture.status)
	}
	defer wgpu.TextureRelease(surface_texture.texture)
	
	frame_view := wgpu.TextureCreateView(surface_texture.texture, nil)
	defer wgpu.TextureViewRelease(frame_view)
	
	encoder := wgpu.DeviceCreateCommandEncoder(state.device)
	defer wgpu.CommandEncoderRelease(encoder)
	
	// Compute pass
	run_compute_pass(encoder)
		
	// Render pass
	{
		render_pass := wgpu.CommandEncoderBeginRenderPass(
			encoder,
			&{
				label                = "Main Render Pass",
				colorAttachmentCount = 1,
				colorAttachments     = &wgpu.RenderPassColorAttachment {
					view       = frame_view,
					loadOp     = .Clear,
					storeOp    = .Store,
					depthSlice = wgpu.DEPTH_SLICE_UNDEFINED,
					clearValue = {0.1, 0.2, 0.3, 1.0},
				},
			},
		)
		defer wgpu.RenderPassEncoderRelease(render_pass)
		
		wgpu.RenderPassEncoderSetPipeline(render_pass, state.render_pipeline)
		
		// Use opposite bind group to read latest computed state
		bind_group_index := (state.step_index + 1) % 2
		wgpu.RenderPassEncoderSetBindGroup(render_pass, 0, state.bind_groups[bind_group_index])
		
		wgpu.RenderPassEncoderSetVertexBuffer(render_pass, 0, state.vertex_buffer, 0, state.vertex_buffer_size)
		wgpu.RenderPassEncoderDraw(render_pass, state.vertex_count, GRID_SIZE * GRID_SIZE, 0, 0)
		wgpu.RenderPassEncoderEnd(render_pass)
	}
	
	command_buffer := wgpu.CommandEncoderFinish(encoder, nil)
	defer wgpu.CommandBufferRelease(command_buffer)
	
	wgpu.QueueSubmit(state.queue, {command_buffer})
	wgpu.SurfacePresent(state.surface)
	
	// Advance simulation
	if state.did_compute {
		state.step_index += 1
	}
}

//=============================================================================
// Cleanup
//=============================================================================

cleanup :: proc() {
	wgpu.RenderPipelineRelease(state.render_pipeline)
	wgpu.ComputePipelineRelease(state.compute_pipeline)
	wgpu.PipelineLayoutRelease(state.pipeline_layout)
	wgpu.BindGroupLayoutRelease(state.bind_group_layout)
	wgpu.ShaderModuleRelease(state.render_module)
	wgpu.ShaderModuleRelease(state.compute_module)
	wgpu.BufferRelease(state.vertex_buffer)
	wgpu.BufferRelease(state.uniform_buffer)
	wgpu.BufferRelease(state.cell_state_storage[0])
	wgpu.BufferRelease(state.cell_state_storage[1])
	wgpu.BindGroupRelease(state.bind_groups[0])
	wgpu.BindGroupRelease(state.bind_groups[1])
	wgpu.QueueRelease(state.queue)
	wgpu.DeviceRelease(state.device)
	wgpu.AdapterRelease(state.adapter)
	wgpu.SurfaceRelease(state.surface)
	wgpu.InstanceRelease(state.instance)
}
