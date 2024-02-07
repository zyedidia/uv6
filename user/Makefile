PICOLIBC_INCLUDE=build/install/include
PICOLIBC_LIB=build/install/lib

CC=/opt/lfi/toolchain/bin/lfi-clang

all: empty hello

empty: empty.o syscall.o
	$(CC) -nostdlib -L$(PICOLIBC_LIB) $^ -lc -static -o $@
%: %.o syscall.o crt0.o
	$(CC) -nostdlib -L$(PICOLIBC_LIB) $^ -lc -static -o $@
%.o: %.S
	$(CC) -c $^ -o $@
%.o: %.c
	$(CC) -nostdlib -I$(PICOLIBC_INCLUDE) -O2 -c $^ -o $@
