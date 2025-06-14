# polystate-examples
Examples for polystate, Requires the [latest zig compiler](https://ziglang.org/download/).

The latest x86 backend of the zig compiler has switched to the zig implementation. Unfortunately, it cannot handle tail recursion. Therefore, the demo code needs to be compiled in Release mode.

# examples

## atm
```shell
zig build -Doptimize=ReleaseFast atm
```
![atm_graph](data/atm_graph.svg)
![atm_graph](data/atm.png)

## counter
```shell
zig build -Doptimize=ReleaseFast counter
```
![counter_graph](data/counter_graph.svg)
![atm_graph](data/counter.png)

## TodoList
```shell
zig build -Doptimize=ReleaseFast todo
```
![todo_graph](data/todo_graph.svg)
![atm_graph](data/todo.png)

## Editor
```shell
zig build -Doptimize=ReleaseFast editor
```
![editor_graph](data/editor_graph.svg)
![atm_graph](data/editor.png)

## Cont
```shell
zig build -Doptimize=ReleaseFast cont
```
![cont_graph](data/cont_graph.svg)
