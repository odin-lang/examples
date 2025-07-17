package main

import "core:fmt"
import "core:net"
import "core:os"

udp_echo_client :: proc(ip: string, port: int) {
	local_addr, ok := net.parse_ip4_address(ip)
	if !ok {
		fmt.println("Failed to parse IP address")
		return
	}
	server_endpoint := net.Endpoint {
		address = local_addr,
		port    = port,
	}
	// for the client, we create an *unbound* UDP socket,
	// the socket will be bound to a free port when we attempt to send data
	sock, err := net.make_unbound_udp_socket(net.family_from_address(local_addr))
	if err != nil {
		fmt.println("Failed to make unbound UDP socket", err)
		return
	}
	fmt.println("Client is ready")
	buffer: [256]u8
	for {
		fmt.print("> ")
		n, err_read := os.read(os.stdin, buffer[:])
		if err_read != nil {
			fmt.println("Failed to read data", err_read)
			break
		}
		data := buffer[:n]
		if n == 0 || is_eol(data)  {
			break
		}
		bytes_sent, err_send := net.send_udp(sock, data, server_endpoint)
		if err_send != nil {
			fmt.println("Failed to send data", err_send)
			break
		}
		sent := data[:bytes_sent]
		fmt.printfln("Client sent [ %d bytes ]: %s", len(sent), sent)
		bytes_recv, _, err_recv  := net.recv_udp(sock, buffer[:])
		if err_recv != nil {
			fmt.println("Failed to receive data", err_recv)
			break
		}
		received := buffer[:bytes_recv]
		fmt.printfln("Client received [ %d bytes ]: %s", len(received), received)
	}
	net.close(sock)
	fmt.println("Closed socket")
}

main :: proc() {
	udp_echo_client("127.0.0.1", 8080)
}

is_lf :: proc(bytes : []u8) -> bool {
	return len(bytes) == 1 && bytes[0] == '\n'
}

is_crlf :: proc(bytes : []u8) -> bool {
	return len(bytes) == 2 && bytes[0] == '\r' && bytes[1] == '\n'
}

is_eol :: proc(bytes : []u8) -> bool {
	return is_lf(bytes) || is_crlf(bytes)
}