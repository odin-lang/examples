package main

import       "core:c/libc"
import win32 "core:sys/windows"

@(private="file")
orig_mode: win32.DWORD

_enable_raw_mode :: proc() {
	// Get a handle to the standard input.
	stdin := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
	assert(stdin != win32.INVALID_HANDLE_VALUE)

	// Get the original terminal mode.
	ok := win32.GetConsoleMode(stdin, &orig_mode)
	assert(ok == true)

	// Reset to the original attributes at the end of the program.
	libc.atexit(disable_raw_mode)

	// Copy, and remove the
	// ENABLE_ECHO_INPUT (so what is typed is not shown) and
	// ENABLE_LINE_INPUT (so we get each input instead of an entire line at once) flags.
	raw := orig_mode
	raw &= ~win32.ENABLE_ECHO_INPUT
	raw &= ~win32.ENABLE_LINE_INPUT
	ok = win32.SetConsoleMode(stdin, raw)
	assert(ok == true)
}

_disable_raw_mode :: proc "c" () {
	stdin := win32.GetStdHandle(win32.STD_INPUT_HANDLE)
	assert_contextless(stdin != win32.INVALID_HANDLE_VALUE)

	win32.SetConsoleMode(stdin, orig_mode)
}

_set_utf8_terminal :: proc() {
	win32.SetConsoleOutputCP(.UTF8)
	win32.SetConsoleCP(.UTF8)
}
