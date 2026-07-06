package raylib_example_log

import       "base:runtime"

import       "core:log"
import       "core:c"

import rl    "vendor:raylib"
import stbsp "vendor:stb/sprintf"

SCREEN_WIDTH  :: 800
SCREEN_HEIGHT :: 450

g_ctx: runtime.Context

main :: proc() {
	context.logger = log.create_console_logger(.Debug)
	g_ctx = context

	rl.SetTraceLogLevel(.ALL)
	rl.SetTraceLogCallback(proc "c" (rl_level: rl.TraceLogLevel, message: cstring, args: ^c.va_list) {
		context = g_ctx

		level: log.Level
		switch rl_level {
		case .TRACE, .DEBUG: level = .Debug
		case .INFO:          level = .Info
		case .WARNING:       level = .Warning
		case .ERROR:         level = .Error
		case .FATAL:         level = .Fatal
		case .ALL, .NONE:    fallthrough
		case:                log.panicf("unexpected log level %v", rl_level)
		}

		@static buf: [dynamic]byte
		log_len: i32
		for {
			buf_len := i32(len(buf))
			log_len = stbsp.vsnprintf(raw_data(buf), buf_len, message, args)
			if log_len <= buf_len {
				break
			}

			non_zero_resize(&buf, max(128, len(buf)*2))
		}

		context.logger.procedure(context.logger.data, level, string(buf[:log_len]), context.logger.options)
	})

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "raylib log callback")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)
		rl.EndDrawing()
	}
}
