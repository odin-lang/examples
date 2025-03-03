/*
This example shows why one might prefer procedure parameters that are slices
whenever possible. Within `main` a dynamic array is created. The program uses
three different procedures to interact with the array. Two out of three
procedures take a slice parameter rather than a dynamic array parameter. There
are comments that motivate the choice of parameter type.

The code is from "Understanding the Odin Programming Language"
(https://odinbook.com/). It is used with permssion from the author.
*/

package prefer_to_pass_slices

import "core:fmt"
import "core:math/rand"

Cat :: struct {
	name: string,
	age: int,
}

/*
Note how `add_cat_of_random_age` is fed a pointer to the dynamic array.
`print_cats` and `mutate_cats` are fed a slice that looks at the whole dynamic
array. See those procedures to understand why.
*/
main :: proc() {
	all_the_cats: [dynamic]Cat
	add_cat_of_random_age(&all_the_cats, "Klucke")
	add_cat_of_random_age(&all_the_cats, "Pontus")

	print_cats(all_the_cats[:])
	mutate_cats(all_the_cats[:])
	print_cats(all_the_cats[:])

	/*
	Output of program (the numbers will be different on each run):

		Klucke is 8 years old
		Pontus is 13 years old
		Klucke is 10 years old
		Pontus is 2 years old
	*/
}

/*
This procedure makes changes to a dynamic array (appends items). So we must pass
a pointer to the dynamic array. After all, the only way to use `append` is if
you have something of type `^[dynamic]Element_Type`.
*/
add_cat_of_random_age :: proc(cats: ^[dynamic]Cat, name: string) {
	random_age := rand.int_max(12) + 2
	append(cats, Cat {
		name = name,
		age = random_age,	
	})
}

/*
This procedure loops over the parameter `cats: []Cat` and prints some info about
each element. Note how the slice operator `[:]` is used in `main`:

	print_cats(all_the_cats[:])

It feeds this procedure a slice that looks at the whole dynamic array.

Creating slices is very cheap. Here's what a slice looks like internally:

	// From `<odin>/base/runtime/core.odin`
	Raw_Slice :: struct {
		data: rawptr,
		len:  int,
	}

So when you do `print_cats(all_the_cats[:])`, then a slice is created with the
`data` field pointing to the first element of `all_the_cats` and `len` is set to
the length of the dynamic array.

This means that slicing is very cheap: There are no extra allocations.

Because this procedure uses a slice, we can also use it with any array type that
supports slicing. A fixed array would work fine:

	fixed_array_of_cats := [3]Cat { bla bla }
	print_cats(fixed_array_of_cats[:])

This makes the procedure more generally useful compared to if it accepted an
array of type `[dynamic]Cat`.
*/
print_cats :: proc(cats: []Cat) {
	for cat in cats {
		fmt.printfln("%v is %v years old", cat.name, cat.age)
	}
}

/*
This procedure loops over the parameter `cats: []Cat` and modifies each element.

This may surprise some people: The parameter type isn't `^[]Cat`. So how can it
modify the elements?

All procedure parameters in Odin are immutable, but it's just the fields of the
`Raw_Slice` that are immutable:

	Raw_Slice :: struct {
		data: rawptr,
		len:  int,
	}

We can't change what address `data` contains or the value of `len`. But the loop
in this procedure doesn't do any of that. It just goes to the memory that the
pointer `data` refers to and modifies the memory that lives at there, which is
allowed!

Passing a slice here makes this procedure more generally useful compared to if
it used a parameter of type `[dynamic]Cat`.

We could for example create a fixed array of 100 cats and give them all a
random age using this procedure:
	
	lots_of_cats: [100]Cat
	mutate_cats(lots_of_cats[:])
*/
mutate_cats :: proc(cats: []Cat) {
	for &cat in cats {
		cat.age = rand.int_max(12) + 2
	}
}
