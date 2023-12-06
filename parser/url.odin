package parser

import "core:fmt"

ParseUrlError :: union {
	InvalidProtocol,
	InvalidPort,
	InvalidHost,
	Maybe(ExpectedToken),
}

InvalidProtocol :: struct {}

InvalidPort :: struct {}

InvalidPath :: struct {}

InvalidHost :: struct {}

Url :: struct {
	protocol: string,
	host:     string,
	port:     int,
	path:     string,
}

parse_url_cli :: proc(parse_url_arguments: ParseUrl) -> (url: Url, error: ParseUrlError) {
	raw_url := parse_url_arguments.url
	return parse_url(raw_url)
}

parse_url :: proc(raw_url: string) -> (url: Url, error: ParseUrlError) {
	tokenizer := tokenizer_create(raw_url, "url")

	protocol_token, protocol_error := tokenizer_expect_exact_one_of(
		&tokenizer,
		{Text{value = "http"}, Text{value = "https"}},
	)

	protocol, protocol_is_text := protocol_token.token.(Text)
	if protocol_error != nil || !protocol_is_text {
		return url, InvalidProtocol{}
	}

	url.protocol = protocol.value

	_ = tokenizer_expect_exact(&tokenizer, Colon{}) or_return

	_ = tokenizer_expect_exact(&tokenizer, Slash{}) or_return
	_ = tokenizer_expect_exact(&tokenizer, Slash{}) or_return

	host_token, host_error := tokenizer_expect(&tokenizer, Text{})
	host, host_is_text := host_token.token.(Text)

	if host_error != nil || !host_is_text {
		return url, InvalidHost{}
	}

	url.host = host.value

	colon_token, _ := tokenizer_expect_one_of(&tokenizer, {Colon{}, Slash{}})
	_, is_colon := colon_token.token.(Colon)

	if is_colon {
		port_token, port_error := tokenizer_expect(&tokenizer, IntConst{})
		port, port_is_int := port_token.token.(IntConst)

		if port_error != nil || !port_is_int {
			return url, InvalidPort{}
		}

		url.port = port.value

	} else {
		url.port = 80
	}

	path_token, _ := tokenizer_expect(&tokenizer, Text{})
	path, path_is_text := path_token.token.(Text)

	if path_is_text {
		url.path = path.value
	}

	return url, nil
}
