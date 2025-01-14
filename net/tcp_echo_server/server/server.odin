package main

import "core:fmt"
import "core:net"
import "core:strings"
import "core:thread"

is_ctrl_d :: proc(bytes: []u8, bytes_read: int) -> bool {
	return bytes_read == 1 && bytes[0] == 4
}

// checks if ends with \r\n or \n
is_empty :: proc(bytes: []u8, bytes_read: int) -> bool {
	return(
		(bytes_read == 2 && bytes[0] == 13 && bytes[1] == 10) ||
		(bytes_read == 1 && bytes[0] == 10) \
	)
}

is_telnet_ctrl_c :: proc(bytes: []u8, bytes_read: int) -> bool {
	return(
		(bytes_read == 3 && bytes[0] == 255 && bytes[1] == 251 && bytes[2] == 6) ||
		(bytes_read == 5 &&
				bytes[0] == 255 &&
				bytes[1] == 244 &&
				bytes[2] == 255 &&
				bytes[3] == 253 &&
				bytes[4] == 6) \
	)
}

handle_msg :: proc(sock: net.TCP_Socket) {
	buffer_backing: [256]u8
	buffer := buffer_backing[:]
	for {
		bytes_recv, err_recv := net.recv_tcp(sock, buffer[:])
		if err_recv != nil {
			fmt.println("Failed to receive data")
		}
		if bytes_recv == 0 ||
		   is_ctrl_d(buffer, bytes_recv) ||
		   is_empty(buffer, bytes_recv) ||
		   is_telnet_ctrl_c(buffer, bytes_recv) {
			fmt.println("Disconnecting client")
			break
		}
		fmt.printfln("Server received [ %d bytes ]: %s", bytes_recv, buffer[:bytes_recv])
		bytes_sent, err_send := net.send_tcp(sock, buffer[:bytes_recv])
		if err_send != nil {
			fmt.println("Failed to send data")
		}
		fmt.printfln("Server sent [ %d bytes ]: %s", bytes_sent, buffer[:bytes_sent])
	}
	net.close(sock)
}

tcp_echo_server :: proc(ip: string, port: int) {
	local_addr, ok := net.parse_ip4_address(ip)
	if !ok {
		fmt.println("Failed to parse IP address")
		return
	}
	endpoint := net.Endpoint {
		address = local_addr,
		port    = port,
	}
	sock, err := net.listen_tcp(endpoint)
	if err != nil {
		fmt.println("Failed to listen on TCP")
		return
	}
	fmt.printfln("Listening on TCP: %s", net.endpoint_to_string(endpoint))
	for {
		cli, _, err_accept := net.accept_tcp(sock)
		if err_accept != nil {
			fmt.println("Failed to accept TCP connection")
		}
		thread.create_and_start_with_poly_data(cli, handle_msg)
	}
	net.close(sock)
	fmt.println("Closed socket")
}

main :: proc() {
	tcp_echo_server("127.0.0.1", 8080)
}
