package open_win32_window

import win "core:sys/windows"
import fmt "core:fmt"
import os "core:os"

main :: proc() {
	// This isn't exactly equivalent to getting the hInstance argument passed to wWinMain in C,
	// but it's good enough for all intents and purposes.
	instance := win.HINSTANCE(win.GetModuleHandleW(nil))
	assert(instance != nil, "Failed to fetch current instance")
	// The 'hPrevInstance' parameter is always nil in modern Windows applications.

	// Equivalent code to getting the lpCmdLine argument passed to wWinMain in C
	lpCmdLine := win.GetCommandLineW()
	fmt.printfln("Command line used to start this application was: %v", lpCmdLine)

	// Equivalent code to getting the nCmdShow argument passed to wWinMain in C
	startup_info : win.STARTUPINFOW
	win.GetStartupInfoW(&startup_info)
	nCmdShow := (startup_info.dwFlags & win.STARTF_USESHOWWINDOW) != 0 ? cast(win.c_int)startup_info.wShowWindow : win.SW_SHOWDEFAULT

	CLASS_NAME :: "Windows Window"

	cls := win.WNDCLASSW {
		lpfnWndProc = win_proc,
		lpszClassName = CLASS_NAME,
		hInstance = instance,
		hCursor = win.LoadCursorA(nil, win.IDC_ARROW),
		hbrBackground = cast(win.HBRUSH)cast(uintptr)(win.COLOR_WINDOW + 1),
	}

	class := win.RegisterClassW(&cls)
	assert(class != 0, "Class creation failed")

	hwnd := win.CreateWindowW(CLASS_NAME,
		win.L("Windows Window"),
		win.WS_OVERLAPPEDWINDOW,
		win.CW_USEDEFAULT, 0, 1280, 720,
		nil, nil, instance, nil)

	assert(hwnd != nil, "Window creation Failed")

	win.ShowWindow(hwnd, nCmdShow)
	win.UpdateWindow(hwnd)

	msg: win.MSG

	for	win.GetMessageW(&msg, nil, 0, 0) > 0 {
		win.TranslateMessage(&msg)
		win.DispatchMessageW(&msg)
	}

	os.exit(cast(int)msg.wParam)
}

win_proc :: proc "stdcall" (hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	switch(msg) {
	case win.WM_DESTROY:
		win.PostQuitMessage(0)
	}

	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}