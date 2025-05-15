package game_of_life

/*********************************************************************
                            GAME  OF  LIFE
                            (using win32)

This example shows a simple setup of Game of Life using Win32. It uses
Software Rendering. This is done by drawing the game cells into a
texture.

Controls:
ESC - Quit
P   - Toggle Pause
R   - Restart
H   - Toggle Help

Build with:

odin build . -resource:game_of_life.rc

If you get errors during build about missing `winres.h`, either:
- Remove the `-resource:game_of_life.rc` flag
- Launch a "x64 Native Tools Command Prompt" and build from that
  command prompt.

**********************************************************************/

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:os"
import win32 "core:sys/windows"
import "core:time"

// aliases
L :: intrinsics.constant_utf16_cstring
Color :: [4]u8
Int2 :: [2]i32

// constants
TITLE :: "Game of Life"
WORLD_SIZE :: Int2 {128, 64}
ZOOM :: 12 // pixel size
FPS :: 20

BLACK :: Color{0, 0, 0, 255}
WHITE :: Color{255, 255, 255, 255}

HELP_TEXT :: `ESC - Quit
P - Toggle Pause
R - Restart
H - Toggle Help`
HELP_RECT :: win32.RECT {20, 20, 160, 105}
show_help := true

// The timer used for ticking the game.
IDT_TIMER1 :: 10001

COLOR_BITS :: 1
PALETTE_COUNT :: 1 << COLOR_BITS
Color_Palette :: [PALETTE_COUNT]Color

Bitmap_Info :: struct {
	bmiHeader: win32.BITMAPINFOHEADER,
	bmiColors: Color_Palette,
}

Screen_Buffer :: [^]u8

Config_Flag :: enum u32 {
	CENTER = 1,
}
Config_Flags :: distinct bit_set[Config_Flag;u32]

Window :: struct {
	name:          win32.wstring,
	size:          Int2,
	fps:           i32,
	control_flags: Config_Flags,
}

Game :: struct {
	tick_rate:         time.Duration,
	last_tick:         time.Time,
	pause:             bool,
	colors:            Color_Palette,
	size:              Int2,
	zoom:              i32,
	world, next_world: ^World,
	timer_id:          win32.UINT_PTR,
	tick:              u32,
	hbitmap:           win32.HBITMAP,
	pvBits:            Screen_Buffer,
	window:            Window,
}

World :: struct {
	width:  i32,
	height: i32,
	alive:  []u8,
}

Cell :: struct {
	width:  f32,
	height: f32,
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

/*
 draws all the tiles of world.
*/
draw_world :: #force_inline proc(app: ^Game) {
	cnt := int(app.world.width * app.world.height)
	runtime.mem_copy(app.pvBits, &app.world.alive[0], cnt)
}

message_box :: #force_inline proc(text, caption: string, loc := #caller_location) {
	win32.MessageBoxW(nil, win32.utf8_to_wstring(text), win32.utf8_to_wstring(caption), win32.MB_ICONSTOP | win32.MB_OK)
}

show_error_and_panic :: proc(msg: string, loc := #caller_location) {
	message_box(fmt.tprintf("%s\nLast error: %x\n", msg, win32.GetLastError()), "Panic")
	panic(msg, loc = loc)
}

get_rect_size :: #force_inline proc(rect: ^win32.RECT) -> Int2 {return {(rect.right - rect.left), (rect.bottom - rect.top)}}

set_app :: #force_inline proc(hwnd: win32.HWND, app: ^Game) {win32.SetWindowLongPtrW(hwnd, win32.GWLP_USERDATA, win32.LONG_PTR(uintptr(app)))}

get_app :: #force_inline proc(hwnd: win32.HWND) -> ^Game {return (^Game)(rawptr(uintptr(win32.GetWindowLongPtrW(hwnd, win32.GWLP_USERDATA))))}

randomize_world :: proc(world: ^World) {
	cc := world.width * world.height
	for i in 0 ..< cc {world.alive[i] = u8(rand.int31_max(2))}
}

