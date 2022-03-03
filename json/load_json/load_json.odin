package load_json

import "core:fmt"
import "core:encoding/json"

import "core:os"

main :: proc() {
	// Load in your json file!
	data, ok := os.read_entire_file_from_filename("game_settings.json")
	if !ok {
		fmt.eprintln("Failed to load the file!")
		return
	}
	defer delete(data) // Free the memory at the end
	
	// Parse the json file.
	json_data, err := json.parse(data)
	if err != .None {
		fmt.eprintln("Failed to parse the json file.")
		fmt.eprintln("Error:", err)
		return
	}
	defer json.destroy_value(json_data)

	// Access the Root Level Object
	root := json_data.(json.Object)

	fmt.println("Root:")
	fmt.println(
		"window_width:",
		root["window_width"],
		"window_height:",
		root["window_height"],
		"window_title:",
		root["window_title"],
	)
	fmt.println("rendering_api:", root["rendering_api"])

	// Store the value.
	window_width := root["window_width"].(json.Float)
	fmt.println("window_width:", window_width)

	fmt.println("")

	fmt.println("Renderer Settings:")
	renderer_settings := root["renderer_settings"].(json.Object)
	fmt.println("msaa:", renderer_settings["msaa"])
	fmt.println("depth_testing:", renderer_settings["depth_testing"])
}
