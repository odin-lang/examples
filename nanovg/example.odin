package main

/*
Original Source: https://github.com/memononen/nanovg/blob/master/example/example_gl3.c
Can be run using: odin.exe run example.odin -file
*/

import "core:fmt"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"
import nvg "vendor:nanovg"
import nvg_gl "vendor:nanovg/gl"
import stbi "vendor:stb/image"

DEMO_MSAA :: true

DemoData :: struct {
	fontNormal, fontBold, fontIcons, fontEmoji: int,
	images:                                     [12]int,
}

blowup: bool
screenshot: bool
premult: bool

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: i32) {
	if action != glfw.PRESS {
		return
	}

	switch key {
	case glfw.KEY_ESCAPE:
		{
			glfw.SetWindowShouldClose(window, true)
		}

	case glfw.KEY_SPACE:
		{
			blowup = !blowup
		}

	case glfw.KEY_S:
		{
			screenshot = true
		}

	case glfw.KEY_P:
		{
			premult = !premult
		}
	}
}

main :: proc() {
	if !glfw.Init() {
		panic("glfw failed")
	}

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 2)
	glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, 1)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, 1)

	when DEMO_MSAA {
		glfw.WindowHint(glfw.SAMPLES, 4)
	}

	window := glfw.CreateWindow(1000, 600, "NanoVG", nil, nil)

	if window == nil {
		glfw.Terminate()
		panic("glfw window failed")
	}

	glfw.SetKeyCallback(window, key_callback)
	glfw.MakeContextCurrent(window)
	gl.load_up_to(3, 2, glfw.gl_set_proc_address)

	when DEMO_MSAA {
		ctx := nvg_gl.Create({.STENCIL_STROKES, .DEBUG})
	} else {
		ctx := nvg_gl.Create({.ANTI_ALIAS, .STENCIL_STROKES, .DEBUG})
	}
	defer nvg_gl.Destroy(ctx)

	demo: DemoData
	loadDemoData(ctx, &demo)
	defer freeDemoData(ctx, &demo)

	gpuTimer: GPUtimer
	fps, cpuGraph, gpuGraph: PerfGraph

	initGraph(&fps, .FPS, "Frame Time")
	initGraph(&cpuGraph, .MS, "CPU Time")
	initGraph(&gpuGraph, .MS, "GPU Time")

	glfw.SetTime(0)
	prevt := glfw.GetTime()

	for !glfw.WindowShouldClose(window) {
		t := glfw.GetTime()
		dt := t - prevt
		prevt = t

		startGPUTimer(&gpuTimer)

		fw, fh := glfw.GetFramebufferSize(window)
		w, h := glfw.GetWindowSize(window)
		gl.Viewport(0, 0, fw, fh)

		if premult {
			gl.ClearColor(0, 0, 0, 0)
		} else {
			gl.ClearColor(0.3, 0.3, 0.32, 1.0)
		}

		gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT | gl.STENCIL_BUFFER_BIT)
		px_ratio := f32(fw) / f32(fw)

		{
			xx, yy := glfw.GetCursorPos(window)
			x := f32(xx)
			y := f32(yy)

			nvg.BeginFrame(ctx, f32(w), f32(h), px_ratio)
			defer nvg.EndFrame(ctx)

			renderDemo(ctx, x, y, f32(w), f32(h), f32(t), blowup, &demo)
			renderGraph(ctx, 5, 5, &fps)
			renderGraph(ctx, 5 + 200 + 5, 5, &cpuGraph)

			if gpuTimer.supported {
				renderGraph(ctx, 5 + 200 + 5 + 200 + 5, 5, &gpuGraph)
			}
		}

		cpuTime := glfw.GetTime() - t
		updateGraph(&fps, f32(dt))
		updateGraph(&cpuGraph, f32(cpuTime))
		stopGPUTimer(&gpuTimer)

		if screenshot {
			saveScreenshot(int(fw), int(fh), premult, "dump.png")
			screenshot = false
		}

		glfw.SwapBuffers(window)
		glfw.PollEvents()
	}
}

drawWindow :: proc(ctx: ^nvg.Context, title: string, x, y, w, h: f32) {
	corner_radius := f32(3)
	nvg.SaveScoped(ctx)

	// window
	{
		nvg.FillScoped(ctx)
		nvg.RoundedRect(ctx, x, y, w, h, corner_radius)
		nvg.FillColor(ctx, nvg.RGBA(28, 30, 34, 192))
	}

	// drop shadow
	{
		nvg.FillScoped(ctx)
		nvg.Rect(ctx, x - 10, y - 10, w + 20, h + 30)
		nvg.RoundedRect(ctx, x, y, w, h, corner_radius)
		nvg.PathSolidity(ctx, .HOLE)
		shadow_paint := nvg.BoxGradient(
			x,
			y + 2,
			w,
			h,
			corner_radius * 2,
			10,
			nvg.RGBA(0, 0, 0, 128),
			nvg.RGBA(0, 0, 0, 0),
		)
		nvg.FillPaint(ctx, shadow_paint)
	}

	// header 1
	{
		nvg.FillScoped(ctx)
		nvg.RoundedRect(ctx, x + 1, y + 1, w - 2, 30, corner_radius - 1)
		header_paint := nvg.LinearGradient(
			x,
			y,
			x,
			y + 15,
			nvg.RGBA(255, 255, 255, 8),
			nvg.RGBA(0, 0, 0, 8),
		)
		nvg.FillPaint(ctx, header_paint)
	}

	// header 2
	{
		nvg.StrokeScoped(ctx)
		nvg.MoveTo(ctx, x + 0.5, y + 0.5 + 30)
		nvg.LineTo(ctx, x + 0.5 + w - 1, y + 0.5 + 30)
		nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 32))
	}

	// text
	nvg.FontSize(ctx, 15)
	nvg.FontFace(ctx, "sans-bold")
	nvg.TextAlignHorizontal(ctx, .CENTER)
	nvg.TextAlignVertical(ctx, .MIDDLE)

	nvg.FontBlur(ctx, 2)
	nvg.FillColor(ctx, nvg.RGBA(0, 0, 0, 128))
	nvg.Text(ctx, x + w / 2, y + 16 + 1, title)

	nvg.FontBlur(ctx, 0)
	nvg.FillColor(ctx, nvg.RGBA(220, 220, 220, 220))
	nvg.Text(ctx, x + w / 2, y + 16, title)
}

