package parser

import "core:os"

HtmlParseError :: union {
	os.Errno,
	Maybe(ExpectedEndMarker),
	ReadFailed,
	ExpectedOpeningTagOrText,
	Maybe(ExpectedOneOf),
	Maybe(ExpectedToken),
	ExpectedHtmlTag,
}

Html :: struct {
	body: Body,
}

Body :: struct {
	children: [dynamic]HtmlTag,
}

A :: struct {
	href:     Url,
	children: [dynamic]HtmlTag,
}

HtmlTag :: union {
	string,
	A,
	Body,
}

ReadFailed :: struct {}
ExpectedOpeningTagOrText :: struct {}
ExpectedHtmlTag :: struct {}

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
	maybe_html_tag := tokenizer_expect(tokenizer, Tag{}) or_return

	html_tag, is_html_tag := maybe_html_tag.token.(Tag)
	if !is_html_tag {
		return Html{}, ExpectedHtmlTag{}
	}

	maybe_body_tag := parse_tag(html_tag.inside) or_return

	if len(maybe_body_tag) != 1 {
		panic("expected one body tag")
	}

	body, is_body := maybe_body_tag[0].(Body)

	if !is_body {
		panic("expected body tag")
	}

	return Html{body = body}, nil
}

parse_tag :: proc(raw_tag: string) -> (tag: [dynamic]HtmlTag, error: HtmlParseError) {
	children := [dynamic]HtmlTag{}

	if raw_tag == "" || raw_tag == "\n" {
		return {}, nil
	}

	tokenizer := tokenizer_create(raw_tag, raw_tag)

	for {
		tokenizer_skip_any_of(&tokenizer, {EOF{}, Whitespace{}, TagEnd{}})
		next_token := tokenizer_peek(&tokenizer)

		_, is_text := next_token.(Text)

		if is_text {
			string_value, string_value_error := tokenizer_read_string_until(&tokenizer, {"<"})
			if string_value_error == nil {
				append(&children, string_value)
				continue
			} else {
				append(&children, raw_tag)
				break
			}
		}

		_, is_close_tag := next_token.(CloseTag)

		if is_close_tag {
			tokenizer_expect(&tokenizer, CloseTag{}) or_return
			next := tokenizer_peek(&tokenizer)
			_, is_eof := next.(EOF)
			if is_eof {
				break
			}
			continue
		}

		should_be_tag := tokenizer_expect(&tokenizer, Tag{}) or_return

		tag, is_tag := should_be_tag.token.(Tag)

		if is_tag {
			switch tag.value {
			case "a":
				a := A {
					href     = tag.attribute.value.(Url),
					children = parse_tag(tag.inside) or_return,
				}
				append(&children, a)
				continue
			case "body":
				body := Body {
					children = parse_tag(tag.inside) or_return,
				}
				append(&children, body)
				continue
			case:
				panic("unsupported tag")
			}
		}
		break
	}

	return children, nil
}
