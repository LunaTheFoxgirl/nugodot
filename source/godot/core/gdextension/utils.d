module godot.core.gdextension.utils;
import godot.core.gdextension.iface;

alias GDClassStartupFunc = extern(C) void function() @nogc nothrow;
alias GDClassCleanupFunc = extern(C) void function() @nogc nothrow;

/**
    Fetches the extension class startup functions from this library.

    All initializers are stored in the `__gde_startup` section.

    Returns:
        A slice over all the functions.
*/
GDClassStartupFunc[] getExtensionClassStartupFunctions() @nogc nothrow {
    size_t startAddr = cast(size_t)(cast(void*)&__start___gde_startup);
    size_t stopAddr = cast(size_t)(cast(void*)&__stop___gde_startup);
    ptrdiff_t fCount = (stopAddr-startAddr)/((void*).sizeof);
    return (&__start___gde_startup)[0..fCount];
}

/**
    Fetches the extension class cleanup functions from this library.

    All initializers are stored in the `__gde_shutdown` section.

    Returns:
        A slice over all the functions.
*/
GDClassCleanupFunc[] getExtensionClassCleanupFunctions() @nogc nothrow {
    size_t startAddr = cast(size_t)(cast(void*)&__start___gde_shutdown);
    size_t stopAddr = cast(size_t)(cast(void*)&__stop___gde_shutdown);
    ptrdiff_t fCount = (stopAddr-startAddr)/((void*).sizeof);
    return (&__start___gde_shutdown)[0..fCount];
}



//
//              IMPLEMENTATION DETAILS
//
private:

extern(C) extern GDClassStartupFunc __start___gde_startup;
extern(C) extern GDClassStartupFunc __stop___gde_startup;

extern(C) extern GDClassCleanupFunc __start___gde_shutdown;
extern(C) extern GDClassCleanupFunc __stop___gde_shutdown;