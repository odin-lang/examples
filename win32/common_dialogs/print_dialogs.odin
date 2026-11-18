package comdlg32_example

import fmt "core:fmt"
import win "core:sys/windows"

// ====================================================================================
// Print dialog

print :: proc(owner: win.HWND) {
	pd := win.PRINTDLGW {
		lStructSize = size_of(win.PRINTDLGW),
		hwndOwner = owner,
		Flags = win.PD_USEDEVMODECOPIESANDCOLLATE | win.PD_RETURNDC,
		nCopies = 1,
		nFromPage = 0xffff,
		nToPage = 0xffff,
		nMinPage = 1,
		nMaxPage = 0xffff,
	}
	defer if pd.hDevMode != nil { win.GlobalFree(pd.hDevMode) }
	defer if pd.hDevNames != nil { win.GlobalFree(pd.hDevNames) }
	defer if pd.hDC != nil { win.DeleteDC(pd.hDC) }
	success := win.PrintDlgW(&pd)
	if success {
		fmt.printfln("PrintDlgW confirmed.")
		// Do printing with `pd.hDC` here.
	} else {
		fmt.printfln("PrintDlgW canceled.")
	}
}

// ====================================================================================
// Print property sheet dialog

print_properties :: proc(owner: win.HWND) {
	page_ranges: [10]win.PRINTPAGERANGE
	pd := win.PRINTDLGEXW {
		lStructSize = size_of(win.PRINTDLGEXW),
		hwndOwner = owner,
		Flags = win.PD_COLLATE | win.PD_RETURNDC,
		nCopies = 1,
		nMinPage = 1,
		nMaxPage = 1000,
		nPageRanges = 0,
		lpPageRanges = raw_data(page_ranges[:]),
		nMaxPageRanges = len(page_ranges),
		nStartPage = win.START_PAGE_GENERAL,
	}
	defer if pd.hDevMode != nil { win.GlobalFree(pd.hDevMode) }
	defer if pd.hDevNames != nil { win.GlobalFree(pd.hDevNames) }
	defer if pd.hDC != nil { win.DeleteDC(pd.hDC) }
	hr := win.PrintDlgExW(&pd)
	if win.SUCCEEDED(hr) {
		fmt.printfln("PrintDlgExW succeeded.")
		if pd.dwResultAction == win.PD_RESULT_PRINT {
			// Do printing with `pd.hDC` here.
		}
	} else {
		fmt.printfln("PrintDlgExW failed: HRESULT = 0x%8x", hr)
	}
}

// ====================================================================================
// Page setup dialog

page_setup :: proc(owner: win.HWND) {
	psd := win.PAGESETUPDLGW {
		lStructSize = size_of(win.PAGESETUPDLGW),
		hwndOwner = owner,
		Flags = win.PSD_INTHOUSANDTHSOFINCHES | win.PSD_MARGINS | win.PSD_ENABLEPAGEPAINTHOOK,
		rtMargin = {
			left = 1250,
			top = 1000,
			right = 1250,
			bottom = 1000,
		},
		lpfnPagePaintHook = page_setup_paint_hook,
	}
	success := win.PageSetupDlgW(&psd)
	if success {
		fmt.printfln("PageSetupDlgW confirmed: PaperSize = %v; Margin = %v", psd.ptPaperSize, psd.rtMargin)
	} else {
		fmt.printfln("PageSetupDlgW canceled.")
	}
}

page_setup_paint_hook :: proc "system" (hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.UINT_PTR {
	switch msg {
	case win.WM_PSD_MARGINRECT:
		hdc := cast(win.HDC)wparam
		rc := cast(^win.RECT)cast(uintptr)lparam
		crMargRect := win.GetSysColor(win.COLOR_HIGHLIGHT)
		pen := win.CreatePen(win.PS_DASHDOT, 1, crMargRect)
		defer win.DeleteObject(auto_cast pen)
		previous_pen := win.SelectObject(hdc, auto_cast pen)
		win.Rectangle(hdc, rc.left, rc.top, rc.right, rc.bottom)
		if previous_pen != nil {
			win.SelectObject(hdc, previous_pen)
		}
		return cast(win.UINT_PTR)true
	case win.WM_PSD_FULLPAGERECT:
		hdc := cast(win.HDC)wparam
		rc := cast(^win.RECT)cast(uintptr)lparam
		brush := win.CreateSolidBrush(win.RGB(255, 0, 0))
		defer win.DeleteObject(auto_cast brush)
		win.FillRect(hdc, rc, brush)
		return cast(win.UINT_PTR)false
	case:
		return cast(win.UINT_PTR)false
	}
	return cast(win.UINT_PTR)true
}
