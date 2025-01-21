package basics

import "core:fmt"

// This defines a new type that we can use in our code. A struct is essentially
// like a group of several variables. You can send a struct into a procedure and
// treat it like a single thing. That way you don't have to juggle a million
// variables. Handy!
Cat :: struct {
	// These are called the fields of the struct. The `name` field if of type
	// string, it can store text. Note how the fields look like variables, but
	// with a comma at the end.
	name: string,
	age: int,
}

// This procedure returns a whole struct!
structs :: proc() -> Cat {
	// This makes a new variable of type `Cat`. Since we don't provide a value,
	// it is zero-initialized. This means that the `name` and the `age` fields
	// are all zeroed.
	cat1: Cat

	// This prints the whole struct! Note how the age is zero and the name is
	// "" (empty string)
	fmt.println(cat1) // Cat{name = "", age = 0}

	// Let's give cat1 a name and an age:
	cat1.name = "Pontus"
	cat1.age = 7

	fmt.println(cat1) // Cat{name = "Pontus", age = 7}

	// Just like with other types, you can create and initialize a type on a 
	// single line:
	cat2 := Cat {
		name = "Klucke",
		age = 5,
	}

	fmt.println(cat2) // Cat{name = "Klucke", age = 5}

	// You can re-initialize a struct by assigning to it (note: We only use `=`,
	// not `:=`):

	cat1 = {
		name = "Tom",
		age = 23,
	}

	fmt.println(cat1) // Cat{name = "Tom", age = 23}

	// Let's return the whole `cat2` struct!
	return cat2
}