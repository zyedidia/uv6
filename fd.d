module fd;

import core.lib;
import core.alloc;

import file;
import proc;

struct FDFile {
    void* dev;
    usize refs;
    ssize function(void*, Proc*, ubyte[]) read;
    ssize function(void*, Proc*, ubyte[]) write;
    ssize function(void*, Proc*, ssize, uint) lseek;
    int function(void*, Proc*) close;
    int function(void*, Proc*, Stat*) stat;
}

enum {
    NOFILE = 128,
}

struct FDTable {
    FDFile*[NOFILE] files;
}

void fdassign(FDTable* t, int fd, FDFile* ff) {
    ff.refs++;
    t.files[fd] = ff;
}

int fdalloc(FDTable* t) {
    int i;
    for (i = 0; i < t.files.length; i++) {
        if (t.files[i] == null)
            break;
    }
    if (i >= t.files.length)
        return -1;
    return i;
}

FDFile* fdget(FDTable* t, int fd) {
    if (fdhas(t, fd)) {
        return t.files[fd];
    }
    return null;
}

bool fdremove(FDTable* t, int fd) {
    if (fdhas(t, fd)) {
        t.files[fd].refs--;
        if (t.files[fd].refs == 0)
            kfree(t.files[fd]);
        t.files[fd] = null;
        return true;
    }
    return false;
}

bool fdhas(FDTable* t, int fd) {
    return fd >= 0 && fd < t.files.length && t.files[fd] != null;
}

void fdcopy(FDTable* t, ref FDTable to) {
    assert(t.files.length == to.files.length);

    for (int i = 0; i < t.files.length; i++) {
        if (t.files[i] != null) {
            t.files[i].refs++;
            to.files[i] = t.files[i];
        }
    }
}

void fdclear(FDTable* t) {
    for (int fd = 0; fd < t.files.length; fd++) {
        fdremove(t, fd);
    }
}

void fdinit(FDTable* t) {
    fdassign(t, 0, filenew(fileno(stdin)));
    fdassign(t, 1, filenew(fileno(stdout)));
    fdassign(t, 2, filenew(fileno(stderr)));
}
