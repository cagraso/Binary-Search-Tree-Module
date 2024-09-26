# Binary Search Tree Module
## Brief Explanation
Binary Search Tree (BST) module can store a BST having a user defined maximum node number.  Module iterates over the tree at every clock cycle and processes insert, find and delete operations for a tree node.
## Design Overview
BST module has clock, reset, data port, data ready and command (insert, find, delete) input  interfaces. Module can store a BST by receiving node data in burst mode through the data input port. Module can also insert a new node to a stored tree, if it receives “insert” command. Any BST node can be removed from the tree when “delete” command is received. 

Each node in the tree is assigned to a specific index number. To access a node in the tree, assigned index values are used. Tree node values are stored in an indexed array. Child info of each node is stored in 2D array which holds index numbers of each child. 

BST module has node index data out port, node found output signal and node not found output signal interfaces. When module receives a “find” command, it searches the tree for the requested node. If the node is found, module asserts a “found” signal and sends node index value to the data output port. If the node doesn’t exists in the tree, “not found” signal is asserted.
