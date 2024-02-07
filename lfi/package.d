module lfi;

alias LFI = void;

alias LFIProc = void;

struct LFIOptions {
    bool noverify;
    bool fastyield;
    usize pagesize;
    usize stacksize;
    ulong function(void*, ulong, ulong[6]) syshandler;
}

struct LFIProcInfo {
    void* stack;
    usize stacksize;
    ulong lastva;
    ulong elfentry;
    ulong elfbase;
    ulong elfphoff;
    ulong elfphnum;
    ulong elfphentsize;
}

enum {
    LFI_VASPACE_MAX = 16,
};

enum {
    LFI_ERR_NOMEM         = -1,
    LFI_ERR_NOSLOT        = -2,
    LFI_ERR_CANNOT_MAP    = -3,
    LFI_ERR_MAX_VASPACE   = -4,
    LFI_ERR_INVALID_ELF   = -5,
    LFI_ERR_VERIFY        = -6,
    LFI_ERR_PROTECTION    = -7,
    LFI_ERR_INVALID_STACK = -8,
};

enum {
    LFI_PROT_NONE  = 0,
    LFI_PROT_READ  = 1,
    LFI_PROT_WRITE = 2,
    LFI_PROT_EXEC  = 4,
};

struct LFIRegs {
    ulong x0;
    ulong x1;
    ulong x2;
    ulong x3;
    ulong x4;
    ulong x5;
    ulong x6;
    ulong x7;
    ulong x8;
    ulong x9;
    ulong x10;
    ulong x11;
    ulong x12;
    ulong x13;
    ulong x14;
    ulong x15;
    ulong x16;
    ulong x17;
    ulong x18;
    ulong x19;
    ulong x20;
    ulong x21;
    ulong x22;
    ulong x23;
    ulong x24;
    ulong x25;
    ulong x26;
    ulong x27;
    ulong x28;
    ulong x29;
    ulong x30;
    ulong sp;
    ulong nzcv;
    ulong fpsr;
    ulong tpidr;
    ulong[64] vector;
};

extern (C) {
    LFI* lfi_new(LFIOptions* options);

    int lfi_auto_add_vaspaces(LFI* lfi);

    int lfi_add_vaspace(LFI* lfi, void* base, usize size);

    ulong lfi_max_procs(LFI* lfi);

    ulong lfi_num_procs(LFI* lfi);

    LFIProc* lfi_add_proc(LFI* lfi, ubyte* prog, usize size, void* ctxp, LFIProcInfo* info, int* err);

    void lfi_remove_proc(LFI* lfi, LFIProc* proc);

    void lfi_delete(LFI* lfi);

    void lfi_proc_start(LFIProc* proc, uintptr entry, void* stack, usize stacksize);

    LFIRegs* lfi_proc_get_regs(LFIProc* proc);

    LFIProc* lfi_proc_copy(LFIProc* proc, void* new_ctxp);

    int lfi_proc_exec(LFIProc* proc, ubyte* prog, usize size, LFIProcInfo* info);

    uintptr lfi_proc_base(LFIProc* proc);
}