drawEyes :: proc(ctx: ^nvg.Context, x, y: f32, w, h: f32, mx, my: f32, t: f32) {
	ex := w * 0.23
	ey := h * 0.5
	lx := x + ex
	ly := y + ey
	rx := x + w - ex
	ry := y + ey
	br := (ex < ey ? ex : ey) * 0.5
	blink := 1 - math.pow(math.sin(t * 0.5), 200) * 0.8

	{
		bg := nvg.LinearGradient(
			x,
			y + h * 0.5,
			x + w * 0.1,
			y + h,
			nvg.RGBA(0, 0, 0, 32),
			nvg.RGBA(0, 0, 0, 16),
		)
		nvg.FillScoped(ctx)
		nvg.Ellipse(ctx, lx + 3.0, ly + 16.0, ex, ey)
		nvg.Ellipse(ctx, rx + 3.0, ry + 16.0, ex, ey)
		nvg.FillPaint(ctx, bg)
	}

	{
		bg := nvg.LinearGradient(
			x,
			y + h * 0.25,
			x + w * 0.1,
			y + h,
			nvg.RGBA(220, 220, 220, 255),
			nvg.RGBA(128, 128, 128, 255),
		)
		nvg.FillScoped(ctx)
		nvg.Ellipse(ctx, lx, ly, ex, ey)
		nvg.Ellipse(ctx, rx, ry, ex, ey)
		nvg.FillPaint(ctx, bg)
	}

	dx := (mx - rx) / (ex * 10)
	dy := (my - ry) / (ey * 10)
	d := math.sqrt(dx * dx + dy * dy)
	if d > 1.0 {
		dx /= d
		dy /= d
	}
	dx *= ex * 0.4
	dy *= ey * 0.5

	{
		nvg.FillScoped(ctx)
		nvg.Ellipse(ctx, lx + dx, ly + dy + ey * 0.25 * (1 - blink), br, br * blink)
		nvg.FillColor(ctx, nvg.RGBA(32, 32, 32, 255))
	}

	dx = (mx - rx) / (ex * 10)
	dy = (my - ry) / (ey * 10)
	d = math.sqrt(dx * dx + dy * dy)
	if d > 1.0 {
		dx /= d
		dy /= d
	}
	dx *= ex * 0.4
	dy *= ey * 0.5

	{
		nvg.FillScoped(ctx)
		nvg.Ellipse(ctx, rx + dx, ry + dy + ey * 0.25 * (1 - blink), br, br * blink)
		nvg.FillColor(ctx, nvg.RGBA(32, 32, 32, 255))
	}

	{
		gloss := nvg.RadialGradient(
			lx - ex * 0.25,
			ly - ey * 0.5,
			ex * 0.1,
			ex * 0.75,
			nvg.RGBA(255, 255, 255, 128),
			nvg.RGBA(255, 255, 255, 0),
		)
		nvg.FillScoped(ctx)
		nvg.Ellipse(ctx, lx, ly, ex, ey)
		nvg.FillPaint(ctx, gloss)
	}

	{
		gloss := nvg.RadialGradient(
			rx - ex * 0.25,
			ry - ey * 0.5,
			ex * 0.1,
			ex * 0.75,
			nvg.RGBA(255, 255, 255, 128),
			nvg.RGBA(255, 255, 255, 0),
		)
		nvg.FillScoped(ctx)
		nvg.Ellipse(ctx, rx, ry, ex, ey)
		nvg.FillPaint(ctx, gloss)
	}
}

drawGraph :: proc(ctx: ^nvg.Context, x, y, w, h, t: f32) {
	sx: [6]f32
	sy: [6]f32
	dx := w / 5.0
	samples: [6]f32
	samples[0] = (1 + math.sin(t * 1.2345 + math.cos(t * 0.33457) * 0.44)) * 0.5
	samples[1] = (1 + math.sin(t * 0.68363 + math.cos(t * 1.3) * 1.55)) * 0.5
	samples[2] = (1 + math.sin(t * 1.1642 + math.cos(t * 0.33457) * 1.24)) * .5
	samples[3] = (1 + math.sin(t * 0.56345 + math.cos(t * 1.63) * 0.14)) * 0.
	samples[4] = (1 + math.sin(t * 1.6245 + math.cos(t * 0.254) * 0.3)) * 0.5
	samples[5] = (1 + math.sin(t * 0.345 + math.cos(t * 0.03) * 0.6)) * 0.5

	for i in 0 ..< 6 {
		sx[i] = x + f32(i) * dx
		sy[i] = y + h * samples[i] * 0.8
	}

	// Graph background
	{
		bg := nvg.LinearGradient(
			x,
			y,
			x,
			y + h,
			nvg.RGBA(0, 160, 192, 0),
			nvg.RGBA(0, 160, 192, 64),
		)
		nvg.FillScoped(ctx)
		nvg.MoveTo(ctx, sx[0], sy[0])
		for i in 1 ..< 6 {
			nvg.BezierTo(
				ctx,
				sx[i - 1] + dx * 0.5,
				sy[i - 1],
				sx[i] - dx * 0.5,
				sy[i],
				sx[i],
				sy[i],
			)
		}
		nvg.LineTo(ctx, x + w, y + h)
		nvg.LineTo(ctx, x, y + h)
		nvg.FillPaint(ctx, bg)
	}

	// Graph line
	{
		nvg.StrokeScoped(ctx)
		nvg.MoveTo(ctx, sx[0], sy[0] + 2)
		for i in 1 ..< 6 {
			nvg.BezierTo(
				ctx,
				sx[i - 1] + dx * 0.5,
				sy[i - 1] + 2,
				sx[i] - dx * 0.5,
				sy[i] + 2,
				sx[i],
				sy[i] + 2,
			)
		}
		nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 32))
		nvg.StrokeWidth(ctx, 3.0)
	}

	{
		nvg.StrokeScoped(ctx)
		nvg.MoveTo(ctx, sx[0], sy[0])
		for i in 1 ..< 6 {
			nvg.BezierTo(
				ctx,
				sx[i - 1] + dx * 0.5,
				sy[i - 1],
				sx[i] - dx * 0.5,
				sy[i],
				sx[i],
				sy[i],
			)
		}
		nvg.StrokeColor(ctx, nvg.RGBA(0, 160, 192, 255))
		nvg.StrokeWidth(ctx, 3.0)
	}

	// Graph sample pos
	for i in 0 ..< 6 {
		bg := nvg.RadialGradient(
			sx[i],
			sy[i] + 2,
			3.0,
			8.0,
			nvg.RGBA(0, 0, 0, 32),
			nvg.RGBA(0, 0, 0, 0),
		)
		nvg.FillScoped(ctx)
		nvg.Rect(ctx, sx[i] - 10, sy[i] - 10 + 2, 20, 20)
		nvg.FillPaint(ctx, bg)
	}

	{
		nvg.FillScoped(ctx)
		for i in 0 ..< 6 {
			nvg.Circle(ctx, sx[i], sy[i], 4.0)
		}
		nvg.FillColor(ctx, nvg.RGBA(0, 160, 192, 255))
	}

	{
		nvg.FillScoped(ctx)
		for i in 0 ..< 6 {
			nvg.Circle(ctx, sx[i], sy[i], 2.0)
		}
		nvg.FillColor(ctx, nvg.RGBA(220, 220, 220, 255))
	}

	nvg.StrokeWidth(ctx, 1.0)
}

