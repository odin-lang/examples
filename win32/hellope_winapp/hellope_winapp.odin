#+vet
package main

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:os"
import win32 "core:sys/windows"

L :: intrinsics.constant_utf16_cstring

TITLE :: "Hellope!"
WIDTH :: 320
HEIGHT :: WIDTH * 3 / 4
CENTER :: true

hbrGray: win32.HBRUSH

show_error_and_panic :: proc(msg: string, type: win32.UINT = win32.MB_ICONSTOP | win32.MB_OK, loc := #caller_location) {
	win32.MessageBoxW(nil, win32.utf8_to_wstring(msg), L("Panic"), type)
	fmt.panicf("%s (Last error: %x)", msg, win32.GetLastError(), loc = loc)
}

WM_CREATE :: proc(hwnd: win32.HWND, lparam: win32.LPARAM) -> win32.LRESULT {
	fmt.println(#procedure, hwnd)
	pcs := (^win32.CREATESTRUCTW)(rawptr(uintptr(lparam)))
	fmt.printfln("%#v", pcs)
	hbrGray = win32.HBRUSH(win32.GetStockObject(win32.DKGRAY_BRUSH))
	return 0
}

WM_DESTROY :: proc(hwnd: win32.HWND) -> win32.LRESULT {
	fmt.println(#procedure, hwnd)
	hbrGray = nil
	win32.PostQuitMessage(666) // exit code
	return 0
}

WM_ERASEBKGND :: proc(hwnd: win32.HWND, wparam: win32.WPARAM) -> win32.LRESULT {
	return 1 // paint should fill out the client area so no need to erase the background
}

WM_SIZE :: proc(hwnd: win32.HWND, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	size := [2]i32{win32.GET_X_LPARAM(lparam), win32.GET_Y_LPARAM(lparam)}
	fmt.println(#procedure, size, wparam)
	return 0
}

WM_PAINT :: proc(hwnd: win32.HWND) -> win32.LRESULT {
	ps: win32.PAINTSTRUCT
	win32.BeginPaint(hwnd, &ps)
	defer win32.EndPaint(hwnd, &ps)

	if hbrGray != nil {
		win32.FillRect(ps.hdc, &ps.rcPaint, hbrGray)
	}

	win32.DrawTextW(ps.hdc, L(TITLE), -1, &ps.rcPaint, .DT_SINGLELINE | .DT_CENTER | .DT_VCENTER)

	return 0
}

WM_CHAR :: proc(hwnd: win32.HWND, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	switch wparam {
	case '\x1b':
		win32.DestroyWindow(hwnd)
	case '\t':
		fmt.println("tab")
	case '\r':
		fmt.println("return")
	case 'm':
		win32.PlaySoundW(L("62a.wav"), nil, win32.SND_FILENAME)
	case 'p':
		show_error_and_panic("Don't worry it's just a test!")
	case:
		fmt.printfln("%s %4d 0x%4x 0x%4x 0x%4x", #procedure, wparam, wparam, win32.HIWORD(u32(lparam)), win32.LOWORD(u32(lparam)))
	}
	return 0
}

wndproc :: proc "system" (hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	context = runtime.default_context()
	switch msg {
	case win32.WM_CREATE:
		return WM_CREATE(hwnd, lparam)
	case win32.WM_DESTROY:
		return WM_DESTROY(hwnd)
	case win32.WM_ERASEBKGND:
		return WM_ERASEBKGND(hwnd, wparam)
	case win32.WM_SIZE:
		return WM_SIZE(hwnd, wparam, lparam)
	case win32.WM_PAINT:
		return WM_PAINT(hwnd)
	case win32.WM_CHAR:
		return WM_CHAR(hwnd, wparam, lparam)
	case:
		return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
	}
}

main :: proc() {

	instance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
	if (instance == nil) {show_error_and_panic("No instance")}

	icon := win32.LoadIconW(instance, win32.MAKEINTRESOURCEW(101))
	if icon == nil {icon = win32.LoadIconW(nil, win32.wstring(win32._IDI_APPLICATION))}
	if icon == nil {show_error_and_panic("Missing icon")}

	cursor := win32.LoadCursorW(nil, win32.wstring(win32._IDC_ARROW))
	if cursor == nil {show_error_and_panic("Missing cursor")}

	wcx := win32.WNDCLASSEXW {
		cbSize        = size_of(win32.WNDCLASSEXW),
		style         = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
		lpfnWndProc   = wndproc,
		cbClsExtra    = 0,
		cbWndExtra    = 0,
		hInstance     = instance,
		hIcon         = icon,
		hCursor       = cursor,
		hbrBackground = nil,
		lpszMenuName  = nil,
		lpszClassName = L("OdinMainClass"),
		hIconSm       = icon,
	}

	atom := win32.RegisterClassExW(&wcx)
	if atom == 0 {show_error_and_panic("Failed to register window class")}

	dwStyle :: win32.WS_OVERLAPPED | win32.WS_CAPTION | win32.WS_SYSMENU
	dwExStyle :: win32.WS_EX_OVERLAPPEDWINDOW

	size := [2]i32{WIDTH, HEIGHT}
	{
		// adjust size for style
		rect := win32.RECT{0, 0, size.x, size.y}
		if win32.AdjustWindowRectEx(&rect, dwStyle, false, dwExStyle) {
			size = {i32(rect.right - rect.left), i32(rect.bottom - rect.top)}
		}
	}

	position := [2]i32{i32(win32.CW_USEDEFAULT), i32(win32.CW_USEDEFAULT)}
	if CENTER {
		if deviceMode: win32.DEVMODEW; win32.EnumDisplaySettingsW(nil, win32.ENUM_CURRENT_SETTINGS, &deviceMode) {
			dm_size := [2]i32{i32(deviceMode.dmPelsWidth), i32(deviceMode.dmPelsHeight)}
			position = (dm_size - size) / 2
		}
	}

	hwnd := win32.CreateWindowExW(dwExStyle, win32.LPCWSTR(uintptr(atom)), L(TITLE), dwStyle, position.x, position.y, size.x, size.y, nil, nil, instance, nil)
	if hwnd == nil {show_error_and_panic("CreateWindowEx failed")}

	win32.ShowWindow(hwnd, win32.SW_SHOWDEFAULT)
	win32.UpdateWindow(hwnd)

	fmt.println("Main loop")

	msg: win32.MSG
	for win32.GetMessageW(&msg, nil, 0, 0) > 0 {
		win32.TranslateMessage(&msg)
		win32.DispatchMessageW(&msg)
	}

	fmt.println("Exit code", msg.wParam)
	assert(msg.wParam == 666)
	os.exit(int(msg.wParam))
}
