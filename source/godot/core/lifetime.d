module godot.core.lifetime;
import godot.core.gdextension;
import godot.core.object;
import godot.core.traits;
import godot.variant;

import numem.core.math;
import numem.lifetime;

/**
    Constructs a new type using the godot allocator.

    Params:
        args = arguments to pass to the type's constructor.

    Returns:
        A new object of the given type.
*/
Ref!T gd_new(T, Args...)(Args args) @safe @nogc {
    static if (is(T : GDEObject)) {
        static if (isGodotNativeClass!T) {

            // Base godot objects.
            StringName className = StringName(classNameOf!T);
            auto ptr = classdb_construct_object2(&className);
            return gde_get!T(ptr);

        } else static if (is(T PT == super)) {
    
            // Extension objects.
            StringName parentClassName = StringName(classNameOf!PT);
            auto ptr = classdb_construct_object2(&parentClassName);
            auto obj_ = gde_get!T(ptr);

            // Call our constructor.
            obj_.__ctor(args);
            return obj_;
        } else {
            static assert(0, "No super class was found for the type?!");
        }
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
void gd_delete(T)(ref Ref!T value) @safe @nogc {
    static if (is(T : GDEObject)) {
        object_destroy(value.value_ptr);
    }
    nogc_delete(value);
}

/**
    Gets a GDE Object from its native pointer.

    Note:
        This does not call the class constructor.
        The class must be able to work with the
        class initializer.

        Abstract classes cannot be wrapped.

    Params:
        ptr =   The native Godot pointer.
    
    Returns:
        The wrapped object, either fetched directly from the object
        or wrapped on the spot if no bindings were found.
*/
T gde_get(T)(GDExtensionObjectPtr ptr) @safe @nogc
if (is(T : GDEObject)) {

    // Object already has a binding, return it.
    if (auto obj = cast(T)object_get_instance_binding(ptr, __godot_class_library, null))
        return obj;
    
    // Object needs to be allocated.
    return gde_alloc_class!T(ptr);
}