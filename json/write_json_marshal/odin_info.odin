/*
Demonstrates how you can turn a struct into JSON and then write that JSON out
to a file.
*/
package main

import "base:builtin"
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:os"

main :: proc() {
	fmt.println("Some of Odin's builtin constants")
	path := len(os.args) > 1 ? os.args[1] : "odin_info.json"

	// This uses an "anonymous struct type". You could equally well do
	//
	//     info := Odin_Info { ODIN_OS, ODIN_ARCH, ... }
	//
	// where you make a struct type `Odin_Info` that contains the same fields.
	info: struct {
		ODIN_OS:      runtime.Odin_OS_Type,
		ODIN_ARCH:    runtime.Odin_Arch_Type,
		ODIN_ENDIAN:  runtime.Odin_Endian_Type,
		ODIN_VENDOR:  string,
		ODIN_VERSION: string,
		ODIN_ROOT:    string,
		ODIN_DEBUG:   bool,
	} = {ODIN_OS, ODIN_ARCH, ODIN_ENDIAN, ODIN_VENDOR, ODIN_VERSION, ODIN_ROOT, ODIN_DEBUG}

	fmt.println("Odin:")
	fmt.printfln("%#v", info)

	json_data, err := json.marshal(info, {
		// Adds indentation etc
		pretty         = true,

		// Output enum member names instead of numeric value.
		use_enum_names = true,
	})

	if err != nil {
		fmt.eprintfln("Unable to marshal JSON: %v", err)
		os.exit(1)
	}

	fmt.println("JSON:")
	fmt.printfln("%s", json_data)
	fmt.printfln("Writing: %s", path)
	werr := os.write_entire_file_or_err(path, json_data)

	if werr != nil {
		fmt.eprintfln("Unable to write file: %v", werr)
		os.exit(1)
	}

	fmt.println("Done")
}
