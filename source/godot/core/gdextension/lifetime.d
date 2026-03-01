module godot.core.gdextension.lifetime;
import godot.core.gdextension.iface;
import godot.core.gdextension.object;
import godot.variant.string;
import numem.core.traits;
import numem.lifetime;



/**
    Constructs a new type using the godot allocator.

    Params:
        args = arguments to pass to the type's constructor.
*/
Ref!T gd_new(T, Args...)(Args args) @nogc {
    static if (is(T : GDEObject)) {
        // GDStringName name = 
    } else {
        Ref!T mem = cast(Ref!T)mem_alloc2(AllocSize!T, true);
        nogc_construct(mem, args);
        return mem;
    }
}

/**
    Frees a given godot object.

    Params:
        value = The given value to free.
*/
void gd_delete(T)(ref Ref!T value) @nogc {
    nogc_delete(value);
}