package awesome_package

// Our function here is in the `awesome_packge`. It's completely distinct from our `main` functions and package.
// One could simply copy everything in the `awesome_package` directory to their own project and use our functions!
// Packages are most commonly used in Odin for this purpose: self-contained, redistributable libraries.
add :: proc(a: int, b: int) -> int {
	return a + b
}

// This function is private to this package and cannot be imported in another package.
@(private)
subtract_private :: proc(a: int, b: int) -> int {
	return a - b
}
