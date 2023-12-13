package parser
import "core:fmt"

Node :: struct {
	value:       string,
	left_child:  ^Node,
	right_child: ^Node,
}

binary_tree_insert :: proc(node: ^Node, value: string) {
	if node == nil || node.value == "" {
		fmt.println("init ", value)
		node.value = value
		return
	}
	fmt.println("insert ", value)
	if value < node.value {
		binary_tree_insert(node.left_child, value)
	} else {
		binary_tree_insert(node.right_child, value)
	}

}

binary_tree_search :: proc(node: ^Node, value: string) -> bool {
	if node == nil {
		return false
	}

	if node.value == value {
		return true
	}

	if value < node.value {
		return binary_tree_search(node.left_child, value)
	} else {
		return binary_tree_search(node.right_child, value)
	}
}

binary_tree_print :: proc(node: ^Node) {
	if node == nil {
		return
	}

	binary_tree_print(node.left_child)
	fmt.println(node.value)
	binary_tree_print(node.right_child)
}