drawColorwheel :: proc(ctx: ^nvg.Context, x, y, w, h, t: f32) {
	r0, r1, ax, ay, bx, by, cx, cy, aeps, r: f32
	hue := math.sin(t * 0.12)
	paint: nvg.Paint
	nvg.Save(ctx)

	cx = x + w * 0.5
	cy = y + h * 0.5
	r1 = (w < h ? w : h) * 0.5 - 5.0
	r0 = r1 - 20.0
	aeps = 0.5 / r1 // half a pixel arc length in radians (2pi cancels out).

	for i in 0 ..< 6 {
		a0 := f32(i) / 6.0 * math.PI * 2.0 - aeps
		a1 := f32(i + 1.0) / 6.0 * math.PI * 2.0 + aeps
		nvg.BeginPath(ctx)
		nvg.Arc(ctx, cx, cy, r0, a0, a1, .CW)
		nvg.Arc(ctx, cx, cy, r1, a1, a0, .CCW)
		nvg.ClosePath(ctx)
		ax = cx + math.cos(a0) * (r0 + r1) * 0.5
		ay = cy + math.sin(a0) * (r0 + r1) * 0.5
		bx = cx + math.cos(a1) * (r0 + r1) * 0.5
		by = cy + math.sin(a1) * (r0 + r1) * 0.5
		paint = nvg.LinearGradient(
			ax,
			ay,
			bx,
			by,
			nvg.HSLA(a0 / (math.PI * 2), 1.0, 0.55, 255),
			nvg.HSLA(a1 / (math.PI * 2), 1.0, 0.55, 255),
		)
		nvg.FillPaint(ctx, paint)
		nvg.Fill(ctx)
	}

	nvg.BeginPath(ctx)
	nvg.Circle(ctx, cx, cy, r0 - 0.5)
	nvg.Circle(ctx, cx, cy, r1 + 0.5)
	nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 64))
	nvg.StrokeWidth(ctx, 1.0)
	nvg.Stroke(ctx)

	// Selector
	nvg.Save(ctx)
	nvg.Translate(ctx, cx, cy)
	nvg.Rotate(ctx, hue * math.PI * 2)

	// Marker on
	nvg.StrokeWidth(ctx, 2.0)
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, r0 - 1, -3, r1 - r0 + 2, 6)
	nvg.StrokeColor(ctx, nvg.RGBA(255, 255, 255, 192))
	nvg.Stroke(ctx)

	paint = nvg.BoxGradient(
		r0 - 3,
		-5,
		r1 - r0 + 6,
		10,
		2,
		4,
		nvg.RGBA(0, 0, 0, 128),
		nvg.RGBA(0, 0, 0, 0),
	)
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, r0 - 2 - 10, -4 - 10, r1 - r0 + 4 + 20, 8 + 20)
	nvg.Rect(ctx, r0 - 2, -4, r1 - r0 + 4, 8)
	nvg.PathSolidity(ctx, .HOLE)
	nvg.FillPaint(ctx, paint)
	nvg.Fill(ctx)

	// Center triangle
	r = r0 - 6
	ax = math.cos(f32(120.0 / 180.0 * math.PI)) * r
	ay = math.sin(f32(120.0 / 180.0 * math.PI)) * r
	bx = math.cos(f32(-120.0 / 180.0 * math.PI)) * r
	by = math.sin(f32(-120.0 / 180.0 * math.PI)) * r
	nvg.BeginPath(ctx)
	nvg.MoveTo(ctx, r, 0)
	nvg.LineTo(ctx, ax, ay)
	nvg.LineTo(ctx, bx, by)
	nvg.ClosePath(ctx)
	paint = nvg.LinearGradient(
		r,
		0,
		ax,
		ay,
		nvg.HSLA(hue, 1.0, 0.5, 255),
		nvg.RGBA(255, 255, 255, 255),
	)
	nvg.FillPaint(ctx, paint)
	nvg.Fill(ctx)
	paint = nvg.LinearGradient(
		(r + ax) * 0.5,
		(0 + ay) * 0.5,
		bx,
		by,
		nvg.RGBA(0, 0, 0, 0),
		nvg.RGBA(0, 0, 0, 255),
	)
	nvg.FillPaint(ctx, paint)
	nvg.Fill(ctx)
	nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 64))
	nvg.Stroke(ctx)

	// Select circle on triangle
	ax = math.cos(f32(120.0 / 180.0 * math.PI)) * r * 0.3
	ay = math.sin(f32(120.0 / 180.0 * math.PI)) * r * 0.4
	nvg.StrokeWidth(ctx, 2.0)
	nvg.BeginPath(ctx)
	nvg.Circle(ctx, ax, ay, 5)
	nvg.StrokeColor(ctx, nvg.RGBA(255, 255, 255, 192))
	nvg.Stroke(ctx)

	paint = nvg.RadialGradient(ax, ay, 7, 9, nvg.RGBA(0, 0, 0, 64), nvg.RGBA(0, 0, 0, 0))
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, ax - 20, ay - 20, 40, 40)
	nvg.Circle(ctx, ax, ay, 7)
	nvg.PathSolidity(ctx, .HOLE)
	nvg.FillPaint(ctx, paint)
	nvg.Fill(ctx)

	nvg.Restore(ctx)

	// Render hue label
	tw := f32(50)
	th := f32(25)
	r1 += 0.5 * math.sqrt(tw * tw + th * th)
	nvg.BeginPath(ctx)
	nvg.FillColor(ctx, nvg.RGB(32, 32, 32))
	ax = cx + r1 * math.cos(hue * math.PI * 2)
	ay = cy + r1 * math.sin(hue * math.PI * 2)
	nvg.RoundedRect(ctx, ax - tw * 0.5, ay - th * 0.5, tw, th, 5.0)
	nvg.Fill(ctx)

	nvg.TextAlign(ctx, .CENTER, .MIDDLE)
	nvg.FontSize(ctx, th)
	nvg.FontFace(ctx, "sans")
	nvg.FillColor(ctx, nvg.RGB(255, 255, 255))
	text := fmt.tprintf("%d%%", int(100.0 * (hue + 1.0)) % 100)
	nvg.BeginPath(ctx)
	nvg.Text(ctx, ax, ay + 2.0, text)
	nvg.Fill(ctx)

	nvg.Restore(ctx)
}

drawLines :: proc(ctx: ^nvg.Context, x, y, w, h, t: f32) {
	pad := f32(5.0)
	s := w / 9.0 - pad * 2
	pts: [4 * 2]f32
	fx, fy: f32
	joins := [3]nvg.LineCapType{.MITER, .ROUND, .BEVEL}
	caps := [3]nvg.LineCapType{.BUTT, .ROUND, .SQUARE}

	nvg.Save(ctx)
	pts[0] = -s * 0.25 + math.cos(t * 0.3) * s * 0.5
	pts[1] = math.sin(t * 0.3) * s * 0.5
	pts[2] = -s * 0.25
	pts[3] = 0
	pts[4] = s * 0.25
	pts[5] = 0
	pts[6] = s * 0.25 + math.cos(-t * 0.3) * s * 0.5
	pts[7] = math.sin(-t * 0.3) * s * 0.5

	for i in 0 ..< 3 {
		for j in 0 ..< 3 {
			fx = x + s * 0.5 + f32(i * 3 + j) / 9.0 * w + pad
			fy = y - s * 0.5 + pad

			nvg.LineCap(ctx, caps[i])
			nvg.LineJoin(ctx, joins[j])

			nvg.StrokeWidth(ctx, s * 0.3)
			nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 160))
			nvg.BeginPath(ctx)
			nvg.MoveTo(ctx, fx + pts[0], fy + pts[1])
			nvg.LineTo(ctx, fx + pts[2], fy + pts[3])
			nvg.LineTo(ctx, fx + pts[4], fy + pts[5])
			nvg.LineTo(ctx, fx + pts[6], fy + pts[7])
			nvg.Stroke(ctx)

			nvg.LineCap(ctx, .BUTT)
			nvg.LineJoin(ctx, .BEVEL)

			nvg.StrokeWidth(ctx, 1.0)
			nvg.StrokeColor(ctx, nvg.RGBA(0, 192, 255, 255))
			nvg.BeginPath(ctx)
			nvg.MoveTo(ctx, fx + pts[0], fy + pts[1])
			nvg.LineTo(ctx, fx + pts[2], fy + pts[3])
			nvg.LineTo(ctx, fx + pts[4], fy + pts[5])
			nvg.LineTo(ctx, fx + pts[6], fy + pts[7])
			nvg.Stroke(ctx)
		}
	}

	nvg.Restore(ctx)
}

drawWidths :: proc(ctx: ^nvg.Context, x, y, width: f32) {
	nvg.Save(ctx)
	nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 255))
	y := y

	for i in 0 ..< 20 {
		w := (f32(i) + 0.5) * 0.1
		nvg.StrokeWidth(ctx, w)
		nvg.BeginPath(ctx)
		nvg.MoveTo(ctx, x, y)
		nvg.LineTo(ctx, x + width, y + width * 0.3)
		nvg.Stroke(ctx)
		y += 10
	}

	nvg.Restore(ctx)
}

