#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/wait.h>
#include <linux/limits.h>

int main(void) {
    fprintf(stderr, "test");
    static char buf[100];
    fgets(buf, sizeof(buf), stdin);
}
