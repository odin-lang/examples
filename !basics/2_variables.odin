// As you can see, this is the same package name as in `1_main.odin`. Which is
// required. Also: The filename `2_variables.odin` and `1_main.odin` are
// numbered like that only in order to make you look in `1_main.odin` first.
// The file names don't matter at all: By default, any file within a package can
// use anything from any other file within that package.
package basics

import "core:fmt"

// In this example we'll look at variables. Variables are like the name hints
// possible to vary. You can change their value and read their contents.
variables :: proc() {
	// This creates an integer variable. It's called `number`. It is of type
	// `int`, short for integer. It can only store whole numbers.
	//
	// We didn't supply any value, so it has the value `0` by default.
	number: int

	fmt.println(number) // 0

	// This gives `number` a new value. If there was no pre-existing variable
	// with the name `number`, then this would not compile.
	number = 7

	fmt.println(number) // 7

	// However, you can create variable and give it a value in one line! This
	// looks like `number: int`, but we tucked on `= 10` at the end.
	another_number: int = 10

	fmt.println(another_number) // 10

	// This line also creates a new variable. But it doesn't say which type it
	// should have. Instead, the compiler uses "type inference": It figures out
	// the type by looking at the value on the right side of `:=`. In this case
	// the type is inferred to `int`.
	yet_another_number := 42

	fmt.println(yet_another_number) // 42

	// Let's use another type: This variable has the type `f32`. That's short
	// for "floating point 32 bit". Such a type can store a number with both
	// a whole part and also a fractional part.
	//
	// Just like before, the default value is `0`.
	float_number: f32

	fmt.println(float_number) // 0

	// You can assign number with a period in them to variables of type `f32`.
	float_number = 7.2

	// This one might actually print something like `7.1999998`. Floating point
	// numbers have a limited precision, trying to print it that many decimals
	// will make that limit apparent.
	fmt.println(float_number) // 7.1999998

	// To limit the number of printed decimals, you can use `printfln` instead
	// of `println`. That procedure takes two parameters: The first one is known
	// as a format string. The thing `%.1f` says that we want to print a
	// floating point number with a single decimal.
	fmt.printfln("%.1f", float_number) // 7.2

	// Here we again create a new variable and try to infer the type. But the
	// inferred type will not be `f32`. It will be `f64`! The default inferred
	// type for when there is a decimal point in the right hand side is `f64`.
	another_float_number := 7.2

	// This prints the type of a variable! We can use it to verify that the type
	// of `another_float_number` is indeed f64
	fmt.println(typeid_of(type_of(another_float_number))) // f64

	// So if you want to declare an f32 and give it a value on a single line,
	// then you must say what type it should have. You can do this in two ways.
	//
	// 1) This creates a variable of type `f32` and assign `7.2` to it.
	i_want_a_f32: f32 = 123.4

	// 2) This creates a variable and infers the type from the right-hand-side.
	// `f32(7.2)` casts the value `7.2` to the type `f32`, which is then used
	// for the type inference.
	i_want_another_f32 := f32(2025.1)

	fmt.printfln("%.1f", i_want_a_f32)
	fmt.printfln("%.1f", i_want_another_f32)

	// Read more:
	// - All built-in basic types: https://odin-lang.org/docs/overview/#basic-types
	// - Chapter on variables and constants from Odin book sample: https://odinbook.com/sample.html#variables-and-constants

	// That's it for this procedure! It ends here, which means that the program
	// will continue with the next after `variables()` in `1_main.odin`.
}