package parser
import "core:fmt"

Node :: struct {
	value:       string,
	left_child:  ^Node,
	right_child: ^Node,
}

binary_tree_insert :: proc(node: ^Node, value: string) {

	if node.value == "" || node.value == value || node == nil {
		node.value = value
		return
	}
	if value < node.value {
		if node.left_child == nil {
			left_child := Node {
				value = value,
			}
			node.left_child = new_clone(left_child)
		} else {
			binary_tree_insert(node.left_child, value)
		}
		return
	} else {
		if node.right_child == nil {
			right_child := Node {
				value = value,
			}
			node.right_child = new_clone(right_child)
		} else {
			binary_tree_insert(node.right_child, value)
		}
		return
	}

	fmt.panicf("should not reach here", value)


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
	if node == nil || node.value == "" {
		return
	}

	binary_tree_print(node.left_child)
	fmt.print(" ", node.value)
	binary_tree_print(node.right_child)
}
