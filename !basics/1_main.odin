// This is the package name. All files in this folder is part of the same
// package. They must all have the same package name. The package name must be
// unique project-wide.
package basics

// This imports the `fmt` package from the core collection. You find the core
// collection in `<odin>/core`, where `<odin>` is the folder where you installed
// Odin. `fmt` is just a subfolder of `core`.
import "core:fmt"

// This is a procedure. A procedure contains code that can be executed. This
// procedure is special: By default, the program starts in the procedure called
// `main`.
main :: proc() {
	// The `fmt.println` procedure is part of the `core:fmt` package. It prints
	// text to the "standard output stream", which could mean:
	// - Terminal
	// - Command prompt
	// - Code editor output window
	//
	// You'll find `println` in `<odin>/core/fmt/fmt_os.odin`.
	fmt.println("Hellope!") // Prints "Hellope!" to the console

	// This runs another procedure called `variables`. But there is no such
	// procedure in this file! Where is it? All files within this folder are
	// part of the same package. So this procedure can be in any of the `.odin`
	// files in this folder. In this case it is in `2_variables.odin`. Open that
	// one to see what it does!
	variables()

	// When the `variables` procedure finishes running the program will continue
	// with the next line:

}