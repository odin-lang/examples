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
	fmt.println(m["Bob"])

	// We can check if a key exists for a map as well
	alice_exists := "Alice" in m

	if alice_exists {
		fmt.println("Hurray, Alice is included!")
	} else {
		fmt.println("Please be sure to include Alice to the party :(")
	}

	fmt.println("Length of map is", len(m))

	// We can remove a key like such 
	deleted_key, deleted_value := delete_key(&m, "Alice")

	fmt.println("We have now removed key", deleted_key, "with value", deleted_value)

	// Or we can empty the whole map using clear 
	clear(&m)


	// We will now store actors in a map 
	Actor :: struct {
		age:    int,
		salary: int,
	}

	actors := make(map[string]Actor)
	defer delete(actors)

	// We insert to actors into our maps, with their respective age and salary
	actors["Alice"] = {45, 140_000}
	actors["Bob"] = {36, 120_000}

	// We can change the value of one of our actors like such
	value, ok := &actors["Alice"]
	if ok {
		// If the key exists, we can dereference the map to change the value for given key
		value^ = {36, 200_000}
	}

	// We can iterate over the map like such
	for k, v in actors {
		fmt.println("Name:", k, "Age:", v.age, "Salary:", v.salary)
	}

	// To enable compoud literals, #+feature dynamic-literals must be enbabled 
	m2 := map[string]int {
		"Bob"   = 10,
		"Chloe" = 20,
	}

	// We can also directly print a map for debugging purposes
	fmt.println(m2)
}
