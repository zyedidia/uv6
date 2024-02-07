#include <string.h>

void _start(void);

/* This is the application entry point */
int main(int, char **);

extern void __libc_init_array(void);

extern void exit(int);

void _start(void) {
    __libc_init_array();

#define argv NULL
#define argc 0

    int ret = main(argc, argv);
    exit(ret);
}
