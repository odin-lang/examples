package main

import "core:fmt"

// While it's not strictly enforced, it's common to see Odin projects have a single primary package, in this case `main`,
// and use additional files with prefixes, like our `game_`, for organization.
// In Odin, packages such as our `awesome_package`, are most commonly used for self-contained, redistributable libraries
// and not for code organization.
game_init :: proc() {
	fmt.println("game_init")
	// Even though this function is marked as `private` it's in the same file so we can call it here.
	// We can't call it from outside of this file, though.
	game_private_inside()
}

game_draw :: proc() {
	fmt.println("game_draw")
}

// These functions are private to this particular file.
@(private = "file")
game_private :: proc() {
	fmt.println("game_private")
}

@(private = "file")
game_private_inside :: proc() {
	fmt.println("game_private_another")
}
