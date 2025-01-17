package game_of_life

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:os"
import win32 "core:sys/windows"
import "core:time"

// constants
TITLE :: "Game Of Life"
WORLD_SIZE :: [2]i32{128, 64}
ZOOM :: 12 // pixel size
FPS :: 20

BLACK :: [4]u8{0, 0, 0, 255}
WHITE :: [4]u8{255, 255, 255, 255}

HELP_TEXT :: `ESC - Quit
P - Toggle Pause
H - Toggle Help`
HELP_RECT :: win32.RECT{20, 20, 160, 100}
show_help := true

IDT_TIMER1: win32.UINT_PTR : 10001

COLOR_BITS :: 1
PALETTE_COUNT :: 1 << COLOR_BITS
Color_Palette :: [PALETTE_COUNT][4]u8

Bitmap_Info :: struct {
	bmiHeader: win32.BITMAPINFOHEADER,
	bmiColors: Color_Palette,
}

Screen_Buffer :: [^]u8

Config_Flag :: enum u32 {
	Center = 1,
}
Config_Flags :: distinct bit_set[Config_Flag;u32]

Window :: struct {
	name:          win32.wstring,
	size:          [2]i32,
	fps:           i32,
	control_flags: Config_Flags,
}

Game :: struct {
	tick_rate:         time.Duration,
	last_tick:         time.Time,
	pause:             bool,
	colors:            Color_Palette,
	size:              [2]i32,
	zoom:              i32,
	world, next_world: ^World,
	timer_id:          win32.UINT_PTR,
	tick:              u32,
	hbitmap:           win32.HBITMAP,
	pvBits:            Screen_Buffer,
	window:            Window,
}

game := Game{}

World :: struct {
	width:  i32,
	height: i32,
	alive:  []u8,
}

Cell :: struct {
	width:  f32,
	height: f32,
}

User_Input :: struct {
	left_mouse_clicked:   bool,
	right_mouse_clicked:  bool,
	toggle_pause:         bool,
	mouse_world_position: i32,
	mouse_tile_x:         i32,
	mouse_tile_y:         i32,
}

/*
 Game Of Life rules:
 * (1) A cell with 2 alive neighbors stays alive/dead
 * (2) A cell with 3 alive neighbors stays/becomes alive
 * (3) Otherwise: the cell dies/stays dead.

 reads from world, writes into next_world
*/
update_world :: #force_inline proc(world: ^World, next_world: ^World) {
	for x: i32 = 0; x < world.width; x += 1 {
		for y: i32 = 0; y < world.height; y += 1 {
			neighbors := count_neighbors(world, x, y)
			index := y * world.width + x

			switch neighbors {
			case 2: next_world.alive[index] = world.alive[index]
			case 3: next_world.alive[index] = 1
			case:   next_world.alive[index] = 0
			}
		}
	}
}

/*
 Just a branch-less version of adding adding all neighbors together
*/
count_neighbors :: #force_inline proc(w: ^World, x: i32, y: i32) -> u8 {
	// our world is a torus!
	left  := (x - 1) %% w.width
	right := (x + 1) %% w.width
	up    := (y - 1) %% w.height
	down  := (y + 1) %% w.height

	top_left     := w.alive[up   * w.width + left ]
	top          := w.alive[up   * w.width + x    ]
	top_right    := w.alive[up   * w.width + right]

	mid_left     := w.alive[y    * w.width + left ]
	mid_right    := w.alive[y    * w.width + right]

	bottom_left  := w.alive[down * w.width + left ]
	bottom       := w.alive[down * w.width + x    ]
	bottom_right := w.alive[down * w.width + right]

	top_row    := top_left    + top     + top_right
	mid_row    := mid_left              + mid_right
	bottom_row := bottom_left + bottom  + bottom_right

	total      := top_row     + mid_row + bottom_row
	return total
}

show_error_and_panic :: proc(msg: string, loc := #caller_location) {
	win32.MessageBoxW(nil, win32.utf8_to_wstring(fmt.tprintf("%s\nLast error: %x\n", msg, win32.GetLastError())), win32.utf8_to_wstring("Panic"), win32.MB_ICONSTOP | win32.MB_OK)
	panic(msg, loc = loc)
}

