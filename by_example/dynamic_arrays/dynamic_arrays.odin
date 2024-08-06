package dynamic_arrays

import "core:fmt"
import "core:mem"

main :: proc() {
	// Create a dynamic array with a length of 5 and a capacity of 5.
	dyn := make([dynamic]int, 5, 5)
	// dyn = [0, 0, 0, 0, 0]

	// Free the dynamic array.
	defer delete(dyn)

	// Add elements to the dynamic array.
	append(&dyn, 1)
	append(&dyn, 2)
	// dyn = [0, 0, 0, 0, 0, 1, 2]

	// Remove the last element.
	last_element := pop(&dyn)
	fmt.println(last_element)

	// Remove the first element.
	first_element := pop_front(&dyn)
	fmt.println(first_element)
	// dyn = [0, 0, 0, 0, 1]

	// Add an array to the dynamic array.
	arr: [3]int = {1, 2, 3}
	append(&dyn, ..arr[:])

	// Remove what we just added.
	remove_range(&dyn, len(dyn) - len(arr), len(dyn))

	fmt.println(dyn)

	// Zero all the elements.
	mem.zero_slice(dyn[:])
	
	for _, i in dyn {
		dyn[i] = i + 1
	}

	// Maintain the order of the elements.
	ordered_remove(&dyn, 0)

	// Do not maintain the order. 
	// This is faster since ordered_remove has to copy, 
	// whereas this effectively swaps the last element 
	// with that of your choice and pops it.
	unordered_remove(&dyn, 0)

	// Copy the dynamic array into dyn_copy.
	dyn_copy := make([dynamic]int, len(dyn), cap(dyn))
	defer delete(dyn_copy)
	
	copy(dyn_copy[:], dyn[:])
	
	fmt.println("Elements:", dyn)
	fmt.println("Length:  ", len(dyn))
	fmt.println("Capacity:", cap(dyn))
}
