package basics

import "core:fmt"
 
if_statements :: proc(some_number: int) {
	// An if statement runs some code only if a condition is true.
	//
	// The condition goes between the `if` and the `{`. If the condition is
	// `true` then the code between the curly braces runs.
	if true {
		fmt.println("This is always happens.")
	}

	// You can use `>` to check if a value is bigger than another value.
	if some_number > 10 {
		fmt.printfln("some_number is %v, which is bigger than 10!", some_number)
	}

	// Unless you changed something in the example, then `some_number` will be
	// `210`. So the following call to `println` will not run!
	if some_number > 300 {
		fmt.println("some_number is bigger than 300!")
	}

	// This `>` thing is called a comparison operator. Odin has a bunch of
	// comparison operators. All of them result in a value of type `bool`, short
	// for 'boolean'. A bool can only have the value true or false.
	//
	// There's a list of all comparison operators here:
	// https://odin-lang.org/docs/overview/#comparison-operators
	//
	// You can assign the result of the comparison operator to a variable. Note
	// how we don't write any type: It's inferred to being of type `bool`:
	a_condition := some_number < 500

	// This will print.
	if a_condition {
		fmt.println("some_number is less than 500")
	}

	// Use ! to invert a boolean. This will not print anything.
	if !a_condition {
		fmt.println("some_number is equal to 500, or larger")
	}
}