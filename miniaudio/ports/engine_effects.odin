package main

import "base:runtime"
import "core:fmt"
import "core:os"
import ma "vendor:miniaudio"

DELAY_IN_SECONDS :: 0.2
DECAY :: 0.25

main :: proc() {
	args := runtime.args__
	if len(args) < 2 {
		fmt.eprintfln("No input file.")
		os.exit(-1)
	}

	engine: ma.engine
	result := ma.engine_init(nil, &engine)
	if result != .SUCCESS {
		fmt.eprintfln("Failed to initialize audio engine.")
		os.exit(-2)
	}

	channels := ma.engine_get_channels(&engine)
	sample_rate := ma.engine_get_sample_rate(&engine)
	delay_in_frames := u32(f32(sample_rate) * DELAY_IN_SECONDS)
	delay_node_config := ma.delay_node_config_init(channels, sample_rate, delay_in_frames, DECAY)

	delay_node: ma.delay_node
	if ma.delay_node_init(ma.engine_get_node_graph(&engine), &delay_node_config, nil, &delay_node) != .SUCCESS {
		fmt.eprintfln("Failed to initialize delay node.")
		os.exit(-3)
	}

	if ma.node_attach_output_bus(cast(^ma.node)&delay_node, 0, ma.engine_get_endpoint(&engine), 0) != .SUCCESS {
		fmt.eprintfln("Failed to attach delay node to output bus.")
		os.exit(-4)
	}

	sound: ma.sound
	result = ma.sound_init_from_file(&engine, args[1], {}, nil, nil, &sound)
	if result != .SUCCESS {
		fmt.eprintfln("Failed to initialize sound \"%s\".", args[1])
		os.exit(-5)
	}

	if ma.node_attach_output_bus(cast(^ma.node)&sound, 0, cast(^ma.node)&delay_node, 0) != .SUCCESS {
		fmt.eprintfln("Failed to attach sound node to output bus.")
		os.exit(-6)
	}

	if ma.sound_start(&sound) != .SUCCESS {
		fmt.eprintfln("Failed to start sound.")
		os.exit(-7)
	}

	fmt.printfln("Press Enter to quit...")
	p: [1]byte
	os.read(os.stdin, p[:])

	ma.sound_uninit(&sound)
	ma.delay_node_uninit(&delay_node, nil)
	ma.engine_uninit(&engine)
}
