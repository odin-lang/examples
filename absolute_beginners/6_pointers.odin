package basics

import "core:fmt"

// This procedure has a parameter that is of type `^Cat`. Read that as:
// "pointer to Cat". The `^Cat` type contains a memory address. We can go
// through that pointer in order to modify the memory that lives there.
pointers :: proc(cat: ^Cat) {
	// Printing a pointer shows the value at that memory address.
	fmt.println(cat) // &Cat{name = "Klucke", age = 5}

	// But we can also use the format string "%p" to directly print the memory
	// address it contains. This is not super-important, but interesting to see
	// that the pointer is just a number!
	fmt.printfln("%p", cat) // 0x52EF52F878

	// This will go through the pointer `cat` and modify the `age` field. The
	// procedure that called this procedure (main) will be able to see these
	// changes as well.
	cat.age = 11

	fmt.println(cat) // &Cat{name = "Klucke", age = 11}
}