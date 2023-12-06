package parser

import "core:fmt"
// import "core:log"
import "core:net"
import "core:strings"

ResolveError :: union {
	net.Network_Error,
	GotIPV6Error,
	MissingHostnameError,
}

GotIPV6Error :: struct {
	ipv6: net.IP6_Address,
}

MissingHostnameError :: struct {}

resolve_ip :: proc(hostname: string) -> (resp_ip: net.Endpoint, error: ResolveError) {
	ip_endpoint, _ := net.resolve(hostname) or_return

	_, is_ipv4 := ip_endpoint.address.(net.IP4_Address)

	if is_ipv4 {
		return ip_endpoint, nil
	}


	return net.Endpoint{}, GotIPV6Error{ipv6 = ip_endpoint.address.(net.IP6_Address)}
}

ipv4ToString :: proc(ipv4: ^net.IP4_Address) -> string {
	builder := strings.builder_make()

	for i in 0 ..< 4 {
		octet := uint(ipv4[i])
		strings.write_uint(&builder, octet)
		if i != 3 {
			strings.write_byte(&builder, '.')
		}
	}

	return strings.to_string(builder)
}

dnsLookup :: proc(dnsLookupArguments: DNSLookup) -> (ipv4String: string, error: ResolveError) {
	hostname := dnsLookupArguments.hostname

	if hostname == "" {
		return "", MissingHostnameError{}
	}

	ipv4 := resolve_ip(hostname) or_return

	ipv4String = ipv4ToString(&ipv4.address.(net.IP4_Address))

	return ipv4String, nil
}

GetError :: union {
	net.Network_Error,
	ParseUrlError,
	ResolveError,
	FailedToWriteAllBytes,
}

FailedToWriteAllBytes :: struct {}

get :: proc(url: string) -> (response: string, error: GetError) {
	url := parse_url(url) or_return

	url_builer := strings.builder_make()
	strings.write_string(&url_builer, url.host)
	strings.write_byte(&url_builer, ':')
	strings.write_int(&url_builer, url.port)

	url_with_port := strings.to_string(url_builer)

	resolved_ip := resolve_ip(url_with_port) or_return
	ipv4_string := ipv4ToString(&resolved_ip.address.(net.IP4_Address))

	socket := net.dial_tcp(resolved_ip) or_return
	get_body := build_get(ipv4_string, url.path)

	bytes_written := net.send_tcp(socket, transmute([]u8)get_body) or_return

	if bytes_written != len(get_body) {
		return "", FailedToWriteAllBytes{}
	}

	response_builder := strings.builder_make()
	response_buffer := [1024]u8{}

	for {
		bytes_read := net.recv_tcp(socket, response_buffer[:]) or_return

		if bytes_read == 0 {
			break
		}

		strings.write_bytes(&response_builder, response_buffer[:])
	}

	return strings.to_string(response_builder), nil
}

build_get :: proc(ipv4_string: string, path: string) -> string {
	builder := strings.builder_make()

	strings.write_string(&builder, "GET /")
	strings.write_string(&builder, path)
	strings.write_string(&builder, " HTTP/1.1\r\n")
	strings.write_string(&builder, "Host: ")
	strings.write_string(&builder, ipv4_string)
	strings.write_string(&builder, "\r\n\r\n")

	return strings.to_string(builder)
}
