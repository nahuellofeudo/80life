# 80life
Conway's Game of Life in Z80 Assembly language
Right now it builds a binary that runs, but the life algorithm itself is buggy.

## TODO: 

* Fix the algorithm.
* Automate the build process.
* Make it generate .com files to run on CP/M systems.

# Instructions

Requires 

* z80asm
* [Udo Munk's Z80pack](https://github.com/udo-munk/z80pack) for z80sim and bin2hex


### Build with
```
$ z80asm 80life.asm -o 80life.bin
$ bin2hex 80life.bin 80life.hex -o 0
```

### Run with

```
$ z80sim -x 80life.bin
```
