/*
This sets the working directory to the path of the executable.

This is useful for programs that need to load files that are located relative to
the executable. If you start a program from command line, like so:

	c:\a_program\a_program.exe

Then this code will make sure that the working directory is `c:\a_program`. This
example uses Windows paths, but this should work on unix-like operating systems
too.
*/

package working_directory

import "core:os"
import "core:path/slashpath"

main :: proc() {
	// os.args[0] always contains the full path to the current executable.
	exe_path := os.args[0]

	// Gets the directory, i.e. removes `a_program.exe` from `c:\a_program\a_program.exe`
	exe_dir := slashpath.dir(exe_path)

	os.set_current_directory(exe_dir)
}