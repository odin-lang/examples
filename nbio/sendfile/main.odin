/*
Example that shows the `sendfile` operation.

Dials a TCP server (localhost:1234) (use `nc -l 1234` to start a netcat server)
and sends the contents of this file to it.

Try it with a big file and you will see progress updates as the file is sent.
*/
package main

import "core:fmt"
import "core:nbio"
import "core:os"
import "core:terminal/ansi"

main :: proc() {
	if len(os.args) <= 1 {
		fmt.eprintfln("usage: %s <path>", os.args[0])
		return
	}

	err := nbio.acquire_thread_event_loop()
	assert(err == nil)
	defer nbio.release_thread_event_loop()

	nbio.dial({nbio.IP4_Loopback, 1234}, on_dial)

	err = nbio.run()
	assert(err == nil)

	on_dial :: proc(op: ^nbio.Operation) {
		fmt.assertf(op.dial.err == nil, "dial: %v", op.dial.err)

		file, err := nbio.open_sync(os.args[1])
		assert(err == nil)

		// Call can also take an offset, a length, a timeout.
		// By default it sends the entire file, without a timeout.
		op := nbio.sendfile(op.dial.socket, file, on_sent, progress_updates=true)

		fmt.print(ansi.CSI + ansi.DECTCEM_HIDE)
		render_progress(op, clear=false)
	}

	on_sent :: proc(op: ^nbio.Operation) {
		fmt.assertf(op.sendfile.err == nil, "sendfile: %v", op.sendfile.err)

		render_progress(op, clear=true)
		if op.sendfile.sent < op.sendfile.nbytes {
			// Progress update, not done.
			return
		}

		fmt.print(ansi.CSI + ansi.DECTCEM_SHOW)
		nbio.close(op.sendfile.file)
	}
}

render_progress :: proc(op: ^nbio.Operation, clear: bool) {
	if clear {
		fmt.print(ansi.CSI + "1" + ansi.CUU)
	}

	fmt.print(ansi.CSI + "2" + ansi.EL + ansi.CSI + "0" + ansi.CHA)
	fmt.printfln("%M/%M", op.sendfile.sent, op.sendfile.nbytes)
}
