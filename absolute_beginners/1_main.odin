// This example shows a few basic Odin features. It's targeted at people with
// very little programming experience.

// When you ran `odin run .`, then all the `.odin` files in this folder were
// compiled into a single package. That package was turned into an executable
// and then started.

// This is the package name. All files in a package must use the same package
// name. The package name must be unique project-wide (no other imported package
// may use the same name).
package basics

// This imports the `fmt` package from the core collection. You find the core
// collection in `<odin>/core`, where `<odin>` is the folder where you installed
// Odin. `fmt` is just a subfolder of `core`. Again, packages are just folders!
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
	fmt.println("Hellope!") // Prints "Hellope!" to the console

	// This runs another procedure called `variables`. But there is no such
	// procedure in this file! Where is it? All files within this folder are
	// part of the same package. So this procedure can be in any of the `.odin`
	// files in this folder. In this case it is in `2_variables.odin`. Open that
	// one to see what it does!
	variables()

	// When the `variables` procedure finishes running, then the program will
	// continue with the next line. This runs a procedure called `loops`. Note
	// that we feed the value `21` into it. You'll find `loops` in `3_loops.odin`.
	loops_result := loops(21)

	// `loops` returned a value. We've put that in a new variable called
	// `loops_result`. We can send that value into the next procedure:
	// `if_statements`. You'll find that procedure in (you guessed it!)
	// `4_if_statements.odin`.
	if_statements(loops_result)

	// Let's move on and read about what structs are! Continue in `5_structs.odin`
	cat := structs()

	// That procedure returned a whole struct of type `Cat`! We can print the
	// contents of it:
	fmt.println(cat) // Cat{name = "Klucke", age = 5}

	// We are nearing the end of this program. Let's finish with looking at what
	// pointers are. Note how we write `&cat` when running the `pointers`
	// procedure. That fetches the memory address of `cat` and sends it into the
	// `pointers` procedure. More about that in `6_pointers.odin`!
	pointers(&cat)

	// `pointers` modified the age of `cat` from `5` to `11`. It did so by
	// writing to the age field through the pointer we sent into `pointers`.
	fmt.println(cat) // Cat{name = "Klucke", age = 11}

	// One note before we end: This example is split into a bunch of files, with
	// just a single procedure in each. Usually you'll have much bigger files
	// in Odin, where each file has lots of procedures, structs and all that.

	// That's it for this example! There is A LOT more to discover. Have a look
	// at the resources available here: https://odin-lang.org/docs/
}