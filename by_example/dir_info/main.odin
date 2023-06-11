package main 

import "core:fmt"
import "core:os"

main :: proc() {
    dir := os.get_current_directory()
    fmt.println("Current directory: ", dir)

    f: os.Handle
    err := os.ERROR_NONE
    f, err = os.open(dir)
    if err != os.ERROR_NONE {
        fmt.println("Could not open directory for reading", err)
    }
    defer os.close(f)

    fis: []os.File_Info
    fis, err = os.read_dir(f, -1) // -1 reads all file infos
    if err != os.ERROR_NONE {
        fmt.println("Could not read directory", err)
    }
    defer os.file_info_slice_delete(fis) // fis is a slice, we need to remember to free it

    for fi in fis {
        fmt.println("Found: ", fi.fullpath)
        fmt.println("Is directory? ", fi.is_dir)
        fmt.println("Size: ", fi.size)
        fmt.println()
    }
}
