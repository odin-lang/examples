package main
// Solution of https://rosettacode.org/wiki/Musical_scale

import "core:time"
import "core:fmt"
import ma "vendor:miniaudio"

data_callback :: proc "c" (device: ^ma.device, output: rawptr, input: rawptr, frameCount: u32) {
	assert_contextless(device.playback.channels == 2)

	sine := (^ma.waveform)(device.pUserData)
	assert_contextless(sine != nil)

	ma.waveform_read_pcm_frames(sine, output, u64(frameCount), nil)
}

main :: proc() {
	NOTE      :: [8]f64    {261.63, 293.67, 329.63, 349.23, 392.00, 440.01, 493.89, 523.26}
	NOTE_NAME := [8]string {"C",    "D",    "E",    "F",    "G",    "A",    "B",    "C'"  }

	wave_config   : ma.waveform_config = ---
	device_config : ma.device_config   = ---
	wave          : ma.waveform        = ---
	device        : ma.device          = ---

	device_config              = ma.device_config_init(.playback)
	device_config.dataCallback = data_callback
	device_config.pUserData    = &wave

	if ma.device_init(nil, &device_config, &device) != .SUCCESS {
		panic("Failed to open playback device")
	}
	fmt.printfln("Device Name: %s", device.playback.name)

	for freq, i in NOTE {
		wave_config = ma.waveform_config_init(
			device.playback.playback_format,
			device.playback.channels,
			device.sampleRate,
			.triangle,
			0.2,
			freq,
		)

		if ma.waveform_init(&wave_config, &wave) != .SUCCESS {
			fmt.eprintln("Failed to init waveform")
			break
		}

		if ma.device_start(&device) != .SUCCESS {
			fmt.eprintln("Failed to start playback device")
			break
		} else {
			fmt.printfln("Playing %s", NOTE_NAME[i])
		}

		time.sleep(time.Second)

		if ma.device_stop(&device) != .SUCCESS {
			fmt.eprintln("Failed to stop playback device")
			break
		}
	}

	ma.device_uninit(&device)
}
