// Basic window in the Windows API.
package winapi
import win "core:sys/windows"

hwnd: win.HWND
main :: proc()
{
	hInstance: win.HINSTANCE
	nCmdShow: win.c_int
	msg: win.MSG
	wc: win.WNDCLASSW = {}
	wc.style = win.CS_HREDRAW | win.CS_VREDRAW
	wc.hInstance = hInstance
	wc.lpfnWndProc = WndProc
	wc.lpszClassName = win.L("WinAPI example")
	win.RegisterClassW(&wc)
	hwnd = win.CreateWindowW(
		wc.lpszClassName,
		win.utf8_to_wstring("WinAPI Windows Example"),
		win.WS_OVERLAPPEDWINDOW | win.WS_VISIBLE,
		win.CW_USEDEFAULT,
		win.CW_USEDEFAULT,
		300,
		300,
		nil,
		nil,
		hInstance,
		nil,
	)

	
	for win.GetMessageW(&msg, nil, 0, 0) {
		win.DispatchMessageW(&msg)
		win.TranslateMessage(&msg)
	}
	win.ShowWindow(hwnd, nCmdShow)
	win.UpdateWindow(hwnd)
}

WndProc :: proc "system" (hwnd: win.HWND, msg: win.UINT, wParam: win.WPARAM, lParam: win.LPARAM) -> win.LRESULT
{
	switch msg {
		case win.WM_PAINT:
			ps: win.PAINTSTRUCT
			hdc := win.BeginPaint(hwnd, &ps)
			win.EndPaint(hwnd, &ps)
		case win.WM_DESTROY:
			win.PostQuitMessage(0)
	}
	return win.DefWindowProcW(hwnd, msg, wParam, lParam);
}