#+feature dynamic-literals
package maps

import "core:fmt"

/*
	Maps in Odin maps keys to value, and have a zero value of nil
	This data structure is called a hash map or dictionary in other languages
*/
main :: proc() {
	m := make(map[string]int)
	defer delete(m)

	m["Alice"] = 1
	m["Bob"] = 2

	fmt.println(m["Alice"])
	// 1
	fmt.println(m["Bob"])
	// 2

	// Check if a key exists for a map
	alice_exists := "Alice" in m

	if alice_exists {
		fmt.println("Hurray, Alice is included!")
	} else {
		fmt.println("Please be sure to include Alice to the party :(")
	}

	fmt.println("Length of map is", len(m))

	// Remove a value associated with a key
	deleted_key, deleted_value := delete_key(&m, "Alice")

	fmt.println("We have now removed key", deleted_key, "with value", deleted_value)
	// We have now removed key Alice with value 1

	// Or we can empty the whole map using clear 
	clear(&m)


	// We will now store actors in a map 
	Actor :: struct {
		age:    int,
		salary: int,
	}

	actors := make(map[string]Actor)
	defer delete(actors)

	// Insert actors into the map with their age and salary
	actors["Alice"] = {45, 140_000}
	actors["Bob"] = {36, 120_000}

	// Change the value of one actor
	value, ok := &actors["Alice"]
	if ok {
		// If the key exists, we can dereference the map to change the value for given key
		value^ = {36, 200_000}
	}

	// Iterating over a map
	for k, v in actors {
		fmt.println("Name:", k, "Age:", v.age, "Salary:", v.salary)
	}

	// To enable compound literals, '#feature dynamic-literals' must be added at the top of the file.
	m2 := map[string]int {
		"Bob"   = 10,
		"Chloe" = 20,
	}

	// Print a map for debugging purposes
	fmt.println(m2)
}
