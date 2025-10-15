package call_odin_from_lua

import lua "vendor:lua/5.4"
import "core:fmt"

// The code the Lua VM will run
CODE :: "print(add(2, 2))"

// Since Lua is a C library, it expects procedures with the "c" calling convention
// Odin takes advantage of an overall implied context that is implicitly passed with each procedure when it is called
// As such, calling procedures with the Odin calling convention (the regular one) inside of a "c" procedure will require you to include "base:runtime" and "context = runtime.default_context()" at the beginning of the "c" procedure
// There is a compiler check for this, and a note, so this issue is very easy to catch

// Lua expects a specific type of procedure to be defined, with the argument and return value seen below
// This procedure signature is also defined inside of the binding as CFunction, so they can easily be passed into functions
// State is the Lua state, which contains the passed arguments, and can/will contain return value(s)
add :: proc "c" (state: ^lua.State) -> i32 {
	// Check to see if both arguments that were passed are integers, and store them in variables
	// If these fail, Lua automatically pushes an error to the stack, and terminates the code it is currently executing
	a := lua.L_checkinteger(state, 1)
	b := lua.L_checkinteger(state, 2)

	// Since the integer type that the Lua library uses is a distinct copy of an i32 (because it is a C library), basic math operations are supported by default
	result := a + b

	// Push the result onto the stack
	lua.pushinteger(state, result)

	// Lua manages the stack itself once it regains control, flushing any leftover argument values (or otherwise), so there is no explicit memory management required (Within reason)
	// To make things simpler and avoid over-managing memory, Lua initalizes the stack to be able to store at least 20 values before overflowing, though it is a constant defined in "lua.MINSTACK", to be specific
	// To go beyond this number, use the function "lua.checkstack()"

	// It then takes the top number of elements of the stack, returning them to the end user
	// Return the integer that was pushed on top of the stack
	return 1
}

main :: proc() {
	// Create new Lua state
	state := lua.L_newstate()

	// Open the base libraries (print, etc...)
	lua.open_base(state)

	// This is a macro to push a CFunction to the stack, and then popping and using it to set a global value in the Lua VM's global table
	lua.register(state, "add", add)

	// Here is the extended version, for reference:
	/*
	lua.pushcfunction(state, add)
	lua.setglobal(state, "add")
	*/

	// Run code and check if it succeeded
	if lua.L_dostring(state, CODE) != 0 {
		// Get the error string from the top of the stack and print it
		error := lua.tostring(state, -1)
		fmt.println(error)
		// Pop the error off of the stack
		lua.pop(state, 1)
	}

	// Closes the Lua VM, deallocating all memory
	lua.close(state)
}