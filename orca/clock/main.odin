package src

/*
Original Source: https://github.com/orca-app/orca/blob/main/samples/clock/src/main.c

Can be run using in the local folder
1. odin.exe build main.odin -file -target:orca_wasm32 -out:module.wasm 
2. orca bundle --name orca_output --resource-dir data module.wasm
3. orca_output\bin\orca_output.exe
*/

import "core:math"
import oc "core:sys/orca"

clockNumberStrings := [?]string{"12", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"}

surface: oc.surface = {}
renderer: oc.canvas_renderer = {}
canvas: oc.canvas_context = {}
font: oc.font = {}
frameSize: oc.vec2 = {100, 100}
lastSeconds: f64 = 0

mat_transform :: proc "contextless" (x, y, radians: f32) -> oc.mat2x3 {
	rotation := oc.mat2x3_rotate(radians)
	translation := oc.mat2x3_translate(x, y)
	return oc.mat2x3_mul_m(translation, rotation)
}

main :: proc() {
	oc.window_set_title("clock")
	oc.window_set_size({400, 400})

	renderer = oc.canvas_renderer_create()
	surface = oc.canvas_surface_create(renderer)
	canvas = oc.canvas_context_create()

	ranges := [?]oc.unicode_range {
		oc.UNICODE_BASIC_LATIN,
		oc.UNICODE_C1_CONTROLS_AND_LATIN_1_SUPPLEMENT,
		oc.UNICODE_LATIN_EXTENDED_A,
		oc.UNICODE_LATIN_EXTENDED_B,
		oc.UNICODE_SPECIALS,
	}

	oc.font_create_from_path("segoeui.ttf", 5, &ranges[0])
}

@(export)
oc_on_resize :: proc "c" (width, height: u32) {
	frameSize.x = f32(width)
	frameSize.y = f32(height)
}

// TODO replace this after round_f64 is fixed: https://github.com/odin-lang/Odin/issues/3856
remainder_f64 :: proc "contextless" (x, y: f64) -> f64 {
	return x - round_slow(x / y) * y
}

round_slow :: proc "contextless" (x: f64) -> f64 {
	t := math.trunc(x)
	if abs(x - t) >= 0.5 {
		return t + math.copy_sign(1, x)
	}
	return t
}

mod_f64 :: proc "contextless" (x, y: f64) -> (n: f64) {
	z := abs(y)
	n = remainder_f64(abs(x), z)
	if math.sign(n) < 0 {
		n += z
	}
	return math.copy_sign(n, x)
}

@(export)
oc_on_frame_refresh :: proc "c" () {
	// context = runtime.default_context()

	oc.canvas_context_select(canvas)
	oc.set_color_rgba(.05, .05, .05, 1)
	oc.clear()

	timestampSecs := f64(oc.clock_time(.DATE))
	secs := mod_f64(timestampSecs, 60.0)
	minutes := mod_f64(timestampSecs, 60.0 * 60.0) / 60.0
	hours := mod_f64(timestampSecs, 60.0 * 60.0 * 24) / (60.0 * 60.0)
	hoursAs12Format := mod_f64(hours, 12.0)

	if lastSeconds != math.floor(secs) {
		lastSeconds = math.floor(secs)

		// oc.log_infof(
		// 	"current time: %.0f:%.0f:%.0f",
		// 	math.floor(hours),
		// 	math.floor(minutes),
		// 	math.floor(secs),
		// )
	}

	secondsRotation := (math.PI * 2) * (secs / 60.0) - (math.PI / 2)
	minutesRotation := (math.PI * 2) * (minutes / 60.0) - (math.PI / 2)
	hoursRotation := (math.PI * 2) * (hoursAs12Format / 12.0) - (math.PI / 2)

	centerX := frameSize.x / 2
	centerY := frameSize.y / 2
	clockRadius := min(frameSize.x, frameSize.y) * 0.5 * 0.85

	DEFAULT_CLOCK_RADIUS :: 260
	uiScale := clockRadius / DEFAULT_CLOCK_RADIUS

	fontSize := 26 * uiScale
	oc.set_font(font)
	oc.set_font_size(fontSize)

	// clock backing
	oc.set_color_rgba(1, 1, 1, 1)
	oc.circle_fill(centerX, centerY, clockRadius)

	// clock face
	for i in 0 ..< len(clockNumberStrings) {
		str := clockNumberStrings[i]
		textRect := oc.font_text_metrics(font, fontSize, str).ink

		angle := f32(i) * ((math.PI * 2) / f32(12.0)) - (math.PI / 2)
		transform := mat_transform(
			centerX - (textRect.w / 2) - textRect.x,
			centerY - (textRect.h / 2) - textRect.y,
			angle,
		)

		pos := oc.mat2x3_mul(transform, {clockRadius * 0.8, 0})

		oc.set_color_rgba(0.2, 0.2, 0.2, 1)
		oc.text_fill(pos.x, pos.y, str)
	}

	// hours hand
	oc.matrix_multiply_push(mat_transform(centerX, centerY, f32(hoursRotation)))
	{
		oc.set_color_rgba(.2, 0.2, 0.2, 1)
		oc.rounded_rectangle_fill(0, -7.5 * uiScale, clockRadius * 0.5, 15 * uiScale, 5 * uiScale)
	}
	oc.matrix_pop()

	// minutes hand
	oc.matrix_multiply_push(mat_transform(centerX, centerY, f32(minutesRotation)))
	{
		oc.set_color_rgba(.2, 0.2, 0.2, 1)
		oc.rounded_rectangle_fill(0, -5 * uiScale, clockRadius * 0.7, 10 * uiScale, 5 * uiScale)
	}
	oc.matrix_pop()

	// seconds hand
	oc.matrix_multiply_push(mat_transform(centerX, centerY, f32(secondsRotation)))
	{
		oc.set_color_rgba(1, 0.2, 0.2, 1)
		oc.rounded_rectangle_fill(0, -2.5 * uiScale, clockRadius * 0.8, 5 * uiScale, 5 * uiScale)
	}
	oc.matrix_pop()

	oc.set_color_srgba(.2, 0.2, 0.2, 1)
	oc.circle_fill(centerX, centerY, 10 * uiScale)

	oc.canvas_render(renderer, canvas, surface)
	oc.canvas_present(renderer, surface)
}