wndproc :: proc "system" (hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	context = runtime.default_context()

	switch msg {
	case win32.WM_CREATE: {	
		game.timer_id = win32.SetTimer(hwnd, IDT_TIMER1, 1000 / FPS, nil)
		if game.timer_id == 0 {show_error_and_panic("No timer")}
	
		hdc := win32.GetDC(hwnd)
		defer win32.ReleaseDC(hwnd, hdc)
	
		bitmap_info := Bitmap_Info {
			bmiHeader = win32.BITMAPINFOHEADER {
				biSize        = size_of(win32.BITMAPINFOHEADER),
				biWidth       = game.size.x,
				biHeight      = -game.size.y, // minus for top-down
				biPlanes      = 1,
				biBitCount    = 8,
				biCompression = win32.BI_RGB,
				biClrUsed     = len(game.colors),
			},
			bmiColors = game.colors,
		}
		game.hbitmap = win32.CreateDIBSection(hdc, cast(^win32.BITMAPINFO)&bitmap_info, win32.DIB_RGB_COLORS, &game.pvBits, nil, 0)
	
		if game.world != nil {
			cc := game.world.width * game.world.height
			for i in 0 ..< cc {game.world.alive[i] = u8(rand.int31_max(2))}
		}
		game.pause = false
		return 0
	}
	case win32.WM_DESTROY: {
		if game.timer_id != 0 {
			if !win32.KillTimer(hwnd, game.timer_id) {
				win32.MessageBoxW(nil, win32.utf8_to_wstring("Unable to kill timer"), win32.utf8_to_wstring("Error"), win32.MB_ICONSTOP | win32.MB_OK)
			}
			game.timer_id = 0
		}
		if game.hbitmap != nil {
			if !win32.DeleteObject(win32.HGDIOBJ(game.hbitmap)) {
				win32.MessageBoxW(nil, win32.utf8_to_wstring("Unable to delete hbitmap"), win32.utf8_to_wstring("Error"), win32.MB_ICONSTOP | win32.MB_OK)
			}
			game.hbitmap = nil
		}

		win32.PostQuitMessage(0)
		return 0
	}
	case win32.WM_PAINT: {
		ps: win32.PAINTSTRUCT
		hdc := win32.BeginPaint(hwnd, &ps)
		defer win32.EndPaint(hwnd, &ps)
	
		if game.hbitmap != nil {
			hdc_source := win32.CreateCompatibleDC(hdc)
			defer win32.DeleteDC(hdc_source)
	
			win32.SelectObject(hdc_source, win32.HGDIOBJ(game.hbitmap))
			client_size := [2]i32{(ps.rcPaint.right - ps.rcPaint.left), (ps.rcPaint.bottom - ps.rcPaint.top)}
			win32.StretchBlt(hdc, 0, 0, client_size.x, client_size.y, hdc_source, 0, 0, game.size.x, game.size.y, win32.SRCCOPY)
		}
	
		if show_help {
			rect := HELP_RECT
			win32.RoundRect(hdc, rect.left, rect.top, rect.right, rect.bottom, 20, 20)
			win32.InflateRect(&rect, -10, -10)
			win32.DrawTextW(hdc, win32.L(HELP_TEXT), -1, &rect, .DT_TOP)
		}
	
		return 0
	}
	case win32.WM_CHAR: {
		switch wparam {
		case '\x1b':
			win32.PostMessageW(hwnd, win32.WM_CLOSE, 0, 0)
		case 'h':
			show_help ~= true
		case 'p':
			game.pause ~= true
			if !game.pause {show_help = false}
		case 'r':
			cc := game.world.width * game.world.height
			for i in 0 ..< cc {game.world.alive[i] = u8(rand.int31_max(2))}
		case ' ':
			size := game.world.width * game.world.height
			idx := rand.int31_max(size)
			game.world.alive[idx] = 1
		case '£':
			show_error_and_panic("panic test")
		}
		return 0
	}
	case win32.WM_TIMER: {
		switch wparam {
		case IDT_TIMER1:
		if game.tick == 40 && show_help {show_help = false}
		
		if !game.pause {
			game.tick += 1
			update_world(game.world, game.next_world)
			game.world, game.next_world = game.next_world, game.world
		}
		
		cnt := int(game.world.width * game.world.height)
		runtime.mem_copy(game.pvBits, &game.world.alive[0], cnt)
		
		win32.SetWindowTextW(hwnd, win32.utf8_to_wstring(fmt.tprintf("%s - %d\n", game.window.name, game.tick)))
		win32.RedrawWindow(hwnd, nil, nil, .RDW_INVALIDATE | .RDW_UPDATENOW)
		case: fmt.printf("WM_TIMER %v %v %v\n", hwnd, wparam, lparam)
		}
		return 0
	}
	case win32.WM_ERASEBKGND: return 1 // paint should fill out the client area so no need to erase the background
	case: return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
	}
}

