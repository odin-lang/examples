package main

import "./awesome_package"
import "core:fmt"

// See the comments below and be sure to see the other files for additional details!
main :: proc() {
	// There's no need to import anything here. Even though `game_init()` and `game_draw()` are in a different file,
	// the are in the same `main` package as this file, so are automatically accessible.
	game_init()
	game_draw()

	// This won't compile because `game_private()` is marked as private to the file it is in.
	// `Error: Undeclared name: game_private`
	// game_private()

	// We've imported our `awesome_package` so we can use its function here now.
	num := awesome_package.add(2, 3)
	fmt.printfln("My awesome number: %d", num)

	// But we can't use this function as it's marked as private to its package, so is unexported.
	// `Error: 'subtract_private' is not exported by 'awesome_package'`
	// num2 := awesome_package.subtract_private(3, 2)
}
