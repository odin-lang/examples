package hellope_lua

import lua "vendor:lua/5.4"
import "core:fmt"

// The file of code the Lua VM will run
FILE :: "main.lua"

main :: proc() {
	// Create new Lua state
	state := lua.L_newstate()

	// Open the base libraries (print, etc...)
	lua.open_base(state)

	// Run code and check if it succeeded
	if lua.L_dofile(state, FILE) != 0 {
		// Get the error string from the top of the stack and print it
		error := lua.tostring(state, -1)
		fmt.println(error)
		// Pop the error off of the stack
		lua.pop(state, 1)
	}

	// Closes the Lua VM, deallocating all memory
	lua.close(state)
}