package fen_tool

import runtime "base:runtime"
import log "core:log"
import png "core:image/png"
import win "core:sys/windows"

system_error_message_default_language := win.MAKELANGID(win.LANG_NEUTRAL, win.SUBLANG_DEFAULT)

get_system_error_message :: proc(error_code: win.DWORD, language_id: win.DWORD = system_error_message_default_language, allocator := context.allocator) -> (result: string, error: runtime.Allocator_Error) #optional_allocator_error {
	// Let Windows allocate the buffer internally, because only it knows how big it needs to be.
	// It is temporary anyway because it will be converted to UTF-8.
	message_buffer: win.wstring
	rc := win.FormatMessageW(win.FORMAT_MESSAGE_FROM_SYSTEM | win.FORMAT_MESSAGE_IGNORE_INSERTS | win.FORMAT_MESSAGE_ALLOCATE_BUFFER,
                             nil, error_code, language_id, cast(win.LPWSTR)&message_buffer, 0, nil)
	if rc == 0 {
		// FormatMessageW failed. The most likely cause is that the caller gave us an invalid error code.
		// Could try to build a string containing the error code?
		return "", nil
	}

	defer win.LocalFree(cast(win.LPVOID)message_buffer)

	return win.wstring_to_utf8(message_buffer, N = -1, allocator = allocator)
}

get_dialog_item_text :: proc(hdlg: win.HWND, id: win.c_int, capacity: int, allocator := context.temp_allocator) -> (result: string, error: runtime.Allocator_Error) #optional_allocator_error {
	buf := make([]win.WCHAR, capacity, allocator)
	if win.GetDlgItemTextW(hdlg, id, auto_cast raw_data(buf), auto_cast len(buf)) <= 0 {
		return "", nil
	}
	return win.wstring_to_utf8(cast(win.wstring)raw_data(buf), N = -1, allocator = allocator)
}

set_dialog_item_text_string :: proc(hdlg: win.HWND, id: win.c_int, text: string) -> bool {
	wstr := win.utf8_to_wstring(text, context.temp_allocator)
	return cast(bool)win.SetDlgItemTextW(hdlg, id, wstr)
}

set_dialog_item_text_cstring16 :: proc(hdlg: win.HWND, id: win.c_int, text: cstring16) -> bool {
	return cast(bool)win.SetDlgItemTextW(hdlg, id, text)
}

set_dialog_item_text :: proc { set_dialog_item_text_string, set_dialog_item_text_cstring16 }

set_menu_item_text :: proc(hMenu: win.HMENU, itemID: win.UINT, text: string) {
	wstr := win.utf8_to_wstring_alloc(text, context.temp_allocator)
	if wstr == nil {
		return
	}
	mii := win.MENUITEMINFOW {
		cbSize = size_of(win.MENUITEMINFOW),
		fMask = win.MIIM_STRING,
		dwTypeData = cast(win.LPWSTR)wstr,
	}
	win.SetMenuItemInfoW(hMenu, itemID, false, &mii)
}

// This procedure is "needed" because painting a rectangle with gid32's `Rectangle` API function
// is inherently inaccurate if the pen thickness is not equal to 1.
//
// A positive thickness will paint an inset rectangle (rect defines its outer border), a negative
// thickness will paint an outset rectangle (rect defines its inner border).
stroke_rectangle_precise :: proc(hdc: win.HDC, rc: win.RECT, color: win.COLORREF, #any_int thickness: i32 = 1) -> bool {
	if thickness == 0 {
		return true
	}

	thickness := thickness
	rc := rc
	if thickness < 0 {
		// Outset rectangle. We do this by inflating `rc` by the thickness, then
		// paint an inset rectangle.
		thickness *= -1
		rc.left -= thickness
		rc.top -= thickness
		rc.right += thickness
		rc.bottom += thickness
	}

	brush := win.CreateSolidBrush(color)
	if brush == nil {
		return false
	}
	defer win.DeleteObject(auto_cast brush)

	part: win.RECT

	// Top
	part.left = rc.left
	part.top = rc.top
	part.right = rc.right
	part.bottom = min(rc.bottom, rc.top + thickness)
	win.FillRect(hdc, &part, brush)

	// Left
	part.right = min(rc.right, rc.left + thickness)
	part.bottom = rc.bottom
	win.FillRect(hdc, &part, brush)

	// Bottom
	part.top = max(rc.top, rc.bottom - thickness)
	part.right = rc.right
	win.FillRect(hdc, &part, brush)

	// Right
	part.left = max(rc.left, rc.right - thickness)
	part.top = rc.top
	win.FillRect(hdc, &part, brush)

	return true
}

