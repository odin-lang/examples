package main

// port of https://miniaud.io/docs/examples/simple_playback_sine.html

import "core:c/libc"
import "core:fmt"
import ma "vendor:miniaudio"

data_callback :: proc "c" (device: ^ma.device, output: rawptr, input: rawptr, frameCount: u32) {
	assert_contextless(device.playback.channels == 2)

	sine := (^ma.waveform)(device.pUserData)
	assert_contextless(sine != nil)

	ma.waveform_read_pcm_frames(sine, output, u64(frameCount), nil)
}

main :: proc() {
	sine_config   : ma.waveform_config = ---
	device_config : ma.device_config   = ---
	sine          : ma.waveform        = ---
	device        : ma.device          = ---

	device_config                   = ma.device_config_init(.playback)
	device_config.playback.format   = .f32
	device_config.playback.channels = 2
	device_config.sampleRate        = 48000
	device_config.dataCallback      = data_callback
	device_config.pUserData         = &sine

	if ma.device_init(nil, &device_config, &device) != .SUCCESS {
		panic("Failed to open playback device")
	}
	fmt.printfln("Device Name: %s", device.playback.name)

	sine_config = ma.waveform_config_init(
        device.playback.playback_format,
        device.playback.channels,
        device.sampleRate,
        .sine,
        0.2,
        220,
	)

	if ma.waveform_init(&sine_config, &sine) != .SUCCESS {
		panic("Failed to init waveform")
	}

	if ma.device_start(&device) != .SUCCESS {
		ma.device_uninit(&device)
		panic("Failed to start playback device")
	}

	fmt.printfln("Press Enter to quit...")
	libc.getchar()

	ma.device_uninit(&device)
}
