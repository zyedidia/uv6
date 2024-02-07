.macro syscall name num
.globl \name
\name:
	mov x8, \num
	svc #0
	ret
.endm

syscall fork   1
syscall exit   2
syscall wait   3
syscall pipe   4
syscall read   5
syscall kill   6
syscall exec   7
syscall fstat  8
syscall chdir  9
syscall dup    10
syscall getpid 11
syscall sbrk   12
syscall sleep  13
syscall uptime 14
syscall open   15
syscall write  16
syscall mknod  17
syscall unlink 18
syscall link   19
syscall mkdir  20
syscall close  21
syscall lseek  22
