package read_console_input

import "core:fmt"
import "core:os"

main :: proc() {
	buf: [256]byte
	fmt.println("Please enter some text:")
	n, err := io.read(buf[:])
	if err != nil {
		// Handle error
		return
	}
	str := string(buf[:n])
	fmt.println("Outputted text:", str)
}
