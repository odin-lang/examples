package main

import "core:fmt"
import "core:math/rand"

// Illustrating a simple first-order markov chain, and a few other ways to generate state transitions
// showcasing a handful of rand procedures in the process.

State :: enum { Banana, Apple, Pear, Lime, Blueberry }

Transition_Matrix := [State][State]f64{
	.Banana     = {.Banana = 0.30, .Apple = 0.25, .Pear = 0.25, .Lime = 0.10, .Blueberry = 0.10},
	.Apple      = {.Banana = 0.10, .Apple = 0.25, .Pear = 0.32, .Lime = 0.13, .Blueberry = 0.20},
	.Pear       = {.Banana = 0.40, .Apple = 0.15, .Pear = 0.25, .Lime = 0.10, .Blueberry = 0.10},
	.Lime       = {.Banana = 0.05, .Apple = 0.05, .Pear = 0.25, .Lime = 0.35, .Blueberry = 0.30},
	.Blueberry  = {.Banana = 0.20, .Apple = 0.25, .Pear = 0.25, .Lime = 0.10, .Blueberry = 0.10},
}

main :: proc() {
	cur_state, prev_state: State

	for i in 1..=10 {
		prev_state = cur_state
		cur_state = next_state(cur_state)
		fmt.printfln("Table state transition %v: %v -> %v", i, prev_state, cur_state)
	}

	for i in 1..=10 {
		prev_state = cur_state
		cur_state = next_state_equal()
		fmt.printfln("Equal weight state transition %v: %v -> %v", i, prev_state, cur_state)
	}

	for s, i in state_list(10) {
		prev_state = cur_state
		cur_state = s
		fmt.printfln("List state transition: %v: %v -> %v", i, prev_state, cur_state)
	}
}

// Using transition matrix
next_state :: proc(cur_state: State) -> State {
	chance := rand.float64()
	accumulate: f64

	for s in State {
		accumulate += Transition_Matrix[cur_state][s]
		
		if chance < accumulate {
			return s
		}
	}

	return cur_state
}

// Equal weighting
next_state_equal :: proc() -> State {
	return rand.choice_enum(State)
}

// A list of equally weighted transitions
state_list :: proc(size: int) -> []State {
	seq := make([]State, size)

	for i in 0..<size {
		seq[i] = State(rand.int_max(len(State)))
	}

	return seq
}