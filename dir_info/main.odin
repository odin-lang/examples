/*
How to get information about a directory, including which files and directories
it contains.
*/
package dir_info

import "core:fmt"
import "core:os"
import "core:path/filepath"

main :: proc() {
	cwd := os.get_current_directory()

	// Swap `cwd` for some other string to change which folder you're looking at
	f, err := os.open(cwd)

	defer os.close(f)

	if err != os.ERROR_NONE {
		fmt.eprintln("Could not open directory for reading", err)
		os.exit(1)
	}

	/*
	File_Info :: struct {
		fullpath: string, // allocated
		name:     string, // uses `fullpath` as underlying data
		size:     i64,
		mode:     File_Mode,
		is_dir:   bool,
		creation_time:     time.Time,
		modification_time: time.Time,
		access_time:       time.Time,
	}

	(from <odin>/core/os/stat.odin)
	*/
	fis: []os.File_Info

	/*
	This will deallocate `fis` at the end of this scope.

	It's not allocated yet, but `fis` is assigned a return value from
	`os.read_dir`. That's a	dynamically allocated slice.
	
	It doesn't matter that `fis` hasn't been assigned yet: `defer` will fetch
	the variable `fis` at the end of this scope. It does not fetch the value of
	that variable now.

	Note that each `File_Info` contains an allocated `fullpath` field. That's
	why this uses `os.file_info_slice_delete(fis)` instead of `delete(fis)`:
	It needs to go through the slice and deallocate those strings.
	*/
	defer os.file_info_slice_delete(fis)

	fis, err = os.read_dir(f, -1) // -1 reads all file infos
	if err != os.ERROR_NONE {
		fmt.eprintln("Could not read directory", err)
		os.exit(2)
	}

	fmt.printfln("Current working directory %v contains:", cwd)

	for fi in fis {
		_, name := filepath.split(fi.fullpath)

		if fi.is_dir {
			fmt.printfln("%v (directory)", name)
		} else {
			fmt.printfln("%v (%v bytes)", name, fi.size)
		}
	}
}
