// Disable warnings for unused variables in this file.
#+vet !unused-variables

package variables

main :: proc() {
	// integer variable, zero-initialized
	n: int

	// Assign to existing variable
	n = 7

	// Note the `:=`. This both declares a variable and gives it a value. The
	// type is inferred from the right side. In this the type becomes `int`.
	n2 := 42

	// 32 bit floating point type, zero-initialized
	f: f32

	// Assign 7 to f32. 7 is a constant. Constants are allowed some implicit
	// conversions. 
	f = 7

	// Declare f32 variable and assign value 7 on single line. Needs type since
	// `7` would make the variable infer to type `int` otherwise.
	f2: f32 = 7

	// Same as previous, but infers type from right side.
	f3 := f32(7)

	// Declares an f64 variable, not f32! The default type inference for a
	// numeric constant with a period in the value is f64.
	f4 := 42.7

	// Same as above, but f5 and f6 are of type f32.
	f5 := f32(42.7)
	f6: f32 = 42.7

	// Read more:
	// https://odin-lang.org/docs/faq/#what-is-the-type-of-x-in-x--123
	// https://odinbook.com/sample.html#variables-and-constants
}