package main

// The build will fail without the required `main` function,
// though we won't use it at all in this example.
main :: proc() {}

// This is the function we'll use in the browser.
// Add the @export() attribute to ensure that the function is
// available in our WASM module.
@(export)
add_numbers :: proc(a: i32, b: i32) -> i32 {
	return a + b
}
