module proc;

import core.lib;

import sched;
import lfi;
import fd;
import queue;

enum PState {
    RUNNABLE,
    BLOCKED,
}

struct Cwd {
    char[PATH_MAX] name;
    int fd;
}

struct Proc {
    Context ctx;
    LFIProc* lp;
    uintptr base;
    FDTable fdtable;
    Proc* parent;
    uintptr brkp;
    Cwd cwd;
    PState state;
    void* wq;
    Proc* next;
    Proc* prev;
}

Proc* procempty() {
    return null;
}

Proc* procfile(const(char)* path, int argc, const(char)** argv, const(char)** envp) {
    return null;
}

Proc* procparent(Proc* parent) {
    return null;
}

bool procsetup(Proc* p, ubyte[] buf, int argc, const(char)** argv, const(char)** envp) {
    return false;
}

void procyield(Proc* p) {
    kswitch(null, &p.ctx, &schedctx);
}

void procblock(Proc* p, Queue* q, PState s) {
    p.state = s;
    p.wq = q;
    qpushf(q, p);
    procyield(p);
}

void procentry(Proc* p) {
    // lfi_proc_start(p.lp, p.);
}

// void procexec(Proc* p) {
//     p.ctx = taskctx(p.kstackp, &procentry, p.kstackbase);
//     kstart(null, null, &schedctx);
// }

int procpid(Proc* p) {
    return cast(int) (p.base >> 32);
}

uintptr procaddr(Proc* p, uintptr addr) {
    return (cast(uint) addr) | p.base;
}

ubyte[] procbuf(Proc* p, uintptr buf, usize size) {
    buf = procaddr(p, buf);
    // TODO: checks
    return (cast(ubyte*) buf)[0 .. size];
}

const(char)* procpath(Proc* p, uintptr path) {
    path = procaddr(p, path);
    // TODO: checks
    const(char)* str = cast(const(char)*) path;
    usize len = strnlen(str, PATH_MAX);
    if (str[len] != 0)
        return null;
    return str;
}

T* procobj(T)(Proc* p, uintptr ptr) {
    ubyte[] buf = procbuf(p, ptr, T.sizeof);
    return cast(T*) buf.ptr;
}