drawCaps :: proc(ctx: ^nvg.Context, x, y, width: f32) {
	caps := [3]nvg.LineCapType{.BUTT, .ROUND, .SQUARE}
	line_width := f32(8.0)

	nvg.Save(ctx)

	nvg.BeginPath(ctx)
	nvg.Rect(ctx, x - line_width / 2, y, width + line_width, 40)
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 32))
	nvg.Fill(ctx)

	nvg.BeginPath(ctx)
	nvg.Rect(ctx, x, y, width, 40)
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 32))
	nvg.Fill(ctx)

	nvg.StrokeWidth(ctx, line_width)
	for i in 0 ..< 3 {
		nvg.LineCap(ctx, caps[i])
		nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 255))
		nvg.BeginPath(ctx)
		nvg.MoveTo(ctx, x, y + f32(i) * 10 + 5)
		nvg.LineTo(ctx, x + width, y + f32(i) * 10 + 5)
		nvg.Stroke(ctx)
	}

	nvg.Restore(ctx)
}

drawScissor :: proc(ctx: ^nvg.Context, x, y, t: f32) {
	nvg.Save(ctx)

	// Draw first rect and set scissor to it's area.
	nvg.Translate(ctx, x, y)
	nvg.Rotate(ctx, nvg.DegToRad(5))
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, -20, -20, 60, 40)
	nvg.FillColor(ctx, nvg.RGBA(255, 0, 0, 255))
	nvg.Fill(ctx)
	nvg.Scissor(ctx, -20, -20, 60, 40)

	// Draw second rectangle with offset and rotation.
	nvg.Translate(ctx, 40, 0)
	nvg.Rotate(ctx, t)

	// Draw the intended second rectangle without any scissoring.
	nvg.Save(ctx)
	nvg.ResetScissor(ctx)
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, -20, -10, 60, 30)
	nvg.FillColor(ctx, nvg.RGBA(255, 128, 0, 64))
	nvg.Fill(ctx)
	nvg.Restore(ctx)

	// Draw second rectangle with combined scissoring.
	nvg.IntersectScissor(ctx, -20, -10, 60, 30)
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, -20, -10, 60, 30)
	nvg.FillColor(ctx, nvg.RGBA(255, 128, 0, 255))
	nvg.Fill(ctx)

	nvg.Restore(ctx)
}

Icon :: enum {
	None          = 0x0,
	Search        = 0x1F50D,
	Circled_Cross = 0x2716,
	Chevron_Right = 0xE75E,
	Check         = 0x2713,
	Login         = 0xE740,
	Trash         = 0xE729,
}

cpToUTF8 :: proc(icon: Icon, str: ^[8]u8) -> string {
	cp := rune(icon)
	bytes, size := utf8.encode_rune(cp)
	for i in 0 ..< size {
		str[i] = bytes[i]
	}
	return string(str[:size])
}

drawSearchBox :: proc(ctx: ^nvg.Context, text: string, x, y, w, h: f32) {
	cornerRadius := f32(h) / 2 - 1

	// Edit
	bg := nvg.BoxGradient(x, y + 1.5, w, h, h / 2, 5, nvg.RGBA(0, 0, 0, 16), nvg.RGBA(0, 0, 0, 92))
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x, y, w, h, cornerRadius)
	nvg.FillPaint(ctx, bg)
	nvg.Fill(ctx)

	nvg.FontSize(ctx, h * 1.3)
	nvg.FontFace(ctx, "icons")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 64))
	nvg.TextAlign(ctx, .CENTER, .MIDDLE)
	nvg.TextIcon(ctx, x + h * 0.55, y + h * 0.55, rune(Icon.Search))

	nvg.FontSize(ctx, 17.0)
	nvg.FontFace(ctx, "sans")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 32))
	nvg.TextAlign(ctx, .LEFT, .MIDDLE)
	nvg.Text(ctx, x + h * 1.05, y + h * 0.5, text)

	nvg.FontSize(ctx, h * 1.3)
	nvg.FontFace(ctx, "icons")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 32))
	nvg.TextAlign(ctx, .CENTER, .MIDDLE)
	nvg.TextIcon(ctx, x + w - h * 0.55, y + h * 0.55, rune(Icon.Circled_Cross))
}

drawDropDown :: proc(ctx: ^nvg.Context, text: string, x, y, w, h: f32) {
	cornerRadius := f32(4.0)

	bg := nvg.LinearGradient(x, y, x, y + h, nvg.RGBA(255, 255, 255, 16), nvg.RGBA(0, 0, 0, 16))
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + 1, y + 1, w - 2, h - 2, cornerRadius - 1)
	nvg.FillPaint(ctx, bg)
	nvg.Fill(ctx)

	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, cornerRadius - 0.5)
	nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 48))
	nvg.Stroke(ctx)

	nvg.FontSize(ctx, 17.0)
	nvg.FontFace(ctx, "sans")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 160))
	nvg.TextAlign(ctx, .LEFT, .MIDDLE)
	nvg.Text(ctx, x + h * 0.3, y + h * 0.5, text)

	nvg.FontSize(ctx, h * 1.3)
	nvg.FontFace(ctx, "icons")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 64))
	nvg.TextAlign(ctx, .CENTER, .MIDDLE)
	nvg.TextIcon(ctx, x + w - h * 0.5, y + h * 0.5, rune(Icon.Chevron_Right))
}

drawLabel :: proc(ctx: ^nvg.Context, text: string, x, y, w, h: f32) {
	nvg.FontSize(ctx, 15.0)
	nvg.FontFace(ctx, "sans")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 128))

	nvg.TextAlign(ctx, .LEFT, .MIDDLE)
	nvg.Text(ctx, x, y + h * 0.5, text)
}

drawEditBoxBase :: proc(ctx: ^nvg.Context, x, y, w, h: f32) {
	// Edit
	bg := nvg.BoxGradient(
		x + 1,
		y + 1 + 1.5,
		w - 2,
		h - 2,
		3,
		4,
		nvg.RGBA(255, 255, 255, 32),
		nvg.RGBA(32, 32, 32, 32),
	)
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + 1, y + 1, w - 2, h - 2, 4 - 1)
	nvg.FillPaint(ctx, bg)
	nvg.Fill(ctx)

	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, 4 - 0.5)
	nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 48))
	nvg.Stroke(ctx)
}

drawEditBox :: proc(ctx: ^nvg.Context, text: string, x, y, w, h: f32) {

	drawEditBoxBase(ctx, x, y, w, h)

	nvg.FontSize(ctx, 17.0)
	nvg.FontFace(ctx, "sans")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 64))
	nvg.TextAlign(ctx, .LEFT, .MIDDLE)
	nvg.Text(ctx, x + h * 0.3, y + h * 0.5, text)
}

drawEditBoxNum :: proc(ctx: ^nvg.Context, text: string, units: string, x, y, w, h: f32) {
	drawEditBoxBase(ctx, x, y, w, h)

	uw := nvg.TextBounds(ctx, 0, 0, units)

	nvg.FontSize(ctx, 15.0)
	nvg.FontFace(ctx, "sans")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 64))
	nvg.TextAlign(ctx, .RIGHT, .MIDDLE)
	nvg.Text(ctx, x + w - h * 0.3, y + h * 0.5, units)

	nvg.FontSize(ctx, 17.0)
	nvg.FontFace(ctx, "sans")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 128))
	nvg.TextAlign(ctx, .RIGHT, .MIDDLE)
	nvg.Text(ctx, x + w - uw - h * 0.5, y + h * 0.5, text)
}

