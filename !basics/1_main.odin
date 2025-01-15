// When you ran `odin run .`, then all the `.odin` files in this folder were
// compiled into a single package.

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
	//
	// You'll find `println` in `<odin>/core/fmt/fmt_os.odin`.
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

	// `loops` returned a value, we assigned that to `loops_result`. We can send
	// that value into the next procedure, which you'll find in (you guessed
	// it!) `4_if_statements.odin`:
	if_statements(loops_result)

	// Let's move on and read about what structs are! Continue in `5_structs.odin`
	cat := structs()

	// That procedure returned a whole struct of type `Cat`! We can print the
	// contents of it:
	fmt.println(cat) // Cat{name = "Klucke", age = 5}

	// We are nearing the end of this little tour of The Basics of Odin. Let's
	// finish with trying out pointers. Note how we write `&cat` when running
	// the `pointers` procedure. That fetches the memory address of `cat`. More
	// about that in `6_pointers.odin`!
	pointers(&cat)

	// `pointers` modified the age of `cat` from `5` to `11`. It did so by
	// writing to the age field through the pointer we sent into `pointers`.
	fmt.println(cat) // Cat{name = "Klucke", age = 11}

	// One note before we end: This example is split into a bunch of files, with
	// just a single procedure in each. Usually you'll have much bigger files
	// in Odin, where each file has lots of procedures, structs and all that.

	// That's it for this little tour! There is A LOT more to discover. Here
	// are three resources that you can check out:
	//
	// The overview (covers many language features):
	//     https://odin-lang.org/docs/overview/
	//
	// demo.odin (like a bigger and more advanced version of this example):
	//     https://github.com/odin-lang/Odin/blob/master/examples/demo/demo.odin
	// 
	// Understanding the Odin Programming Language (paid book with free sample):
	//     https://odinbook.com/
}