/*
Demonstrate how you can create a json file
*/
package main

import "base:builtin"
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	fmt.println("Odin builtin constants")

	path: string = len(os.args) > 1 ? os.args[1] : "odin_info.json"

	builder := strings.builder_make()
	defer strings.builder_destroy(&builder)

	info: struct {
		ODIN_OS:      runtime.Odin_OS_Type,
		ODIN_ARCH:    runtime.Odin_Arch_Type,
		ODIN_ENDIAN:  runtime.Odin_Endian_Type,
		ODIN_VENDOR:  string,
		ODIN_VERSION: string,
		ODIN_ROOT:    string,
		ODIN_DEBUG:   bool,
	} = {ODIN_OS, ODIN_ARCH, ODIN_ENDIAN, ODIN_VENDOR, ODIN_VERSION, ODIN_ROOT, ODIN_DEBUG}

	fmt.println("Odin")
	fmt.printfln("%#v", info)

	fmt.println("Json")
	mo: json.Marshal_Options = {
		pretty         = true,
		use_enum_names = true,
	}
	err := json.marshal_to_builder(&builder, info, &mo)
	assert(err == json.Marshal_Data_Error.None)
	if len(builder.buf) != 0 {
		json_data := builder.buf[:]
		fmt.printfln("%s", json_data)
		fmt.printfln("Writing: %s", path)
		ok := os.write_entire_file(path, json_data)
		if !ok {fmt.eprintln("Unable to write file")}
	}

	fmt.println("Done.")
}
