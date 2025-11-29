package clock

import rl "vendor:raylib"
import "core:time"
import "core:time/datetime"
import "core:time/timezone"
import "core:os"
import "core:math"
import "core:fmt"
import "core:strings"

// The time of day
Time_Period :: enum {
	AM,
	PM,
}

Error :: enum {
	LocalTimeFailed,
	TimeToDateTimeFailed,
	DateTimeToTimezoneFailed,
	DateTimeToTimeFailed,
}

// Create a vector with a specific direction and magnitude
distance_angle :: proc(distance: f32, angle: f32) -> (vector: rl.Vector2) {
	vector = {math.sin_f32(angle), -math.cos_f32(angle)} * distance

	return
}

throw_error :: proc(ok: bool, error: Error) {
	if !ok {
		fmt.printfln("An error occured: %s", error)
		os.exit(int(error))
	}
}

main :: proc() {
	// Load the local timezone for the user
	tz, ok := timezone.region_load("local")
	throw_error(ok, .LocalTimeFailed)

	// Turn on anti-aliasing
	rl.SetConfigFlags({.MSAA_4X_HINT})
	// Create window
	rl.InitWindow(640, 480, "Clock")

	// Get the center of the screen
	screen_center := rl.Vector2 {f32(rl.GetScreenWidth()) / 2, f32(rl.GetScreenHeight()) / 2}

	rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()

		rl.ClearBackground(rl.RAYWHITE)

		date_time: datetime.DateTime
		// Basic error handling
		// Get the current time, convert it to DateTime
		date_time, ok = time.time_to_datetime(time.now())
		throw_error(ok, .TimeToDateTimeFailed)

		// Get the current DateTime, convert it to the user's local timezone
		date_time, ok = timezone.datetime_to_tz(date_time, tz)
		throw_error(ok, .DateTimeToTimezoneFailed)

		// Convert the DateTime back to a regular Time struct
		regular_time: time.Time
		regular_time, ok = time.datetime_to_time(date_time)
		throw_error(ok, .DateTimeToTimeFailed)

		// Determine if it's AM or PM
		period: Time_Period
		hour, min, sec, nanos := time.precise_clock_from_time(regular_time)
		if hour > 12 {
			hour -= 12
			period = .PM
		}
		millis := nanos / int(time.Millisecond)

		// Determine the radius of the clock (not including outline)
		radius := f32(rl.GetScreenHeight()) / 2.5

		// The number of points in the clock's outer circles
		point_count: i32 = 128
		rl.DrawCircleSector(screen_center, radius + 2, 0, 360, point_count, rl.BLACK)
		rl.DrawCircleSector(screen_center, radius, 0, 360, point_count, rl.LIGHTGRAY)

		sec_scalar := (f32(sec) + (f32(millis) / 1000)) / 60
		min_scalar := (f32(min) + sec_scalar) / 60
		hour_scalar := (f32(hour) + min_scalar) / 12

		// Draw the hour hand
		rl.DrawLineEx(screen_center, screen_center + distance_angle(radius * .7, hour_scalar * math.TAU), 4, rl.DARKGREEN)
		// Draw the minute hand
		rl.DrawLineEx(screen_center, screen_center + distance_angle(radius * .75, min_scalar * math.TAU), 4, rl.BLACK)
		// Draw the second hand
		rl.DrawLineEx(screen_center, screen_center + distance_angle(radius * .5, sec_scalar * math.TAU), 4, rl.RED)

		rl.DrawCircleV(screen_center, 6, {40, 40, 40, 255})

		// Draw the dashes on the clock
		for i := 0; i < 60; i += 1 {
			angle := (f32(i) / 60) * math.TAU

			inside_distance: f32 = .8
			thickness: f32 = 1.5

			if i % 5 == 0 {
				// Hour markings
				inside_distance = .775
				thickness = 3
			}
			
			rl.DrawLineEx(screen_center + distance_angle(radius * inside_distance, angle), screen_center + distance_angle(radius * .95, angle), thickness, rl.DARKGRAY)
		}

		// Format time into a string
		str := fmt.aprintfln("%2d:%2d:%2d %s", hour, min, sec, period, allocator = context.temp_allocator)
		c_str := strings.clone_to_cstring(str, context.temp_allocator)

		// Center and draw text
		default_font := rl.GetFontDefault()
		text_size := rl.MeasureTextEx(default_font, c_str, 30, f32(default_font.glyphPadding) + 1)

		rl.DrawTextEx(default_font, c_str, {screen_center.x - (text_size.x / 2), f32(rl.GetScreenHeight()) - (30 * 1.25)}, 30 * 1.0001, f32(default_font.glyphPadding) + 1, rl.DARKGRAY)

		rl.EndDrawing()

		// Garbage collection
		free_all(context.temp_allocator)
	}

	rl.CloseWindow()

	// Unload user's local timezone
	timezone.region_destroy(tz)
}