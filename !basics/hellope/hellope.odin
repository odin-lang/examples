// Package name must be same for all files in a directory and also unique
// project-wide.
package main 

// Import package fmt, contains procedures for printing to console and
// formatting strings.
import "core:fmt"

// You can give `fmt` an alias by instead writing
//     `import f "core:fmt"`

// Programs start in main procedure
main :: proc() {
	// Print to screen. `fmt` comes from `fmt` in "core:fmt".
	fmt.println("Hellope!")
}