drawCheckBox :: proc(ctx: ^nvg.Context, text: string, x, y, w, h: f32) {
	nvg.FontSize(ctx, 15.0)
	nvg.FontFace(ctx, "sans")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 160))

	nvg.TextAlign(ctx, .LEFT, .MIDDLE)
	nvg.Text(ctx, x + 28, y + h * 0.5, text)

	bg := nvg.BoxGradient(
		x + 1,
		y + (h * 0.5) - 9 + 1,
		18,
		18,
		3,
		3,
		nvg.RGBA(0, 0, 0, 32),
		nvg.RGBA(0, 0, 0, 92),
	)
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + 1, y + (h * 0.5) - 9, 18, 18, 3)
	nvg.FillPaint(ctx, bg)
	nvg.Fill(ctx)

	nvg.FontSize(ctx, 33)
	nvg.FontFace(ctx, "icons")
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 128))
	nvg.TextAlign(ctx, .CENTER, .MIDDLE)
	nvg.TextIcon(ctx, x + 9 + 2, y + h * 0.5, rune(Icon.Check))
}

isBlack :: #force_inline proc(col: nvg.Color) -> bool {
	return col == {}
}

drawButton :: proc(
	ctx: ^nvg.Context,
	preicon: Icon,
	text: string,
	x, y, w, h: f32,
	col: nvg.Color,
) {
	icon: [8]u8
	cornerRadius := f32(4.0)
	tw, iw: f32

	bg := nvg.LinearGradient(
		x,
		y,
		x,
		y + h,
		nvg.RGBA(255, 255, 255, isBlack(col) ? 16 : 32),
		nvg.RGBA(0, 0, 0, isBlack(col) ? 16 : 32),
	)
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + 1, y + 1, w - 2, h - 2, cornerRadius - 1)
	if (!isBlack(col)) {
		nvg.FillColor(ctx, col)
		nvg.Fill(ctx)
	}
	nvg.FillPaint(ctx, bg)
	nvg.Fill(ctx)

	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + 0.5, y + 0.5, w - 1, h - 1, cornerRadius - 0.5)
	nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 48))
	nvg.Stroke(ctx)

	nvg.FontSize(ctx, 17.0)
	nvg.FontFace(ctx, "sans-bold")
	tw = nvg.TextBounds(ctx, 0, 0, text)
	if preicon != .None {
		nvg.FontSize(ctx, h * 1.3)
		nvg.FontFace(ctx, "icons")
		iw = nvg.TextBounds(ctx, 0, 0, cpToUTF8(preicon, &icon))
		iw += h * 0.15
	}

	if preicon != .None {
		nvg.FontSize(ctx, h * 1.3)
		nvg.FontFace(ctx, "icons")
		nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 96))
		nvg.TextAlign(ctx, .LEFT, .MIDDLE)
		nvg.TextIcon(ctx, x + w * 0.5 - tw * 0.5 - iw * 0.75, y + h * 0.5, rune(preicon))
	}

	nvg.FontSize(ctx, 17.0)
	nvg.FontFace(ctx, "sans-bold")
	nvg.TextAlign(ctx, .LEFT, .MIDDLE)
	nvg.FillColor(ctx, nvg.RGBA(0, 0, 0, 160))
	nvg.Text(ctx, x + w * 0.5 - tw * 0.5 + iw * 0.25, y + h * 0.5 - 1, text)
	nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 160))
	nvg.Text(ctx, x + w * 0.5 - tw * 0.5 + iw * 0.25, y + h * 0.5, text)
}

drawSlider :: proc(ctx: ^nvg.Context, pos, x, y, w, h: f32) {
	cy := y + math.round(h * 0.5)
	kr := math.round(h * 0.25)

	nvg.Save(ctx)

	// Slot
	bg := nvg.BoxGradient(x, cy - 2 + 1, w, 4, 2, 2, nvg.RGBA(0, 0, 0, 32), nvg.RGBA(0, 0, 0, 128))
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x, cy - 2, w, 4, 2)
	nvg.FillPaint(ctx, bg)
	nvg.Fill(ctx)

	// Knob Shadow
	bg = nvg.RadialGradient(
		x + math.round(pos * w),
		cy + 1,
		kr - 3,
		kr + 3,
		nvg.RGBA(0, 0, 0, 64),
		nvg.RGBA(0, 0, 0, 0),
	)
	nvg.BeginPath(ctx)
	nvg.Rect(
		ctx,
		x + math.round(pos * w) - kr - 5,
		cy - kr - 5,
		kr * 2 + 5 + 5,
		kr * 2 + 5 + 5 + 3,
	)
	nvg.Circle(ctx, x + math.round(pos * w), cy, kr)
	nvg.PathSolidity(ctx, .HOLE)
	nvg.FillPaint(ctx, bg)
	nvg.Fill(ctx)

	// Knob
	knob := nvg.LinearGradient(
		x,
		cy - kr,
		x,
		cy + kr,
		nvg.RGBA(255, 255, 255, 16),
		nvg.RGBA(0, 0, 0, 16),
	)
	nvg.BeginPath(ctx)
	nvg.Circle(ctx, x + math.round(pos * w), cy, kr - 1)
	nvg.FillColor(ctx, nvg.RGBA(40, 43, 48, 255))
	nvg.Fill(ctx)
	nvg.FillPaint(ctx, knob)
	nvg.Fill(ctx)

	nvg.BeginPath(ctx)
	nvg.Circle(ctx, x + math.round(pos * w), cy, kr - 0.5)
	nvg.StrokeColor(ctx, nvg.RGBA(0, 0, 0, 92))
	nvg.Stroke(ctx)

	nvg.Restore(ctx)
}

drawSpinner :: proc(ctx: ^nvg.Context, cx, cy, r, t: f32) {
	a0 := 0.0 + t * 6
	a1 := math.PI + t * 6
	r0 := r
	r1 := r * 0.75

	nvg.Save(ctx)

	nvg.BeginPath(ctx)
	nvg.Arc(ctx, cx, cy, r0, a0, a1, .CW)
	nvg.Arc(ctx, cx, cy, r1, a1, a0, .CCW)
	nvg.ClosePath(ctx)
	ax := cx + math.cos(a0) * (r0 + r1) * 0.5
	ay := cy + math.sin(a0) * (r0 + r1) * 0.5
	bx := cx + math.cos(a1) * (r0 + r1) * 0.5
	by := cy + math.sin(a1) * (r0 + r1) * 0.5
	paint := nvg.LinearGradient(ax, ay, bx, by, nvg.RGBA(0, 0, 0, 0), nvg.RGBA(0, 0, 0, 128))
	nvg.FillPaint(ctx, paint)
	nvg.Fill(ctx)

	nvg.Restore(ctx)
}

