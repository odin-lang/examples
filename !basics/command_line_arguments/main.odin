package main 

import "core:fmt"
import "core:os"

main :: proc() {
	// os.args is a []string
	fmt.println(os.args[0])  // executable name
	fmt.println(os.args[1:]) // the rest of the arguments
}
