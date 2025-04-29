package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:time"
import "core:unicode/utf8"

get_password :: proc(allocator := context.allocator) -> string {
	enable_raw_mode()
	defer disable_raw_mode()

	fmt.print("Enter password: ")

	buf := make([dynamic]byte, allocator)
	in_stream := os.stream_from_handle(os.stdin)

	for {
		// Read a single character at a time.
		ch, sz, err := io.read_rune(in_stream)
		switch {
		case err != nil:
			fmt.eprintfln("\nError: %v", err)
			os.exit(1)

		// End line
		case ch == '\n': // Posix
			fallthrough
		case ch == '\r': // Windows
			fmt.println()
			return string(buf[:])

		// Backspace
		case ch == '\u007f': // Posix
			fallthrough
		case ch == '\b':     // Windows
			_, bs_sz := utf8.decode_last_rune(buf[:])	
			if bs_sz > 0 {
				resize(&buf, len(buf)-bs_sz)
				// Replace last star with a space.
				fmt.print("\b \b")
			}
		case:
			bytes, _ := utf8.encode_rune(ch)
			append(&buf, ..bytes[:sz])

			fmt.print('*')
		}
	}
}

draw_progress_bar :: proc(title: string, percent: int, width := 25) {
	fmt.printf("\r%v[", title, flush=false) // Put cursor back at the start of the line

	done := percent * width / 100
	left := width - done
	for _ in 0..<done {
		fmt.printf("|", flush=false)
	}
	for _ in 0..<left {
		fmt.printf(" ", flush=false)
	}
	fmt.printf("] %d%%", percent)
}

main :: proc() {
	set_utf8_terminal()

	password := get_password()
	defer delete(password)

	for i in 0..=100 {
		draw_progress_bar("Processing login: ", i)
		time.sleep(50 * time.Millisecond)
	}
	fmt.println("\nDone")

	fmt.printfln("\nYour password was: \"%s\"", password)
}

enable_raw_mode :: proc() {
	_enable_raw_mode()
}

disable_raw_mode :: proc "c" () {
	_disable_raw_mode()
}

set_utf8_terminal :: proc() {
	_set_utf8_terminal()
}
