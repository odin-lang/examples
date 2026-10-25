package comdlg32_example

import win "core:sys/windows"

// Stores the persistent custom color palette of the color chooser dialog.
g_color_chooser_custom_colors := default_custom_colors()

default_custom_colors :: proc "contextless" () -> [16]win.COLORREF {
	c: [16]win.COLORREF
	for i in 0 ..< len(c) {
		c[i] = win.RGB(255, 255, 255)
	}
	return c
}

choose_color :: proc(
	owner:             win.HWND,
	initial_color:     win.COLORREF = 0x00ffffff,
) -> (
	dialog_confirmed:  bool,
	new_color:         win.COLORREF,
) {
	cc := win.CHOOSECOLORW {
		lStructSize = size_of(win.CHOOSECOLORW),
		hwndOwner = owner,
		hInstance = nil,
		rgbResult = initial_color,
		lpCustColors = raw_data(g_color_chooser_custom_colors[:]),
		Flags = win.CC_RGBINIT | win.CC_FULLOPEN,
	}

	confirmed := win.ChooseColorW(&cc)

	if confirmed {
		return true, cc.rgbResult
	} else {
		return false, 0
	}
}