drawThumbnails :: proc(ctx: ^nvg.Context, x, y, w, h: f32, images: []int, t: f32) {
	cornerRadius := f32(3.0)
	thumb := f32(60.0)
	arry := f32(30.5)
	stackh := (f32(len(images)) / 2) * (thumb + 10) + 10
	u := (1 + math.cos(t * 0.5)) * 0.5
	u2 := (1 - math.cos(t * 0.2)) * 0.5

	nvg.Save(ctx)

	// Drop shadow
	shadowPaint := nvg.BoxGradient(
		x,
		y + 4,
		w,
		h,
		cornerRadius * 2,
		20,
		nvg.RGBA(0, 0, 0, 128),
		nvg.RGBA(0, 0, 0, 0),
	)
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, x - 10, y - 10, w + 20, h + 30)
	nvg.RoundedRect(ctx, x, y, w, h, cornerRadius)
	nvg.PathSolidity(ctx, .HOLE)
	nvg.FillPaint(ctx, shadowPaint)
	nvg.Fill(ctx)

	// Window
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x, y, w, h, cornerRadius)
	nvg.MoveTo(ctx, x - 10, y + arry)
	nvg.LineTo(ctx, x + 1, y + arry - 11)
	nvg.LineTo(ctx, x + 1, y + arry + 11)
	nvg.FillColor(ctx, nvg.RGBA(200, 200, 200, 255))
	nvg.Fill(ctx)

	nvg.Save(ctx)
	nvg.Scissor(ctx, x, y, w, h)
	nvg.Translate(ctx, 0, -(stackh - h) * u)

	dv := 1.0 / f32(len(images) - 1)
	ix, iy, iw, ih: f32

	for i in 0 ..< len(images) {
		tx := x + 10
		ty := y + 10
		tx += f32(i % 2) * (thumb + 10)
		ty += f32(i / 2) * (thumb + 10)
		imgw, imgh := nvg.ImageSize(ctx, images[i])
		if imgw < imgh {
			iw = thumb
			ih = iw * f32(imgh) / f32(imgw)
			ix = 0
			iy = -(ih - thumb) * 0.5
		} else {
			ih = thumb
			iw = ih * f32(imgw) / f32(imgh)
			ix = -(iw - thumb) * 0.5
			iy = 0
		}

		v := f32(i) * dv
		a := clamp((u2 - v) / dv, 0, 1)

		if a < 1.0 {
			drawSpinner(ctx, tx + thumb / 2, ty + thumb / 2, thumb * 0.25, t)
		}

		imgPaint := nvg.ImagePattern(tx + ix, ty + iy, iw, ih, 0.0 / 180.0 * math.PI, images[i], a)
		nvg.BeginPath(ctx)
		nvg.RoundedRect(ctx, tx, ty, thumb, thumb, 5)
		nvg.FillPaint(ctx, imgPaint)
		nvg.Fill(ctx)

		shadowPaint = nvg.BoxGradient(
			tx - 1,
			ty,
			thumb + 2,
			thumb + 2,
			5,
			3,
			nvg.RGBA(0, 0, 0, 128),
			nvg.RGBA(0, 0, 0, 0),
		)
		nvg.BeginPath(ctx)
		nvg.Rect(ctx, tx - 5, ty - 5, thumb + 10, thumb + 10)
		nvg.RoundedRect(ctx, tx, ty, thumb, thumb, 6)
		nvg.PathSolidity(ctx, .HOLE)
		nvg.FillPaint(ctx, shadowPaint)
		nvg.Fill(ctx)

		nvg.BeginPath(ctx)
		nvg.RoundedRect(ctx, tx + 0.5, ty + 0.5, thumb - 1, thumb - 1, 4 - 0.5)
		nvg.StrokeWidth(ctx, 1.0)
		nvg.StrokeColor(ctx, nvg.RGBA(255, 255, 255, 192))
		nvg.Stroke(ctx)
	}
	nvg.Restore(ctx)

	// Hide fades
	fadePaint := nvg.LinearGradient(
		x,
		y,
		x,
		y + 6,
		nvg.RGBA(200, 200, 200, 255),
		nvg.RGBA(200, 200, 200, 0),
	)
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, x + 4, y, w - 8, 6)
	nvg.FillPaint(ctx, fadePaint)
	nvg.Fill(ctx)

	fadePaint = nvg.LinearGradient(
		x,
		y + h,
		x,
		y + h - 6,
		nvg.RGBA(200, 200, 200, 255),
		nvg.RGBA(200, 200, 200, 0),
	)
	nvg.BeginPath(ctx)
	nvg.Rect(ctx, x + 4, y + h - 6, w - 8, 6)
	nvg.FillPaint(ctx, fadePaint)
	nvg.Fill(ctx)

	// Scroll bar
	shadowPaint = nvg.BoxGradient(
		x + w - 12 + 1,
		y + 4 + 1,
		8,
		h - 8,
		3,
		4,
		nvg.RGBA(0, 0, 0, 32),
		nvg.RGBA(0, 0, 0, 92),
	)
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + w - 12, y + 4, 8, h - 8, 3)
	nvg.FillPaint(ctx, shadowPaint)
	nvg.Fill(ctx)

	scrollh := (h / stackh) * (h - 8)
	shadowPaint = nvg.BoxGradient(
		x + w - 12 - 1,
		y + 4 + (h - 8 - scrollh) * u - 1,
		8,
		scrollh,
		3,
		4,
		nvg.RGBA(220, 220, 220, 255),
		nvg.RGBA(128, 128, 128, 255),
	)
	nvg.BeginPath(ctx)
	nvg.RoundedRect(ctx, x + w - 12 + 1, y + 4 + 1 + (h - 8 - scrollh) * u, 8 - 2, scrollh - 2, 2)
	nvg.FillPaint(ctx, shadowPaint)
	nvg.Fill(ctx)

	nvg.Restore(ctx)
}

drawParagraph :: proc(ctx: ^nvg.Context, x, y, width, height: f32, mx, my: f32) {
	text := "This is longer chunk of text.\n  \n  Would have used lorem ipsum but she    was busy jumping over the lazy dog with the fox and all the men who came to the aid of the party.🎉"
	hoverText := "Hover your mouse over the text to see calculated caret position."
	nvg.Save(ctx)
	defer nvg.Restore(ctx)

	nvg.FontSize(ctx, 15.0)
	nvg.FontFace(ctx, "sans")
	nvg.TextAlign(ctx, .LEFT, .TOP)
	_, _, lineh := nvg.TextMetrics(ctx)

	// The text break API can be used to fill a large buffer of rows,
	// or to iterate over the text just few lines (or just one) at a time.
	// The "next" variable of the last returned item tells where to continue.
	input := text
	rows: [3]nvg.Text_Row
	rows_mod := rows[:]
	lnum, gutter: int
	y := y
	gx, gy: f32

	positions: [100]nvg.Glyph_Position
	glyphs := positions[:]

	for nrows, input_last in nvg.TextBreakLines(ctx, &input, width, &rows_mod) {
		for i in 0 ..< nrows {
			row := &rows[i]
			hit := mx > x && mx < (x + width) && my >= y && my < (y + lineh)

			nvg.BeginPath(ctx)
			nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, hit ? 64 : 16))
			nvg.Rect(ctx, x + row.minx, y, row.maxx - row.minx, lineh)
			nvg.Fill(ctx)

			nvg.FillColor(ctx, nvg.RGBA(255, 255, 255, 255))
			text = input_last[row.start:row.end]
			nvg.Text(ctx, x, y, text)

			if hit {
				caretx := (mx < x + row.width / 2) ? x : x + row.width
				px := x
				nglyphs := nvg.TextGlyphPositions(ctx, x, y, text, &glyphs)

				for j in 0 ..< nglyphs {
					x0 := glyphs[j].x
					x1 := (j + 1 < nglyphs) ? glyphs[j + 1].x : x + row.width
					gx = x0 * 0.3 + x1 * 0.7
					if mx >= px && mx < gx {
						caretx = glyphs[j].x
					}

					px = gx
				}

				nvg.BeginPath(ctx)
				nvg.FillColor(ctx, nvg.RGBA(255, 192, 0, 255))
				nvg.Rect(ctx, caretx, y, 1, lineh)
				nvg.Fill(ctx)

				gutter = lnum + 1
				gx = x - 10
				gy = y + lineh / 2
			}

			lnum += 1
			y += lineh
		}
	}

	bounds: [4]f32

	if false {
		txt := fmt.tprintf("%d", gutter)
		nvg.FontSize(ctx, 12.0)
		nvg.TextAlign(ctx, .RIGHT, .MIDDLE)

		nvg.TextBounds(ctx, gx, gy, txt, &bounds)

		nvg.BeginPath(ctx)
		nvg.FillColor(ctx, nvg.RGBA(255, 192, 0, 255))
		nvg.RoundedRect(
			ctx,
			math.round(bounds[0]) - 4,
			math.round(bounds[1]) - 2,
			math.round(bounds[2] - bounds[0]) + 8,
			math.round(bounds[3] - bounds[1]) + 4,
			(math.round(bounds[3] - bounds[1]) + 4) / 2 - 1,
		)
		nvg.Fill(ctx)

		nvg.FillColor(ctx, nvg.RGBA(32, 32, 32, 255))
		nvg.Text(ctx, gx, gy, txt)
	}

	y += 20.0

	nvg.FontSize(ctx, 11.0)
	nvg.TextAlign(ctx, .LEFT, .TOP)
	nvg.TextLineHeight(ctx, 1.2)

	nvg.TextBoxBounds(ctx, x, y, 150, hoverText, &bounds)

	// Fade the tooltip out when close to it.
	gx = clamp(mx, bounds[0], bounds[2]) - mx
	gy = clamp(my, bounds[1], bounds[3]) - my
	a := math.sqrt(gx * gx + gy * gy) / 30.0
	a = clamp(a, 0, 1)
	nvg.GlobalAlpha(ctx, a)

	nvg.BeginPath(ctx)
	nvg.FillColor(ctx, nvg.RGBA(220, 220, 220, 255))
	nvg.RoundedRect(
		ctx,
		bounds[0] - 2,
		bounds[1] - 2,
		math.round(bounds[2] - bounds[0]) + 4,
		math.round(bounds[3] - bounds[1]) + 4,
		3,
	)
	px := math.round((bounds[2] + bounds[0]) / 2)
	nvg.MoveTo(ctx, px, bounds[1] - 10)
	nvg.LineTo(ctx, px + 7, bounds[1] + 1)
	nvg.LineTo(ctx, px - 7, bounds[1] + 1)
	nvg.Fill(ctx)

	nvg.FillColor(ctx, nvg.RGBA(0, 0, 0, 220))
	nvg.TextBox(ctx, x, y, 150, hoverText)
}

