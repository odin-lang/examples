package main

import "core:fmt"
import "core:net"
import "core:os"

tcp_echo_client :: proc(ip: string, port: int) {
	local_addr, ok := net.parse_ip4_address(ip)
	if !ok {
		fmt.println("Failed to parse IP address")
		return
	}
	sock, err := net.dial_tcp_from_address_and_port(local_addr, port)
	if err != nil {
		fmt.println("Failed to connect to server")
		return
	}
	buffer: [256]u8
	for {
		n, err_read := os.read(os.stdin, buffer[:])
		if err_read != nil {
			fmt.println("Failed to read data")
			break
		}
		if n == 0 || (n == 1 && buffer[0] == '\n') {
			break
		}
		data := buffer[:n]
		bytes_sent, err_send := net.send_tcp(sock, data)
		if err_send != nil {
			fmt.println("Failed to send data")
			break
		}
		sent := data[:bytes_sent]
		fmt.printfln("Client sent [ %d bytes ]: %s", len(sent), sent)
		bytes_recv, err_recv := net.recv_tcp(sock, buffer[:])
		if err_recv != nil {
			fmt.println("Failed to receive data")
			break
		}
		received := buffer[:bytes_recv]
		fmt.printfln("Client received [ %d bytes ]: %s", len(received), received)
	}
	net.close(sock)
}

main :: proc() {
	tcp_echo_client("127.0.0.1", 8080)
}
