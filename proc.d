module proc;

import core.lib;
import core.alloc;
import core.vector;

import sched;
import lfi;
import fd;
import queue;
import elf;
import cwalk;

enum PState {
    RUNNABLE,
    BLOCKED,
    EXITED,
}

enum {
    KSTACKSIZE = 16 * 1024,

    ARGC_MAX = 1024,
    ARGV_MAX = 1024,
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
    Vector!(Proc*) children;
    uintptr brkbase;
    usize brksize;
    Cwd cwd;
    PState state;
    void* wq;
    Proc* next;
    Proc* prev;

    align(16) ubyte[KSTACKSIZE] kstack;
}

Proc* procnewempty() {
    Proc* p = knew!(Proc)();
    if (!p)
        return null;
    p.ctx = taskctx(&p.kstack[$-16], &procentry, &p.kstack[0]);
    p.cwd.fd = AT_FDCWD;
    ensure(getcwd(&p.cwd.name[0], p.cwd.name.length) != null);
    return p;
}

Proc* procnewchild(Proc* parent) {
    Proc* p = procnewempty();
    if (!p)
        return null;
    p.lp = lfi_new_proc();
    if (!p.lp)
        return null;
    if (lfi_proc_copy(lfiengine, &p.lp, parent.lp, p) < 0)
        return null;

    p.base = lfi_proc_base(p.lp);
    fdcopy(&parent.fdtable, p.fdtable);
    p.brkbase = procaddr(p, parent.brkbase);
    p.brksize = parent.brksize;
    p.parent = parent;
    p.state = PState.RUNNABLE;

    return p;
}

Proc* procnewfile(const(char)* path, int argc, const(char)** argv, const(char)** envp) {
    bool success;

    Proc* p = procnewempty();
    if (!p)
        return null;
    scope(exit) if (!success) procfree(p);
    if (!procfile(p, path, argc, argv, envp))
        return null;
    fdinit(&p.fdtable);

    success = true;
    return p;
}

void procfree(Proc* p) {
    if (p.lp)
        lfi_remove_proc(lfiengine, p.lp);
    fdclear(&p.fdtable);
    if (p.cwd.fd >= 0)
        close(p.cwd.fd);
    kfree(p);
}

bool procfile(Proc* p, const(char)* path, int argc, const(char)** argv, const(char)** envp) {
    int fd = openat(p.cwd.fd, path, O_RDONLY, 0);
    if (fd < 0)
        return false;
    void* f = fdopen(fd, "rb");
    if (!f)
        return false;
    ubyte[] buf = readfile(f);
    if (!buf)
        return false;
    ensure(fclose(f) == 0);
    scope(exit) kfree(buf);

    if (!procsetup(p, buf, argc, argv, envp))
        return false;

    return true;
}

bool stacksetup(int argc, const(char)** argv, ref LFIProcInfo info, out uintptr newsp) {
    // Set up argv and envp.
    char*[ARGC_MAX] argv_ptrs;

    void* stack_top = info.stack + info.stacksize;
    char* p_argv = cast(char*) stack_top - PAGESIZE;

    // Write argv string values to the stack.
    for (int i = 0; i < argc; i++) {
        usize len = strnlen(argv[i], ARGV_MAX) + 1;

        if (p_argv + len >= stack_top) {
            return false;
        }

        memcpy(p_argv, argv[i], len);
        p_argv[len - 1] = 0;
        argv_ptrs[i] = p_argv;
        p_argv += len;
    }

    // Write argc and argv pointers to the stack.
    long* p_argc = cast(long*) (stack_top - 2 * PAGESIZE);
    newsp = cast(uintptr) p_argc;
    *p_argc++ = argc;
    char** p_argvp = cast(char**) p_argc;
    for (int i = 0; i < argc; i++) {
        if (cast(uintptr) p_argvp >= cast(uintptr) stack_top - PAGESIZE) {
            return false;
        }
        p_argvp[i] = argv_ptrs[i];
    }
    p_argvp[argc] = null;
    // Empty envp.
    char** p_envp = cast(char**) &p_argvp[argc + 1];
    *p_envp++ = null;

    // Set up auxv.
    Auxv* av = cast(Auxv*) p_envp;
    *av++ = Auxv(AT_SECURE, 0);
    *av++ = Auxv(AT_BASE, info.elfbase);
    *av++ = Auxv(AT_PHDR, info.elfbase + info.elfphoff);
    *av++ = Auxv(AT_PHNUM, info.elfphnum);
    *av++ = Auxv(AT_PHENT, info.elfphentsize);
    *av++ = Auxv(AT_ENTRY, info.elfentry);
    *av++ = Auxv(AT_EXECFN, cast(ulong) p_argvp[0]);
    *av++ = Auxv(AT_PAGESZ, PAGESIZE);
    *av++ = Auxv(AT_NULL, 0);
    return true;
}

bool procsetup(Proc* p, ubyte[] buf, int argc, const(char)** argv, const(char)** envp) {
    bool success;

    LFIProc* lp = lfi_new_proc();
    if (!lp)
        return false;
    scope(exit) if (!success) free(lp);

    LFIProcInfo info;
    int err = lfi_add_proc(lp, lfiengine, buf.ptr, buf.length, p, &info);
    if (!lp)
        return false;
    p.lp = lp;
    p.base = lfi_proc_base(lp);

    uintptr sp;
    stacksetup(argc, argv, info, sp);

    lfi_proc_init_regs(lp, info.elfentry, sp);

    p.brkbase = info.lastva;

    p.state = PState.RUNNABLE;

    success = true;

    return true;
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
    lfi_proc_start(p.lp);
}

void procexec(Proc* p) {
    p.ctx = taskctx(&p.kstack[$-16], &procentry, &p.kstack[0]);
    kstart(null, null, &schedctx);
}

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

int procchdir(Proc* p, const(char)* path) {
    int fd = openat(p.cwd.fd, path, O_DIRECTORY | O_PATH, 0);
    if (fd < 0)
        return fd;
    if (p.cwd.fd >= 0)
        close(p.cwd.fd);

    if (!cwk_path_is_absolute(path)) {
        char[PATH_MAX] buffer;
        cwk_path_join(p.cwd.name.ptr, path, buffer.ptr, buffer.length);
        path = buffer.ptr;
    }
    memcpy(p.cwd.name.ptr, path, p.cwd.name.length);
    p.cwd.fd = fd;
    return 0;
}
