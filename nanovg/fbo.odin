package main

/*
Original Source: https://github.com/memononen/nanovg/blob/master/example/example_fbo.c
Can be run using: odin.exe run main.odin -file
*/

import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"

renderPattern :: proc(ctx: ^nvg.Context, fb: ^nvg_gl.framebuffer, t: f32, pxRatio: f32) {
	s := f32(20)
	sr := (math.cos(t) + 1) * 0.5
	r := s * 0.6 * (0.2 + 0.8 * sr)

	if fb == nil {
		return
	}

	fboWidth, fboHeight := nvg.ImageSize(ctx, fb.image)
	winWidth := int(f32(fboWidth) / pxRatio)
	winHeight := int(f32(fboHeight) / pxRatio)

	// Draw some stuff to an FBO as a test
	nvg_gl.BindFramebuffer(fb)
	gl.Viewport(0, 0, i32(fboWidth), i32(fboHeight))
	gl.ClearColor(0, 0, 0, 0)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)
	nvg.BeginFrame(ctx, f32(winWidth), f32(winHeight), pxRatio)

	pw := math.ceil(f32(winWidth) / s)
	ph := math.ceil(f32(winHeight) / s)

	nvg.BeginPath(ctx)
	for y in 0 ..< ph {
		for x in 0 ..< pw {
			cx := (x + 0.5) * s
			cy := (y + 0.5) * s
			nvg.Circle(ctx, cx, cy, r)
		}
	}
	nvg.FillColor(ctx, nvg.RGBA(220, 160, 0, 200))
	nvg.Fill(ctx)

	nvg.EndFrame(ctx)
	nvg_gl.BindFramebuffer(nil)
}

loadFonts :: proc(ctx: ^nvg.Context) -> bool {
	font: int
	font = nvg.CreateFont(ctx, "sans", "fonts/Roboto-Regular.ttf")
	if font == -1 {
		fmt.printf("Could not add font regular.\n")
		return false
	}
	font = nvg.CreateFont(ctx, "sans-bold", "fonts/Roboto-Bold.ttf")
	if font == -1 {
		fmt.printf("Could not add font bold.\n")
		return false
	}
	return true
}

main :: proc() {
	if !glfw.Init() {
		panic("glfw failed")
	}

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, 1)

	window := glfw.CreateWindow(1000, 600, "NanoVG", nil, nil)

	if window == nil {
		glfw.Terminate()
		panic("glfw window failed")
	}

	glfw.MakeContextCurrent(window)
	gl.load_up_to(4, 5, glfw.gl_set_proc_address)

	ctx := nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES, .DEBUG})
	defer nvg_gl.Destroy(ctx)

	glfw.SetTime(0)
	prevt := glfw.GetTime()

	fw, fh := glfw.GetFramebufferSize(window)
	w, h := glfw.GetWindowSize(window)
	px_ratio := f32(fw) / f32(fw)
	fb := nvg_gl.CreateFramebuffer(
		ctx,
		int(100 * px_ratio),
		int(100 * px_ratio),
		{.REPEAT_X, .REPEAT_Y},
	)

	if !loadFonts(ctx) {
		panic("Could not load fonts")
	}

	for !glfw.WindowShouldClose(window) {
		t := glfw.GetTime()
		prevt = t

		fw, fh = glfw.GetFramebufferSize(window)
		w, h = glfw.GetWindowSize(window)
		px_ratio = f32(fw) / f32(fw)

		renderPattern(ctx, &fb, f32(t), px_ratio)

		gl.Viewport(0, 0, fw, fh)
		gl.ClearColor(0.3, 0.3, 0.32, 1.0)
		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)

		{
			nvg.FrameScoped(ctx, f32(w), f32(h), px_ratio)

			img := nvg.ImagePattern(0, 0, 100, 100, 0, fb.image, 1.0)
			nvg.SaveScoped(ctx)

			for i in 0 ..< 20 {
				nvg.FillScoped(ctx)
				nvg.Rect(ctx, 10 + f32(i) * 30, 10, 10, f32(w) - 20)
				nvg.FillColor(ctx, nvg.HSLA(f32(i) / 19.0, 0.5, 0.5, 255))
			}

			nvg.BeginPath(ctx)
			nvg.RoundedRect(
				ctx,
				140 + math.sin(f32(t) * 1.3) * 100,
				140 + math.cos(f32(t) * 1.71244) * 100,
				250,
				250,
				20,
			)
			nvg.FillPaint(ctx, img)
			nvg.Fill(ctx)
			nvg.StrokeColor(ctx, nvg.RGBA(220, 160, 0, 255))
			nvg.StrokeWidth(ctx, 3.0)
			nvg.Stroke(ctx)
		}

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}