load_string_resource :: proc(hInstance: win.HINSTANCE, id: win.UINT, allocator := context.temp_allocator) -> (result: string, error: runtime.Allocator_Error) #optional_allocator_error {
	buffer: win.LPWSTR
	// This particular usage (cchBufferMax = 0) makes it so that we receive a read-only
	// pointer to the string resource. We then have to copy it out.
	string_length := win.LoadStringW(hInstance, id, cast(win.LPWSTR)&buffer, 0)
	if string_length <= 0 || buffer == nil {
		return "", nil
	}
	return win.utf16_to_utf8((cast([^]win.WCHAR)buffer)[:string_length], allocator = allocator)
}

// Loads a PNG image stored as an `RCDATA` type resource, and converts it into a GDI compatible `HBITMAP`.
load_hbitmap_from_png_rcdata :: proc {
	load_hbitmap_from_png_rcdata_int,
	load_hbitmap_from_png_rcdata_wstr,
	load_hbitmap_from_png_rcdata_hrsrc,
}

load_hbitmap_from_png_rcdata_int :: proc(hModule: win.HMODULE, resource_id: int) -> win.HBITMAP {
	rt_rcdata := win.RT_RCDATA
	resource_info := win.FindResourceW(hModule, cast(win.LPCWSTR)cast(rawptr)cast(uintptr)resource_id, cast(win.LPCWSTR)rt_rcdata)
	if resource_info == nil {
		log.errorf("Could not find resource: %v", resource_id)
		return nil
	}
	return load_hbitmap_from_png_rcdata(hModule, resource_info)
}

load_hbitmap_from_png_rcdata_wstr :: proc(hModule: win.HMODULE, resource_id: win.wstring) -> win.HBITMAP {
	rt_rcdata := win.RT_RCDATA
	resource_info := win.FindResourceW(hModule, resource_id, cast(win.LPCWSTR)rt_rcdata)
	if resource_info == nil {
		log.errorf("Could not find resource: %v", resource_id)
		return nil
	}
	return load_hbitmap_from_png_rcdata(hModule, resource_info)
}

load_hbitmap_from_png_rcdata_hrsrc :: proc(hModule: win.HMODULE, resource_info: win.HRSRC) -> win.HBITMAP {
	resource_size := win.SizeofResource(hModule, resource_info)
	if resource_size == 0 {
		error := win.GetLastError()
		log.errorf("Could not load resource: %v", get_system_error_message(error))
		return nil
	}
	hresource := win.LoadResource(hModule, resource_info)
	if hresource == nil {
		error := win.GetLastError()
		log.errorf("Could not load resource: %v", get_system_error_message(error))
		return nil
	}
	defer win.FreeResource(hresource)
	data := (cast([^]byte)win.LockResource(hresource))[:resource_size]
	img, err := png.load_from_bytes(data, allocator = context.temp_allocator)
	if err != nil {
		log.errorf("png.load_from_bytes failed: %v", err)
		return nil
	}
	// Declare a specialized `BITMAPINFO` variant with no color table entries.
	BITMAPINFO :: struct {
		hdr: win.BITMAPINFOHEADER,
	}
	bmi := BITMAPINFO {
		hdr = {
			biSize = size_of(win.BITMAPV5HEADER),
			biWidth = cast(win.LONG)img.width,
			biHeight = cast(win.LONG)-img.height,
			biPlanes = 1,
			biBitCount = 32,
			biCompression = win.BI_RGB,
		},
	}
	pixels: [^]win.RGBQUAD
	dib := win.CreateDIBSection(nil, cast(^win.BITMAPINFO)&bmi, win.DIB_RGB_COLORS, cast(^rawptr)&pixels, nil, 0)
	if dib == nil {
		error := win.GetLastError()
		log.errorf("CreateDIBSection failed: %v", get_system_error_message(error))
		return nil
	}
	// We need to convert the pixel format that `png` gives us from RGBA to BGRA.
	num_pixels := img.width * img.height // NOTE: This only works because `stride == width` here.
	src := cast([^][4]win.BYTE)raw_data(img.pixels.buf)
	for i in 0 ..< num_pixels {
		pixels[i] = win.RGBQUAD {
			rgbBlue      = src[i].b,
			rgbGreen     = src[i].g,
			rgbRed       = src[i].r,
			rgbReserved  = src[i].a,
		}
	}
	return dib
}

fudge_window_starting_position :: proc(hwnd: win.HWND) {
	// Create an invisible dummy window to make the operating system generate a valid starting position
	rc: win.RECT
	if !win.GetWindowRect(hwnd, &rc) {
		return
	}
	w := rc.right - rc.left
	h := rc.bottom - rc.top
	dummy := win.CreateWindowW("STATIC", "", win.WS_OVERLAPPEDWINDOW, win.CW_USEDEFAULT, 0, w, h, nil, nil, nil, nil)
	if dummy == nil {
		return
	}
	defer win.DestroyWindow(dummy)
	dummy_rc: win.RECT
	if !win.GetWindowRect(dummy, &dummy_rc) {
		return
	}
	x := dummy_rc.left
	y := dummy_rc.top
	win.SetWindowPos(hwnd, nil, x, y, 0, 0, win.SWP_NOZORDER | win.SWP_NOSIZE)
}
