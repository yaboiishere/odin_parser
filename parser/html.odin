package parser

import "core:fmt"
import "core:os"
import "core:strings"

Tag :: union {
	Html,
	Body,
	A,
}

Html :: struct {
	body: string,
}

Body :: struct {
	children: []Tag,
}

A :: struct {
	href: string,
	text: string,
}

HtmlParseError :: union {
	os.Errno,
	Maybe(ExpectedEndMarker),
	ReadFailed,
}

ReadFailed :: struct {}

parse_html_file :: proc(file: string) -> (html: Html, error: HtmlParseError) {
	raw_html, read_success := os.read_entire_file(file)
	if !read_success {
		return Html{}, ReadFailed{}
	}

	tokenizer := tokenizer_create(string(raw_html), file)

	html = parse_html(&tokenizer) or_return

	return html, nil
}

parse_html :: proc(tokenizer: ^Tokenizer) -> (html: Html, error: HtmlParseError) {
	tokenizer_expect_exact(tokenizer, Text{value = "<html>"})
	tokenizer_read_string_until(tokenizer, {"<html>"}) or_return
	body := tokenizer_read_string_until(tokenizer, {"</html>"}) or_return

	fmt.printf("body: %s\n", body)

	return Html{body = body}, nil
}

// parse_body :: proc(tokenizer: ^Tokenizer) -> (body: Body) {
// 	tokenizer_expect_exact(tokenizer, Text{value = "<body>"})
// 	children := [dynamic]Tag{}
//
// 	for {
// 		tag := parse_tag(tokenizer)
// 		if tag == nil {
// 			break
// 		}
//
// 		append(children, tag)
// 	}
//
// 	tokenizer_expect_exact(tokenizer, Text{value = "</body>"})
//
// 	return Body{children = children[:]}
// }
//
// parse_tag :: proc(tokenizer: ^Tokenizer) -> (tag: Tag) {
// 	token := tokenizer_peek(tokenizer)
//
// 	if strings.has_prefix(token.(Text).value, "<a href=") {
// 		return parse_a(tokenizer)
// 	}
//
// 	return nil
// }
