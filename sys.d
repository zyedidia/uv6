module sys;

import core.lib;

import proc;
import lfi;
import file;
import fd;

enum {
    SYS_FORK   = 1,
    SYS_EXIT   = 2,
    SYS_WAIT   = 3,
    SYS_PIPE   = 4,
    SYS_READ   = 5,
    SYS_KILL   = 6,
    SYS_EXEC   = 7,
    SYS_FSTAT  = 8,
    SYS_CHDIR  = 9,
    SYS_DUP    = 10,
    SYS_GETPID = 11,
    SYS_SBRK   = 12,
    SYS_SLEEP  = 13,
    SYS_UPTIME = 14,
    SYS_OPEN   = 15,
    SYS_WRITE  = 16,
    SYS_MKNOD  = 17,
    SYS_UNLINK = 18,
    SYS_LINK   = 19,
    SYS_MKDIR  = 20,
    SYS_CLOSE  = 21,
}

enum {
    ERR_PERM  = -1,
    ERR_BADF  = -9,
    ERR_FAULT = -14,
    ERR_NOSYS = -38,
}

alias SyscallFn = uintptr function(Proc* p, ulong[6] args);

SyscallFn[] systbl = [
    SYS_EXIT:  &sysexit,
    SYS_READ:  &sysread,
    SYS_WRITE: &syswrite,
];

uintptr syscall(Proc* p, ulong num, ulong a0, ulong a1, ulong a2, ulong a3, ulong a4, ulong a5) {
    if (num >= systbl.length)
        return ERR_NOSYS;
    SyscallFn fn = systbl[num];
    if (fn == null)
        return ERR_NOSYS;
    return fn(p, [a0, a1, a2, a3, a4, a5]);
}

uintptr sysexit(Proc* p, ulong[6] args) {
    printf("exited\n");
    exit(1);
}

uintptr sysread(Proc* p, ulong[6] args) {
    FDFile* f = fdget(&p.fdtable, cast(int) args[0]);
    if (!f)
        return ERR_BADF;
    if (f.read == null)
        return ERR_PERM;
    ubyte[] buf = procbuf(p, args[1], args[2]);
    if (!buf)
        return ERR_FAULT;
    return f.read(f.dev, p, buf);
}

uintptr syswrite(Proc* p, ulong[6] args) {
    FDFile* f = fdget(&p.fdtable, cast(int) args[0]);
    if (!f)
        return ERR_BADF;
    if (f.write == null)
        return ERR_PERM;
    ubyte[] buf = procbuf(p, args[1], args[2]);
    if (!buf)
        return ERR_FAULT;
    return f.write(f.dev, p, buf);
}

int syserr(int val) {
    if (val == -1) {
        return -errno;
    }
    return val;
}

ssize syserr(ssize val) {
    if (val == -1) {
        return -errno;
    }
    return val;
}