renderDemo :: proc(
	ctx: ^nvg.Context,
	mx, my: f32,
	width, height: f32,
	t: f32,
	blowup: bool,
	data: ^DemoData,
) {
	drawEyes(ctx, width - 250, 50, 150, 100, mx, my, t)
	drawParagraph(ctx, width - 450, 50, 150, 100, mx, my)
	drawGraph(ctx, 0, height / 2, width, height / 2, t)
	drawColorwheel(ctx, width - 300, height - 300, 250.0, 250.0, t)

	// Line joints
	drawLines(ctx, 120, height - 50, 600, 50, t)

	// Line caps
	drawWidths(ctx, 10, 50, 30)

	// Line caps
	drawCaps(ctx, 10, 300, 30)

	drawScissor(ctx, 50, height - 80, t)

	nvg.Save(ctx)
	if blowup {
		nvg.Rotate(ctx, math.sin(t * 0.3) * 5.0 / 180.0 * math.PI)
		nvg.Scale(ctx, 2.0, 2.0)
	}

	// widgets
	drawWindow(ctx, "Widgets `n Stuff", 50, 50, 300, 400)
	x := f32(60)
	y := f32(95)
	drawSearchBox(ctx, "Search", x, y, 280, 25)
	y += 40
	drawDropDown(ctx, "Effects", x, y, 280, 28)

	popy := y + 14
	y += 45

	drawLabel(ctx, "Login", x, y, 280, 20)
	y += 25
	drawEditBox(ctx, "Email", x, y, 280, 28)
	y += 35
	drawEditBox(ctx, "Password", x, y, 280, 28)
	y += 38
	drawCheckBox(ctx, "Remember me", x, y, 140, 28)
	drawButton(ctx, .Login, "Sign in", x + 138, y, 140, 28, nvg.RGBA(0, 96, 128, 255))
	y += 45

	// Slider
	drawLabel(ctx, "Diameter", x, y, 280, 20)
	y += 25
	drawEditBoxNum(ctx, "123.00", "px", x + 180, y, 100, 28)
	drawSlider(ctx, 0.4, x, y, 170, 28)
	y += 55

	drawButton(ctx, .Trash, "Delete", x, y, 160, 28, nvg.RGBA(128, 16, 8, 255))
	drawButton(ctx, .None, "Cancel", x + 170, y, 110, 28, nvg.RGBA(0, 0, 0, 0))

	// Thumbnails box
	drawThumbnails(ctx, 365, popy - 30, 160, 300, data.images[:], t)

	nvg.Restore(ctx)
}

loadDemoData :: proc(ctx: ^nvg.Context, data: ^DemoData) {
	if ctx == nil {
		panic("loadDemoData failed! ctx was nil")
	}

	builder := strings.builder_make(0, 128, context.temp_allocator)
	for i in 0 ..< 12 {
		// hacky way around cstrings
		strings.builder_reset(&builder)
		fmt.sbprintf(&builder, "images/image%d.jpg", i + 1)
		strings.write_byte(&builder, 0)
		file := strings.unsafe_string_to_cstring(strings.to_string(builder))

		data.images[i] = nvg.CreateImage(ctx, file, {})
		if data.images[i] == 0 {
			fmt.panicf("Could not load %s.", file)
		}
	}

	data.fontIcons = nvg.CreateFont(ctx, "icons", "fonts/entypo.ttf")
	if (data.fontIcons == -1) {
		panic("Could not add font icons.")
	}
	data.fontNormal = nvg.CreateFont(ctx, "sans", "fonts/Roboto-Regular.ttf")
	if (data.fontNormal == -1) {
		panic("Could not add font italic.")
	}
	data.fontBold = nvg.CreateFont(ctx, "sans-bold", "fonts/Roboto-Bold.ttf")
	if (data.fontBold == -1) {
		panic("Could not add font bold.")
	}
	data.fontEmoji = nvg.CreateFont(ctx, "emoji", "fonts/NotoEmoji-Regular.ttf")
	if (data.fontEmoji == -1) {
		panic("Could not add font emoji.")
	}

	nvg.AddFallbackFontId(ctx, data.fontNormal, data.fontEmoji)
	nvg.AddFallbackFontId(ctx, data.fontBold, data.fontEmoji)
}

freeDemoData :: proc(ctx: ^nvg.Context, data: ^DemoData) {
	if ctx == nil {
		return
	}

	for i in 0 ..< 12 {
		nvg.DeleteImage(ctx, data.images[i])
	}
}

mini :: #force_inline proc(a, b: int) -> int {
	return a < b ? a : b
}

unpremultiplyAlpha :: proc(image: []byte, w, h, stride: int) {
	// Unpremultiply
	for y in 0 ..< h {
		row := image[y * stride:]

		for _ in 0 ..< w {
			r := row[0]
			g := row[1]
			b := row[2]
			a := row[3]

			if a != 0 {
				row[0] = u8(mini(int(r) * 255 / int(a), 255))
				row[1] = u8(mini(int(g) * 255 / int(a), 255))
				row[2] = u8(mini(int(b) * 255 / int(a), 255))
			}

			row = row[4:]
		}
	}

	// Defringe
	for y in 0 ..< h {
		row_index := y * stride

		for x in 0 ..< w {
			row := image[row_index:]
			r := 0
			g := 0
			b := 0
			a := row[3]
			n := 0

			if a == 0 {
				if x - 1 > 0 && image[row_index - 1] != 0 {
					r += int(image[row_index - 4])
					g += int(image[row_index - 3])
					b += int(image[row_index - 2])
					n += 1
				}
				if x + 1 < w && row[7] != 0 {
					r += int(row[4])
					g += int(row[5])
					b += int(row[6])
					n += 1
				}
				if y - 1 > 0 && image[row_index - stride + 3] != 0 {
					r += int(image[row_index - stride])
					g += int(image[row_index - stride + 1])
					b += int(image[row_index - stride + 2])
					n += 1
				}
				if y + 1 < h && row[stride + 3] != 0 {
					r += int(row[stride])
					g += int(row[stride + 1])
					b += int(row[stride + 2])
					n += 1
				}
				if n > 0 {
					row[0] = u8(f32(r) / f32(n))
					row[1] = u8(f32(g) / f32(n))
					row[2] = u8(f32(b) / f32(n))
				}
			}

			row_index += 4
		}
	}
}

