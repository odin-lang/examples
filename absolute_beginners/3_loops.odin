package basics

import "core:fmt"

// This procedure has a parameter. Note the `(n: int)` just after `:: proc`.
//
// When `main` called this procedure it supplied the value `21` as a procedure
// argument. That argument will be available within the procedure parameter `n`.
//
// Note how `n: int` looks like a variable declaration! `n` is used near the end
// of the procdure.
//
// Also note something else: It says `-> int` on the next line. This means that
// this procedure will return an integer number back to the whoever ran it.
loops :: proc(n: int) -> int {
	fmt.println(n) // prints "21" because it says `loops(21)` in `1_main.odin`.

	// Let's make a loop that runs 5 times! You can do that in several ways.

	// This loops from 0 to 4 and for each lap of the loop the number is
	// availble in the loop variable `i`.
	for i in 0..<5 {
		fmt.println(i) // 0, 1, 2, 3, 4
	}

	// Same thing, but different kind of loop:
	for i := 0; i < 5; i += 1 {
		fmt.println(i) // 0, 1, 2, 3, 4
	}

	// This loop lives inside some extra curly braces. That makes `i` not exist
	// outside those curly braces. Handy, so I don't get collisions with other
	// variables called `i` later in this procedure!
	{
		// This looks like the previous loop, but I've moved out the `i := 0`
		// and I put the `i += 1` inside the loop. It has the same effect.
		i := 0
		for i < 5 {
			fmt.println(i) // 0, 1, 2, 3, 4
			i += 1
		}
	}

	// Note how all the loops above use the word `for`. All loops in Odin use
	// `for`. There is no `while` or `foreach` keyword like in some languages.

	// We can use the procedure parameter `n` to loop that many times.
	res := 0

	for i in 0..<n {
		fmt.println(i) // 0, 1, 2, ... , 19, 20
		res += i
	}

	// What's this `res` thing? This procedure has a return value, so I thought
	// I'd better return something... So I made `res` into a sum of all the
	// numbers in the previous loop.

	return res
}
