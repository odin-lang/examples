package read_console_input

import "core:fmt"
import "core:os"

main :: proc() {
	buf: [256]byte
	fmt.println("Please enter some text:")
	n, err := os.read(os.stdin, buf[:])
	if err < 0 {
		// Handle error
		return
	}
	str := string(buf[:n])
	fmt.println("Outputted text:", str)
}