setAlpha :: proc(image: []byte, w, h, stride: int, a: u8) {
	for y in 0 ..< h {
		row := image[y * stride:]

		for x in 0 ..< w {
			row[x * 4 + 3] = a
		}
	}
}

flipHorizontal :: proc(image: []byte, w, h, stride: int) {
	i: int
	j := h - 1

	for i < j {
		ri := image[i * stride:]
		rj := image[j * stride:]

		for k in 0 ..< (w * 4) {
			ri[k], rj[k] = rj[k], ri[k]
		}

		i += 1
		j -= 1
	}
}

saveScreenshot :: proc(w, h: int, premult: bool, name: cstring) {
	image := make([]byte, w * h * 4)
	defer delete(image)

	gl.ReadPixels(0, 0, i32(w), i32(h), gl.RGBA, gl.UNSIGNED_BYTE, raw_data(image))
	if premult {
		unpremultiplyAlpha(image, w, h, w * 4)
	} else {
		setAlpha(image, w, h, w * 4, 255)
	}
	flipHorizontal(image, w, h, w * 4)
	stbi.write_png(name, i32(w), i32(h), 4, raw_data(image), i32(w) * 4)
}

GRAPH_HISTORY_COUNT :: 100

GraphrenderStyle :: enum {
	FPS,
	MS,
	PERCENT,
}

PerfGraph :: struct {
	style:  GraphrenderStyle,
	name:   string,
	values: [GRAPH_HISTORY_COUNT]f32,
	head:   int,
}

initGraph :: proc(fps: ^PerfGraph, style: GraphrenderStyle, name: string) {
	fps.style = style
	fps.name = name
}

updateGraph :: proc(fps: ^PerfGraph, frameTime: f32) {
	fps.head = (fps.head + 1) % GRAPH_HISTORY_COUNT
	fps.values[fps.head] = frameTime
}

renderGraph :: proc(ctx: ^nvg.Context, x, y: f32, fps: ^PerfGraph) {
	avg := getGraphAverage(fps)
	w := f32(200)
	h := f32(35)

	nvg.BeginPath(ctx)
	nvg.Rect(ctx, x, y, w, h)
	nvg.FillColor(ctx, nvg.RGBA(0, 0, 0, 128))
	nvg.Fill(ctx)

	nvg.BeginPath(ctx)
	nvg.MoveTo(ctx, x, y + h)

	switch fps.style {
	case .FPS:
		{
			for i in 0 ..< GRAPH_HISTORY_COUNT {
				v := 1.0 / (0.00001 + fps.values[(fps.head + i) % GRAPH_HISTORY_COUNT])
				if v > 80.0 {
					v = 80.0
				}
				vx := x + (f32(i) / (GRAPH_HISTORY_COUNT - 1)) * w
				vy := y + h - ((v / 80.0) * h)
				nvg.LineTo(ctx, vx, vy)
			}
		}

	case .PERCENT:
		{
			for i in 0 ..< GRAPH_HISTORY_COUNT {
				v := fps.values[(fps.head + i) % GRAPH_HISTORY_COUNT] * 1.0
				if v > 100.0 {
					v = 100.0
				}
				vx := x + (f32(i) / (GRAPH_HISTORY_COUNT - 1)) * w
				vy := y + h - ((v / 100.0) * h)
				nvg.LineTo(ctx, vx, vy)
			}
		}

	case .MS:
		{
			for i in 0 ..< GRAPH_HISTORY_COUNT {
				v := fps.values[(fps.head + i) % GRAPH_HISTORY_COUNT] * 1000.0
				if v > 20.0 {
					v = 20.0
				}
				vx := x + (f32(i) / (GRAPH_HISTORY_COUNT - 1)) * w
				vy := y + h - ((v / 20.0) * h)
				nvg.LineTo(ctx, vx, vy)
			}
		}
	}

	nvg.LineTo(ctx, x + w, y + h)
	nvg.FillColor(ctx, nvg.RGBA(255, 192, 0, 128))
	nvg.Fill(ctx)

	nvg.FontFace(ctx, "sans")

	if fps.name != "" {
		nvg.FontSize(ctx, 12.0)
		nvg.TextAlign(ctx, .LEFT, .TOP)
		nvg.FillColor(ctx, nvg.RGBA(240, 240, 240, 192))
		nvg.Text(ctx, x + 3, y + 3, fps.name)
	}

	switch fps.style {
	case .FPS:
		{
			nvg.FontSize(ctx, 15.0)
			nvg.TextAlign(ctx, .RIGHT, .TOP)
			nvg.FillColor(ctx, nvg.RGBA(240, 240, 240, 255))
			str := fmt.tprintf("%.2f FPS", 1.0 / avg)
			nvg.Text(ctx, x + w - 3, y + 3, str)

			nvg.FontSize(ctx, 13.0)
			nvg.TextAlign(ctx, .RIGHT, .BASELINE)
			nvg.FillColor(ctx, nvg.RGBA(240, 240, 240, 160))
			str = fmt.tprintf("%.2f ms", avg * 1000.0)
			nvg.Text(ctx, x + w - 3, y + h - 3, str)
		}

	case .PERCENT:
		{
			nvg.FontSize(ctx, 15.0)
			nvg.TextAlign(ctx, .RIGHT, .TOP)
			nvg.FillColor(ctx, nvg.RGBA(240, 240, 240, 255))
			str := fmt.tprintf("%.1f %%", avg * 1.0)
			nvg.Text(ctx, x + w - 3, y + 3, str)
		}

	case .MS:
		{
			nvg.FontSize(ctx, 15.0)
			nvg.TextAlign(ctx, .RIGHT, .TOP)
			nvg.FillColor(ctx, nvg.RGBA(240, 240, 240, 255))
			str := fmt.tprintf("%.2f ms", avg * 1000.0)
			nvg.Text(ctx, x + w - 3, y + 3, str)
		}
	}
}

getGraphAverage :: proc(fps: ^PerfGraph) -> f32 {
	avg := f32(0)
	for i in 0 ..< GRAPH_HISTORY_COUNT {
		avg += fps.values[i]
	}
	return avg / f32(GRAPH_HISTORY_COUNT)
}

GPU_QUERY_COUNT :: 5

GPUtimer :: struct {
	supported: bool,
	cur, ret:  int,
	queries:   [GPU_QUERY_COUNT]u32,
}

startGPUTimer :: proc(timer: ^GPUtimer) {
	if !timer.supported {
		return
	}

	gl.BeginQuery(gl.TIME_ELAPSED, timer.queries[timer.cur % GPU_QUERY_COUNT])
	timer.cur += 1
}

stopGPUTimer :: proc(timer: ^GPUtimer) {
	available := i32(1)
	if !timer.supported {
		return
	}

	gl.EndQuery(gl.TIME_ELAPSED)
	for timer.ret <= timer.cur && available == 1 {
		// check for results if there are any
		gl.GetQueryObjectiv(
			timer.queries[timer.ret % GPU_QUERY_COUNT],
			gl.QUERY_RESULT_AVAILABLE,
			&available,
		)
	}

	return
}