WM_CREATE :: proc(hwnd: win32.HWND, lparam: win32.LPARAM) -> win32.LRESULT {
	pcs := (^win32.CREATESTRUCTW)(rawptr(uintptr(lparam)))
	if pcs == nil {show_error_and_panic("lparam is nil")}
	app := (^Game)(pcs.lpCreateParams)
	if app == nil {show_error_and_panic("lpCreateParams is nil")}
	set_app(hwnd, app)

	app.timer_id = win32.SetTimer(hwnd, IDT_TIMER1, 1000 / FPS, nil)
	if app.timer_id == 0 {show_error_and_panic("No timer")}

	hdc := win32.GetDC(hwnd)
	defer win32.ReleaseDC(hwnd, hdc)

	bitmap_info := Bitmap_Info {
		bmiHeader = win32.BITMAPINFOHEADER {
			biSize        = size_of(win32.BITMAPINFOHEADER),
			biWidth       = app.size.x,
			biHeight      = -app.size.y, // minus for top-down
			biPlanes      = 1,
			biBitCount    = 8,
			biCompression = win32.BI_RGB,
			biClrUsed     = len(app.colors),
		},
		bmiColors = app.colors,
	}
	app.hbitmap = win32.CreateDIBSection(hdc, cast(^win32.BITMAPINFO)&bitmap_info, win32.DIB_RGB_COLORS, (^^rawptr)(&app.pvBits), nil, 0)

	if app.world != nil {
		randomize_world(app.world)
	}
	app.pause = false

	return 0
}

WM_DESTROY :: proc(hwnd: win32.HWND) -> win32.LRESULT {
	app := get_app(hwnd)
	if app == nil {show_error_and_panic("Missing app!")}
	if app.timer_id != 0 {
		if !win32.KillTimer(hwnd, app.timer_id) {
			message_box("Unable to kill timer", "Error")
		}
		app.timer_id = 0
	}
	if app.hbitmap != nil {
		if !win32.DeleteObject(win32.HGDIOBJ(app.hbitmap)) {
			message_box("Unable to delete hbitmap", "Error")
		}
		app.hbitmap = nil
	}
	exit_code :: 0
	win32.PostQuitMessage(exit_code)
	return 0
}

WM_PAINT :: proc(hwnd: win32.HWND) -> win32.LRESULT {
	app := get_app(hwnd)
	if app == nil {return 0}

	ps: win32.PAINTSTRUCT
	hdc := win32.BeginPaint(hwnd, &ps)
	defer win32.EndPaint(hwnd, &ps)

	if app.hbitmap != nil {
		hdc_source := win32.CreateCompatibleDC(hdc)
		defer win32.DeleteDC(hdc_source)

		win32.SelectObject(hdc_source, win32.HGDIOBJ(app.hbitmap))
		client_size := get_rect_size(&ps.rcPaint)
		win32.StretchBlt(hdc, 0, 0, client_size.x, client_size.y, hdc_source, 0, 0, app.size.x, app.size.y, win32.SRCCOPY)
	}

	if show_help {
		rect := HELP_RECT
		win32.RoundRect(hdc, rect.left, rect.top, rect.right, rect.bottom, 20, 20)
		win32.InflateRect(&rect, -10, -10)
		win32.DrawTextW(hdc, L(HELP_TEXT), -1, &rect, .DT_TOP)
	}

	return 0
}

WM_TIMER :: proc(hwnd: win32.HWND, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	switch wparam {
	case IDT_TIMER1:
		app := get_app(hwnd)
		if app != nil {

			if app.tick == 40 && show_help {show_help = false}

			if !app.pause {
				app.tick += 1
				update_world(app.world, app.next_world)
				app.world, app.next_world = app.next_world, app.world
			}

			draw_world(app)

			win32.SetWindowTextW(hwnd, win32.utf8_to_wstring(fmt.tprintf("%s - %d\n", app.window.name, app.tick)))
			win32.RedrawWindow(hwnd, nil, nil, .RDW_INVALIDATE | .RDW_UPDATENOW)
		}
	case:
		fmt.printf("WM_TIMER %v %v %v\n", hwnd, wparam, lparam)
	}
	return 0
}

WM_CHAR :: proc(hwnd: win32.HWND, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	switch wparam {
	case '\x1b':
		win32.PostMessageW(hwnd, win32.WM_CLOSE, 0, 0)
	case 'h':
		show_help ~= true
	case 'p':
		app := get_app(hwnd)
		app.pause ~= true
		if !app.pause {show_help = false}
	case 'r':
		app := get_app(hwnd)
		randomize_world(app.world)
	case ' ':
		app := get_app(hwnd)
		siz := app.world.width * app.world.height
		idx := rand.int31_max(siz)
		app.world.alive[idx] = 1
	}
	return 0
}

