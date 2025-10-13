package main

import lua "vendor:lua/5.4"
import "core:fmt"

// The code the Lua VM will run
CODE :: "print(Answer)"

main :: proc() {
	// Create new Lua state
	state := lua.L_newstate()

	// Open the base libraries (print, etc...)
	lua.open_base(state)

	// Set a new global integer (a Lua 5.3+ feature!) called "answer" to 42
	// First we push the integer to the stack, which is our "postboard" to talk with the Lua VM
	lua.pushinteger(state, 42)
	// Pops the top value on the stack and creates a global with it's value
	lua.setglobal(state, "Answer")

	// Run code and check if it succeeded
	if (lua.L_dostring(state, CODE) != 0) {
		// Get the error string from the top of the stack and print it
		error := lua.tostring(state, -1)
		fmt.println(error)
		// Pop the error off of the stack
		lua.pop(state, 1)
	}

	// Closes the Lua VM, deallocating all memory
	lua.close(state)
}