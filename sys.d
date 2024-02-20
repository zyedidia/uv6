module sys;

import core.lib;

import proc;
import lfi;
import file;
import fd;
import pipe;

enum Sys {
    FORK   = 1,
    EXIT   = 2,
    WAIT   = 3,
    PIPE   = 4,
    READ   = 5,
    KILL   = 6,
    EXEC   = 7,
    FSTAT  = 8,
    CHDIR  = 9,
    DUP    = 10,
    GETPID = 11,
    SBRK   = 12,
    SLEEP  = 13,
    UPTIME = 14,
    OPEN   = 15,
    WRITE  = 16,
    MKNOD  = 17,
    UNLINK = 18,
    LINK   = 19,
    MKDIR  = 20,
    CLOSE  = 21,
}

enum Err {
    PERM  = -1,
    BADF  = -9,
    FAULT = -14,
    INVAL = -22,
    MFILE = -24,
    NPIPE = -25,
    NOSYS = -38,
}

alias SyscallFn = uintptr function(Proc* p, ulong[6] args);

SyscallFn[] systbl = [
    Sys.FORK:   &sysfork,
    Sys.EXIT:   &sysexit,
    Sys.WAIT:   &syswait,
    Sys.PIPE:   &syspipe,
    Sys.READ:   &sysread,
    Sys.KILL:   &syskill,
    Sys.EXEC:   &sysexec,
    Sys.FSTAT:  &sysfstat,
    Sys.CHDIR:  &syschdir,
    Sys.DUP:    &sysdup,
    Sys.GETPID: &sysgetpid,
    Sys.SBRK:   &syssbrk,
    Sys.SLEEP:  &syssleep,
    Sys.UPTIME: &sysuptime,
    Sys.OPEN:   &sysopen,
    Sys.WRITE:  &syswrite,
    Sys.MKNOD:  &sysmknod,
    Sys.UNLINK: &sysunlink,
    Sys.LINK:   &syslink,
    Sys.MKDIR:  &sysmkdir,
    Sys.CLOSE:  &sysclose,
];

uintptr syscall(void* p, ulong num,
        ulong a0, ulong a1, ulong a2, ulong a3, ulong a4, ulong a5) {
    if (num >= systbl.length)
        return Err.NOSYS;
    SyscallFn fn = systbl[num];
    if (fn == null)
        return Err.NOSYS;
    return fn(cast(Proc*) p, [a0, a1, a2, a3, a4, a5]);
}

uintptr sysexit(Proc* p, ulong[6] args) {
    printf("exited\n");
    exit(1);
}

uintptr sysopen(Proc* p, ulong[6] args) {
    const(char)* path = procpath(p, args[0]);
    if (!path)
        return Err.FAULT;
    FDFile* f = filenew(path, cast(int) args[1], cast(int) args[2]);
    if (!f)
        return Err.INVAL;
    int fd = fdalloc(&p.fdtable);
    if (fd < 0) {
        fdrelease(f);
        return Err.MFILE;
    }
    fdassign(&p.fdtable, fd, f);
    return fd;
}

uintptr sysclose(Proc* p, ulong[6] args) {
    bool ok = fdremove(&p.fdtable, cast(int) args[0]);
    if (!ok)
        return Err.BADF;
    return 0;
}

uintptr sysread(Proc* p, ulong[6] args) {
    FDFile* f = fdget(&p.fdtable, cast(int) args[0]);
    if (!f)
        return Err.BADF;
    if (f.read == null)
        return Err.PERM;
    ubyte[] buf = procbuf(p, args[1], args[2]);
    if (!buf)
        return Err.FAULT;
    return f.read(f.dev, p, buf);
}

uintptr syswrite(Proc* p, ulong[6] args) {
    FDFile* f = fdget(&p.fdtable, cast(int) args[0]);
    if (!f)
        return Err.BADF;
    if (f.write == null)
        return Err.PERM;
    ubyte[] buf = procbuf(p, args[1], args[2]);
    if (!buf)
        return Err.FAULT;
    return f.write(f.dev, p, buf);
}

uintptr sysfstat(Proc* p, ulong[6] args) {
    Stat* stat = procobj!(Stat)(p, args[1]);
    if (!stat)
        return Err.FAULT;
    FDFile* f = fdget(&p.fdtable, cast(int) args[0]);
    if (!f)
        return Err.BADF;
    if (f.stat == null)
        return Err.PERM;
    if (f.stat(f.dev, p, stat) < 0)
        return Err.INVAL;
    return 0;
}

uintptr syschdir(Proc* p, ulong[6] args) {
    assert(0, "chdir");
}

uintptr sysdup(Proc* p, ulong[6] args) {
    assert(0, "dup");
}

uintptr sysgetpid(Proc* p, ulong[6] args) {
    return procpid(p);
}

uintptr syssbrk(Proc* p, ulong[6] args) {
    assert(0, "sbrk");
}

uintptr syssleep(Proc* p, ulong[6] args) {
    assert(0, "sleep");
}

uintptr sysuptime(Proc* p, ulong[6] args) {
    assert(0, "uptime");
}

uintptr sysmknod(Proc* p, ulong[6] args) {
    assert(0, "mknod");
}

uintptr sysunlink(Proc* p, ulong[6] args) {
    const(char)* path = procpath(p, args[0]);
    if (!path)
        return Err.FAULT;
    return syserr(unlinkat(AT_FDCWD, path, 0));
}

uintptr syslink(Proc* p, ulong[6] args) {
    assert(0, "link");
}

uintptr sysmkdir(Proc* p, ulong[6] args) {
    const(char)* path = procpath(p, args[0]);
    if (!path)
        return Err.FAULT;
    return syserr(mkdirat(AT_FDCWD, path, cast(int) args[1]));
}

uintptr sysfork(Proc* p, ulong[6] args) {
    assert(0, "fork");
}

uintptr syswait(Proc* p, ulong[6] args) {
    assert(0, "wait");
}

uintptr syspipe(Proc* p, ulong[6] args) {
    struct Pipefd {
        int[2] fd;
    }

    bool success;
    Pipefd* pipefd = procobj!(Pipefd)(p, args[0]);
    if (pipefd == null)
        return Err.FAULT;

    int fd0, fd1;
    FDFile* f0, f1;
    if (!pipenew(f0, f1))
        return Err.NPIPE;
    scope(exit) if (!success) {
        fdrelease(f0);
        fdrelease(f1);
    }

    fd0 = fdalloc(&p.fdtable);
    if (fd0 < 0)
        return Err.MFILE;
    scope(exit) if (!success) fdremove(&p.fdtable, fd0);

    fd1 = fdalloc(&p.fdtable);
    if (fd1 < 0)
        return Err.MFILE;
    pipefd.fd[0] = fd0;
    pipefd.fd[1] = fd1;
    success = true;
    return 0;
}

uintptr syskill(Proc* p, ulong[6] args) {
    assert(0, "kill");
}

uintptr sysexec(Proc* p, ulong[6] args) {
    assert(0, "exec");
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
