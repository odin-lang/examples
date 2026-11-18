package comdlg32_example

import win "core:sys/windows"

choose_font :: proc(
	owner:               win.HWND,
	initial_font:        Maybe(win.LOGFONTW) = nil,
	initial_text_color:  win.COLORREF = 0x00000000,
) -> (
	dialog_confirmed:    bool,
	new_font:            win.LOGFONTW,
	new_text_color:      win.COLORREF,
) {
	// If no initial font is provided, we query the standard system message font as
	// the initially selected font.
	font := initial_font.? if initial_font != nil else get_default_ui_logfont()

	cf := win.CHOOSEFONTW {
		lStructSize = size_of(win.CHOOSEFONTW),
		hwndOwner = owner,
		lpLogFont = &font,
		rgbColors = initial_text_color,
		Flags = win.CF_SCREENFONTS | win.CF_EFFECTS | win.CF_INITTOLOGFONTSTRUCT,
	}

	confirmed := win.ChooseFontW(&cf)

	if confirmed {
		return true, font, cf.rgbColors
	} else {
		return false, {}, 0
	}
}

get_default_ui_logfont :: proc() -> win.LOGFONTW {
	// NOTE: There are multiple valid definitions of what the "default UI font" can be.
	//       This implementation arbitrarily chooses the "NonClientMetrics MessageFont".
	ncm := win.NONCLIENTMETRICSW {
		cbSize = size_of(win.NONCLIENTMETRICSW),
	}
	win.SystemParametersInfoW(win.SPI_GETNONCLIENTMETRICS, 0, &ncm, 0)
	return ncm.lfMessageFont
}
