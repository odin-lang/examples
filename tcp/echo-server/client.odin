package main

import "core:fmt"
import "core:net"
import "core:os"

tcp_cli :: proc(ip: string, port: int) {
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
	for true {
		buf: [256]u8
		n, err_read := os.read(os.stdin, buf[:])
		if err_read != nil {
			fmt.println("Failed to read data")
			break
		}
		if (n == 0 || (n == 1 && buf[0] == '\n')) {
			break
		}
		bytes_sent, err_send := net.send_tcp(sock, buf[:n])
		if err_send != nil {
			fmt.println("Failed to send data")
			break
		}
		fmt.println("Client sent [", bytes_sent, "bytes ]: ", string(buf[:n]))
		bytes_recv, err_recv := net.recv_tcp(sock, buf[:])
		if err_recv != nil {
			fmt.println("Failed to receive data")
			break
		}
		fmt.println("Client received [", bytes_recv, "bytes ]: ", string(buf[:bytes_recv]))
	}
	net.close(sock)
}

main :: proc() {
	tcp_cli("127.0.0.1", 8080)
}

