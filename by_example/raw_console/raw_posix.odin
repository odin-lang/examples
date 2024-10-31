#+build !windows
package main

import psx "core:sys/posix"

@(private="file")
orig_mode: psx.termios

_enable_raw_mode :: proc() {
	// Get the original terminal attributes.
	res := psx.tcgetattr(psx.STDIN_FILENO, &orig_mode)
	assert(res == .OK)

	// Reset to the original attributes at the end of the program.
	psx.atexit(disable_raw_mode)

	// Copy, and remove the
	// ECHO (so what is typed is not shown) and
	// ICANON (so we get each input instead of an entire line at once) flags.
	raw := orig_mode
	raw.c_lflag -= {.ECHO, .ICANON}
	res = psx.tcsetattr(psx.STDIN_FILENO, .TCSANOW, &raw)
	assert(res == .OK)
}

_disable_raw_mode :: proc "c" () {
	psx.tcsetattr(psx.STDIN_FILENO, .TCSANOW, &orig_mode)
}

_set_utf8_terminal :: proc() {}
