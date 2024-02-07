#define weak __attribute__((__weak__))
#define hidden __attribute__((__visibility__("hidden")))
#define weak_alias(old, new) \
extern __typeof(old) new __attribute__((__weak__, __alias__(#old)))

#define START "_start"
#define _dlstart_c _start_c
#include "dlstart.c"

weak void _init();
weak void _fini();
int main(int, char **);
void exit(int);

hidden void __dls2(unsigned char *base, size_t *sp)
{
    int r = main(*sp, (void *)(sp+1));
    exit(r);
}
