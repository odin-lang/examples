package basics

import "core:fmt"

// This package lets us generate random numbers.
import "core:math/rand"

// This is called from the `main` procedure. When it called it `21` was supplied
// as a procedure argument. That argument will be available within the procedure
// parameter with the name `n`.
//
// Note how `n: int` looks like a variable declaration!
//
// Also note something else: There is a `-> int` on the next line. This means
// that this procedure will return an integer number to the procedure that
// called it.
loops :: proc(n: int) -> int {
	fmt.println(n) // 21 because it says `loops(21)` in `1_main.odin`.

	// Let's make a loop that runs 5 times! You can do that in several ways.

	for i in 0..<5 {
		fmt.println(i) // 0, 1, 2, 3, 4
	}

	for i := 0; i < 5; i += 1 {
		fmt.println(i) // 0, 1, 2, 3, 4
	}

	// This loop lives inside some extra curly braces. That makes `i` not exist
	// outside those curly braces. Handy, so I don't get collisions with other
	// variables called `i` later in this procedure!
	{
		i := 0
		for i < 5 {
			fmt.println(i) // 0, 1, 2, 3, 4
			i += 1
		}
	}

	// Let's do something different. This uses the `core:math/rand` package.
	// `rand.int_max(10)` will result in a random value between `0` and `9` (10
	// is not included in the range).
	random_number := rand.int_max(10)

	fmt.printfln("Time to print %v numbers!", random_number)

	// This loop will run between 0 and 9 times!
	for i in 0..<random_number {
		fmt.println(i) // I have no idea what it will print!
	}

	// Note how all these loops use the word `for`. All loops in Odin use the
	// word `for`. There is no `while` or `foreach` keyword like in some
	// languages.

	// We can use the procedure parameter `n` to loop that many times.
	res := 0
	for i in 0..<n {
		fmt.println(i) // 0, 1, 2, ... , 19, 20

		res += i
	}

	// What's this res thing? This proc has a return value, so I thought I'd
	// better return something... So I summed all the numbers in the previous
	// loop.

	return res
}
