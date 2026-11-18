package comdlg32_example

// This file contains the main window, with a demo button for each of the common dialog examples.

import runtime "base:runtime"
import os "core:os"
import win "core:sys/windows"
import fmt "core:fmt"

main :: proc() {

	instance := cast(win.HINSTANCE)win.GetModuleHandleW(nil)

	wndclass := win.WNDCLASSW {
		lpfnWndProc = wndproc,
		hInstance = instance,
		hCursor = win.LoadCursorA(nil, win.IDC_ARROW),
		hbrBackground = cast(win.HBRUSH)cast(uintptr)(win.COLOR_3DFACE + 1),
		lpszClassName = "comdlg32_example",
	}

	win.RegisterClassW(&wndclass)
	
	hwnd := win.CreateWindowW(wndclass.lpszClassName, "Comdlg32 Example",
		win.WS_OVERLAPPEDWINDOW,
		win.CW_USEDEFAULT, 0, 800, 600,
		nil, nil, instance, nil)

	win.ShowWindow(hwnd, win.SW_SHOW)
	win.UpdateWindow(hwnd)

	msg: win.MSG
	for win.GetMessageW(&msg, nil, 0, 0) > 0 {
		if win.IsDialogMessageW(hwnd, &msg) {
			// This is a keyboard navigation message targeting the main window.
			continue
		}
		if g_current_find_replace_window != nil && win.IsDialogMessageW(g_current_find_replace_window, &msg) {
			// This is a keyboard navigation message targeting the find/replace window.
			continue
		}
		win.TranslateMessage(&msg)
		win.DispatchMessageW(&msg)
		free_all(context.temp_allocator)
	}

	os.exit(cast(int)msg.wParam)
}

IDC_CHOOSE_COLOR      :: 101
IDC_CHOOSE_FONT       :: 102
IDC_OPEN_FILE         :: 103
IDC_SAVE_FILE         :: 104
IDC_PRINT             :: 105
IDC_PRINT_PROPERTIES  :: 106
IDC_PAGE_SETUP        :: 107
IDC_FIND_TEXT         :: 108
IDC_REPLACE_TEXT      :: 109

@(private="file")
wndproc :: proc "system" (hwnd: win.HWND, msg: win.UINT, wparam: win.WPARAM, lparam: win.LPARAM) -> win.LRESULT {
	switch msg {

	case win.WM_CREATE:
		context = runtime.default_context()
		x :: 10
		y := i32(10)
		logfont := get_default_ui_logfont()
		font := win.CreateFontIndirectW(&logfont)

		create_button :: proc(parent: win.HWND, font: win.HFONT, x: i32, y: ^i32, id: i32, text: win.LPCWSTR) -> win.HWND {
			hwnd := win.CreateWindowW("BUTTON", text,
				win.WS_VISIBLE | win.WS_CHILD | win.WS_TABSTOP | win.BS_PUSHBUTTON,
				x, y^, 150, 25,
				parent, cast(win.HMENU)cast(uintptr)id, nil, nil)
			win.SendMessageW(hwnd, win.WM_SETFONT, cast(uintptr)font, 0)
			y^ += 30
			return hwnd
		}

		create_button(hwnd, font, x, &y, IDC_CHOOSE_COLOR, "Choose color...")
		create_button(hwnd, font, x, &y, IDC_CHOOSE_FONT, "Choose font...")
		create_button(hwnd, font, x, &y, IDC_OPEN_FILE, "Open file...")
		create_button(hwnd, font, x, &y, IDC_SAVE_FILE, "Save file...")
		create_button(hwnd, font, x, &y, IDC_PRINT, "Print...")
		create_button(hwnd, font, x, &y, IDC_PRINT_PROPERTIES, "Print properties...")
		create_button(hwnd, font, x, &y, IDC_PAGE_SETUP, "Page setup...")
		create_button(hwnd, font, x, &y, IDC_FIND_TEXT, "Find text...")
		create_button(hwnd, font, x, &y, IDC_REPLACE_TEXT, "Replace text...")

	case win.WM_DESTROY:
		win.PostQuitMessage(0)

	case win.WM_COMMAND:
		context = runtime.default_context()
		source := win.LOWORD(wparam)
		nc := win.HIWORD(wparam)

		switch source {

		case IDC_CHOOSE_COLOR:
			if nc == win.BN_CLICKED {
				dialog_confirmed, color := choose_color(hwnd)
				if dialog_confirmed {
					fmt.printfln("Choose color dialog confirmed: 0x%8x", color)
				} else {
					fmt.printfln("Choose color dialog canceled.")
				}
			}

		case IDC_CHOOSE_FONT:
			if nc == win.BN_CLICKED {
				dialog_confirmed, font, text_color := choose_font(hwnd)
				if dialog_confirmed {
					fmt.printfln("Choose font dialog confirmed: %v - text color: 0x%8x", font, text_color)
				} else {
					fmt.printfln("Choose font dialog canceled.")
				}
			}

		case IDC_OPEN_FILE:
			if nc == win.BN_CLICKED {
				dialog_confirmed, result := file_dialog(hwnd, .open, allocator = context.temp_allocator)
				if dialog_confirmed {
					display_title := get_file_display_name(result)
					fmt.printfln("Open file dialog confirmed: \"%v\" (Display name: \"%v\")", result, display_title)
				} else {
					fmt.printfln("Open file dialog canceled.")
				}
			}

		case IDC_SAVE_FILE:
			if nc == win.BN_CLICKED {
				filters := [?]File_Dialog_Filter {
					{ display_text = "Text files (*.txt)", filter = "*.txt" },
					{ display_text = "All files (*.*)", filter = "*.*" },
				}
				dialog_confirmed, result := file_dialog(hwnd, .save, filters = filters[:], allocator = context.temp_allocator)
				if dialog_confirmed {
					display_title := get_file_display_name(result)
					fmt.printfln("Save file dialog confirmed: \"%v\" (Display name: \"%v\")", result, display_title)
				} else {
					fmt.printfln("Save file dialog canceled.")
				}
			}

		case IDC_PRINT:
			if nc == win.BN_CLICKED {
				print(hwnd)
			}

		case IDC_PRINT_PROPERTIES:
			if nc == win.BN_CLICKED {
				print_properties(hwnd)
			}

		case IDC_PAGE_SETUP:
			if nc == win.BN_CLICKED {
				page_setup(hwnd)
			}

		case IDC_FIND_TEXT:
			if nc == win.BN_CLICKED {
				find_text(hwnd)
			}

		case IDC_REPLACE_TEXT:
			if nc == win.BN_CLICKED {
				replace_text(hwnd)
			}
		}

	case:
		// Find/Replace dialogs use a dynamic window message ID.
		if g_find_replace_msg != 0 && msg == g_find_replace_msg {
			context = runtime.default_context()
			handle_find_replace_message(hwnd, wparam, lparam)
			return 0
		}
	}

	return win.DefWindowProcW(hwnd, msg, wparam, lparam)
}
