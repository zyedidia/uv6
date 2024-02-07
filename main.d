module main;

import core.lib;

import proc;
import sched;

enum Arg {
    NOVERIFY = "noverify",
}

struct Flags {
    bool noverify;
}

__gshared Flags flags;

void dofilemax() {
    // Raise file descriptor limit to the max.
    RLimit rlim;
    ensure(getrlimit(RLIMIT_NOFILE, &rlim) == 0);
    rlim.rlim_cur = rlim.rlim_max;
    ensure(setrlimit(RLIMIT_NOFILE, &rlim) == 0);
}

void usage() {
    fprintf(stderr, "usage:\n");
    fprintf(stderr, "  uv6 [OPTIONS] FILE [ARGS]\n\n");
    fprintf(stderr, "options:\n");
    fprintf(stderr, "  --no-verify\tdo not perform verification\n");
}

extern (C) int main(int argc, const(char)** argv) {
    dofilemax();

    int i;
    for (i = 1; i < argc; i++) {
        const(char)* arg = argv[i];
        if (arg[0] != '-')
            break;
        arg++;
        if (arg[0] == '-')
            arg++;
        if (strncmp(arg, Arg.NOVERIFY.ptr, Arg.NOVERIFY.length) == 0) {
            fprintf(stderr, "WARNING: verification disabled\n");
            flags.noverify = true;
        } else {
            fprintf(stderr, "unknown flag: %s\n", argv[i]);
        }
    }

    if (i >= argc) {
        fprintf(stderr, "error: no program given\n");
        usage();
        return 0;
    }

    const(char)* file = argv[i];
    Proc* p = procfile(file, argc - i, &argv[i], null);
    if (!p) {
        fprintf(stderr, "error could not load %s\n", argv[i]);
        return 1;
    }

    schedule();

    return 0;
}