wndproc :: proc "system" (hwnd: win32.HWND, msg: win32.UINT, wparam: win32.WPARAM, lparam: win32.LPARAM) -> win32.LRESULT {
	context = runtime.default_context()
	switch msg {
	case win32.WM_CREATE:     return WM_CREATE(hwnd, lparam)
	case win32.WM_DESTROY:    return WM_DESTROY(hwnd)
	case win32.WM_ERASEBKGND: return 1 // paint should fill out the client area so no need to erase the background
	case win32.WM_PAINT:      return WM_PAINT(hwnd)
	case win32.WM_CHAR:       return WM_CHAR(hwnd, wparam, lparam)
	case win32.WM_TIMER:      return WM_TIMER(hwnd, wparam, lparam)
	case:                     return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
	}
}

register_class :: proc(instance: win32.HINSTANCE) -> win32.ATOM {
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
		lpszClassName = L("OdinMainClass"),
	}
	return win32.RegisterClassW(&wcx)
}

unregister_class :: proc(atom: win32.ATOM, instance: win32.HINSTANCE) {
	if atom == 0 {show_error_and_panic("atom is zero")}
	if !win32.UnregisterClassW(win32.LPCWSTR(uintptr(atom)), instance) {show_error_and_panic("UnregisterClassW")}
}

adjust_size_for_style :: proc(size: ^Int2, dwStyle: win32.DWORD) {
	rect := win32.RECT{0, 0, size.x, size.y}
	if win32.AdjustWindowRect(&rect, dwStyle, false) {
		size^ = {i32(rect.right - rect.left), i32(rect.bottom - rect.top)}
	}
}

center_window :: proc(position: ^Int2, size: Int2) {
	if deviceMode: win32.DEVMODEW; win32.EnumDisplaySettingsW(nil, win32.ENUM_CURRENT_SETTINGS, &deviceMode) {
		device_size := Int2{i32(deviceMode.dmPelsWidth), i32(deviceMode.dmPelsHeight)}
		position^ = (device_size - size) / 2
	}
}

create_window :: #force_inline proc(instance: win32.HINSTANCE, atom: win32.ATOM, game: ^Game) -> win32.HWND {
	if atom == 0 {show_error_and_panic("atom is zero")}
	style :: win32.WS_OVERLAPPED | win32.WS_CAPTION | win32.WS_SYSMENU
	size := game.window.size
	pos := Int2{i32(win32.CW_USEDEFAULT), i32(win32.CW_USEDEFAULT)}
	adjust_size_for_style(&size, style)
	if .CENTER in game.window.control_flags {
		center_window(&pos, size)
	}
	return win32.CreateWindowW(win32.LPCWSTR(uintptr(atom)), game.window.name, style, pos.x, pos.y, size.x, size.y, nil, nil, instance, game)
}

message_loop :: proc() -> int {
	msg: win32.MSG
	for win32.GetMessageW(&msg, nil, 0, 0) > 0 {
		win32.TranslateMessage(&msg)
		win32.DispatchMessageW(&msg)
	}
	return int(msg.wParam)
}

run :: proc() -> int {
	game := Game {
		tick_rate = 300 * time.Millisecond,
		last_tick = time.now(),
		pause = true,
		colors = {BLACK, WHITE},
		size = WORLD_SIZE,
		zoom = ZOOM,
		window = Window{name = L(TITLE), size = WORLD_SIZE * ZOOM, fps = FPS, control_flags = {.CENTER}},
	}
	for i in 0 ..< PALETTE_COUNT {
		c := u8((255 * int(i)) / (PALETTE_COUNT - 1))
		game.colors[i] = {c, c, c, 255}
	}

	game.colors[0] = {128, 64, 32, 255}
	game.colors[1] = {255, 128, 64, 255}

	world := World{game.size.x, game.size.y, make([]u8, game.size.x * game.size.y)}
	next_world := World{game.size.x, game.size.y, make([]u8, game.size.x * game.size.y)}
	defer delete(world.alive)
	defer delete(next_world.alive)
	game.world = &world
	game.next_world = &next_world

	instance := win32.HINSTANCE(win32.GetModuleHandleW(nil))
	if (instance == nil) {show_error_and_panic("No instance")}
	atom := register_class(instance)
	if atom == 0 {show_error_and_panic("Failed to register window class")}
	defer unregister_class(atom, instance)

	hwnd := create_window(instance, atom, &game)
	if hwnd == nil {show_error_and_panic("Failed to create window")}
	win32.ShowWindow(hwnd, win32.SW_SHOWDEFAULT)
	win32.UpdateWindow(hwnd)

	return message_loop()
}

main :: proc() {
	exit_code := run()
	os.exit(exit_code)
}
