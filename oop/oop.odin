// OOP in Odin
package test

import "core:fmt"

// VTable
Animal_Actions :: struct {
	noise:        proc() -> string,
	print_weight: proc(_: f32),
	what_am_i:    proc(_: Animal),
}

// Class / Trait / Embedded Struct
Animal_Info :: struct {
	using actions: ^Animal_Actions,
	weight:        f32,
	animal:        Animal,
}

Duck :: struct {
	using info: Animal_Info,
	species: string,
}

Dog :: struct {
	using info: Animal_Info,
	name: string,
}

Animal :: enum {
	None,
	Duck,
	Dog,
}

Trumpet :: struct {
	noise: proc() -> string,
	color: [4]u8,
}

default_actions :: proc() -> (action: ^Animal_Actions) {
	action = new(Animal_Actions)
	action.print_weight = print_weight
	action.what_am_i = what_am_i
	return
}

what_am_i :: proc(animal: Animal) {
	fmt.printf("I am a %v\n", animal)
}

print_weight :: proc(weight: f32) {
	fmt.printf("I weigh %.2f lbs\n", weight)
}

quack :: proc() -> string {
	return "QUACK"
}

bark :: proc() -> string {
	return "BARK"
}

doot :: proc() -> string {
	return "DOOT"
}

create_dog :: proc() -> (dog: ^Dog) {
	dog = new(Dog)
	dog.actions = default_actions()
	dog.noise = bark
	dog.animal = .Dog
	dog.weight = 30.0
	dog.name = "Doug"
	return
}

create_duck :: proc() -> (duck: ^Duck) {
	duck = new(Duck)
	duck.actions = default_actions()
	duck.noise = quack
	duck.animal = .Duck
	duck.weight = 5
	duck.species = "Mallard"
	return
}

create_trumpet :: proc() -> (trumpet: ^Trumpet) {
	trumpet = new(Trumpet)
	trumpet.noise = doot
	return
}

// Interface
make_noise :: proc(info: $T) {
	fmt.println(info.noise())
}

// Interface
destroy_animal :: proc(animal: $T) {
	free(animal.actions)
	free(animal)
}


main :: proc() {
	// dog, duck, and trumpet are pointers to their allocated position in memory
	dog := create_dog()
	duck := create_duck()
	trumpet := create_trumpet()

	// interfaces
	make_noise(dog)
	make_noise(duck)
	make_noise(trumpet)
	//make_noise(32) // does not compile and shows what member is missing

	// methods
	dog.what_am_i(dog.animal)
	dog.print_weight(dog.weight)
	duck.what_am_i(duck.animal)
	duck.print_weight(duck.weight)

	// clean up
	destroy_animal(dog)
	destroy_animal(duck)
	// make_noise(dog) // invalid memory access
	// make_noise(duck) // invalid memory access
}
