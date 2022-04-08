package main

import "core:fmt"
import "core:math/rand"
import "core:os"
import "core:strconv"
import "core:strings"

// a buffer to hold the input
buff: [255]u8

// our input function that reads from stdin
input :: proc(msg: string) -> string {
    fmt.printf(msg)
    bytes, err := os.read(os.stdin, buff[:]) // read the stdin
    if err != 0 {
        fmt.println("Something went wrong!")
        os.exit(1)
    }
    // convert into a string and trim the trailing newline
    return strings.trim(string(buff[:bytes]), "\n")
}

main :: proc() {
    guess := input("Guess a number between 1 and 100: ")
    answer := int(rand.float64_range(1, 100))
    for {
        result, ok := strconv.parse_int(guess)
        if !ok {
            fmt.println("This is not a valid number!")
        } else if answer > result {
            fmt.println(result, "is too low!")
        } else if answer < result {
            fmt.println(result, "is too high!")
        } else {
            break
        }
        guess = input("Take another guess: ")
    }
    fmt.println("You guessed it! The right answer was:", answer)
}