main :: proc() {
	game = Game {
		tick_rate = 300 * time.Millisecond,
		last_tick = time.now(),
		pause = true,
		colors = {BLACK, WHITE},
		size = WORLD_SIZE,
		zoom = ZOOM,
		window = Window{name = win32.L(TITLE), size = WORLD_SIZE * ZOOM, fps = FPS, control_flags = {.Center}},
	}

	for i in 0 ..< PALETTE_COUNT {
		c := u8((255 * int(i)) / (PALETTE_COUNT - 1))
		game.colors[i] = [4]u8{c, c, c, 255}
	}

	game.colors[0] = [4]u8{128, 64, 32, 255}
	game.colors[1] = [4]u8{255, 128, 64, 255}

	world := World{game.size.x, game.size.y, make([]u8, game.size.x * game.size.y)}
	next_world := World{game.size.x, game.size.y, make([]u8, game.size.x * game.size.y)}

	game.world = &world
	game.next_world = &next_world

	instance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
	if (instance == nil) {show_error_and_panic("No instance")}
	icon: win32.HICON = win32.LoadIconW(instance, win32.MAKEINTRESOURCEW(101))
	if icon == nil {icon = win32.LoadIconW(nil, win32.wstring(win32._IDI_APPLICATION))}
	if icon == nil {show_error_and_panic("Missing icon")}
	cursor := win32.LoadCursorW(nil, win32.wstring(win32._IDC_ARROW))
	if cursor == nil {show_error_and_panic("Missing cursor")}
	wcx := win32.WNDCLASSW {
		style         = win32.CS_HREDRAW | win32.CS_VREDRAW | win32.CS_OWNDC,
		lpfnWndProc   = wndproc,
		hInstance     = instance,
		hIcon         = icon,
		hCursor       = cursor,
		lpszClassName = win32.L("OdinMainClass"),
	}
	atom := win32.RegisterClassW(&wcx)

	if atom == 0 {show_error_and_panic("Failed to register window class")}

	style :: win32.WS_OVERLAPPED | win32.WS_CAPTION | win32.WS_SYSMENU
	size := game.window.size
	pos := [2]i32{i32(win32.CW_USEDEFAULT), i32(win32.CW_USEDEFAULT)}

	rect := win32.RECT{0, 0, size.x, size.y}
	if win32.AdjustWindowRect(&rect, style, false) {
		size = {i32(rect.right - rect.left), i32(rect.bottom - rect.top)}
	}

	if .Center in game.window.control_flags {
		if deviceMode: win32.DEVMODEW; win32.EnumDisplaySettingsW(nil, win32.ENUM_CURRENT_SETTINGS, &deviceMode) {
			device_size := [2]i32{i32(deviceMode.dmPelsWidth), i32(deviceMode.dmPelsHeight)}
			pos = (device_size - size) / 2
		}
	}
	hwnd := win32.CreateWindowW(win32.LPCWSTR(uintptr(atom)), game.window.name, style, pos.x, pos.y, size.x, size.y, nil, nil, instance, nil)

	if hwnd == nil {show_error_and_panic("Failed to create window")}
	win32.ShowWindow(hwnd, win32.SW_SHOWDEFAULT)
	win32.UpdateWindow(hwnd)

	msg: win32.MSG
	for win32.GetMessageW(&msg, nil, 0, 0) > 0 {
		win32.TranslateMessage(&msg)
		win32.DispatchMessageW(&msg)
	}

	if !win32.UnregisterClassW(win32.LPCWSTR(uintptr(atom)), instance) {show_error_and_panic("UnregisterClassW")}

	delete(world.alive)
	delete(next_world.alive)

	os.exit(int(msg.wParam))
}
