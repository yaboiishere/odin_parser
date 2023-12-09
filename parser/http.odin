package parser

import "core:fmt"
import "core:net"
import "core:os"
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
	FailedToWriteFile,
	ParseHttpError,
}

FailedToWriteAllBytes :: struct {}
FailedToWriteFile :: struct {}

http_get :: proc(url: string, file: string) -> (response: string, error: GetError) {
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

		strings.write_bytes(&response_builder, response_buffer[:bytes_read])
	}

	net.close(socket)

	response = strings.to_string(response_builder)

	parse_http(response) or_return

	if file != "" {
		// write_file(file, response) or_return
		if !os.write_entire_file(file, transmute([]u8)response) {
			return "", FailedToWriteFile{}
		}
	}

	return response, nil
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

ParseHttpError :: union {
	Maybe(ExpectedToken),
	ParseHeadersError,
}

parse_http :: proc(http: string) -> (status: int, body: string, error: ParseHttpError) {
	tokenizer := tokenizer_create(http, "http")
	tokenizer_expect_exact(&tokenizer, Text{value = "HTTP"}) or_return
	tokenizer_expect(&tokenizer, Slash{}) or_return
	tokenizer_expect(&tokenizer, IntConst{}) or_return
	tokenizer_expect(&tokenizer, Period{}) or_return
	tokenizer_expect(&tokenizer, IntConst{}) or_return
	tokenizer_skip_any_of(&tokenizer, {Whitespace{}})

	statusToken := tokenizer_expect(&tokenizer, IntConst{}) or_return
	status = statusToken.token.(IntConst).value

	tokenizer_skip_any_of(&tokenizer, {Whitespace{}})

	tokenizer_expect(&tokenizer, Text{}) or_return

	tokenizer_expect(&tokenizer, EOF{}) or_return

	parse_headers(&tokenizer) or_return

	body = parse_body(&tokenizer) or_return

	return status, body, nil
}

Header :: struct {
	name:  string,
	value: string,
}

ParseHeadersError :: union {
	Maybe(ExpectedToken),
	Maybe(ExpectedEndMarker),
}

parse_headers :: proc(
	tokenizer: ^Tokenizer,
) -> (
	headers: [dynamic]Header,
	error: ParseHeadersError,
) {
	for {
		token := tokenizer_peek(tokenizer)

		_, is_eof := token.(EOF)

		if is_eof {
			break
		}

		nameToken := tokenizer_expect(tokenizer, Text{}) or_return

		tokenizer_expect(tokenizer, Colon{}) or_return
		tokenizer_skip_any_of(tokenizer, {Whitespace{}})
		value := tokenizer_read_string_until(tokenizer, []string{"\r\n"}) or_return

		tokenizer_expect(tokenizer, EOF{}) or_return


		header := Header {
			name  = nameToken.token.(Text).value,
			value = value,
		}

		append(&headers, header)
	}

	fmt.printf("headers: %v\n", headers)

	return headers, nil
}

parse_body :: proc(tokenizer: ^Tokenizer) -> (body: string, error: ParseHttpError) {
	fmt.printf("parse_body\n")

	return body, nil
}
// WriteError :: union {
// 	os.Errno,
// 	FailedToWriteAllBytes,
// }
//
// write_file :: proc(file: string, contents: string) -> (error: WriteError) {
// 	file_handle, open_error := os.open(
// 		file,
// 		os.O_WRONLY | os.O_CREATE,
// 		os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH,
// 	)
//
// 	if open_error != os.ERROR_NONE {
// 		return open_error
// 	}
//
// 	contents_len := len(contents)
// 	write: []u8 = transmute([]u8)contents[:contents_len]
//
// 	bytes_written, write_error := os.write(file_handle, write)
//
// 	if write_error != os.ERROR_NONE {
// 		return write_error
// 	}
//
// 	if bytes_written != contents_len {
// 		return FailedToWriteAllBytes{}
// 	}
//
// 	fmt.printf("Wrote %d bytes to %s\n", bytes_written, file)
//
// 	return nil
// }
