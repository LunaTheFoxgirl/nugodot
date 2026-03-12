module godot.core.registration;
import godot.core.object;
import godot.core.traits;

/**
    Registration info for a godot class.
*/
struct GDEClassRegistrationInfo {
@nogc:

    /**
        Name of the class.
    */
    string name;

    /**
        XML documentation of the class.
    */
    string docs;

    /**
        Inheritance depth of the registered class.
    */
    size_t inheritDepth;

    /**
        Registration function for the class.
    */
    extern(C) void function() @nogc nothrow registration;

    /**
        Un-registration function for the class.
    */
    extern(C) void function() @nogc nothrow unregistration;
}

/**
    Fetches all of the registration metadata stored for this GDExtension.

    Returns:
        A slice over all the registered extension types..
*/
GDEClassRegistrationInfo[] gde_get_registrations() @nogc nothrow {
    size_t startAddr = cast(size_t)(cast(void*)&__start___gde_registration);
    size_t stopAddr = cast(size_t)(cast(void*)&__stop___gde_registration);
    size_t length = (stopAddr-startAddr);
    return (&__start___gde_registration)[0..(length/GDEClassRegistrationInfo.sizeof)];
}

/**
    Registers a class with Godot's type system.
*/
mixin template GodotClass(T)
if (is(T : GDEObject)) {
    import ldc.attributes;
    import godot.core.traits : getInheritanceDepth;
    import godot.core.registration : GDEClassRegistrationInfo;
    import godot.core.traits : gdeMangleOf, classNameOf, xmldocOf;
    import godot.core.bind : gde_bind_class, gde_unbind_class;

    private __gshared auto _bind_funcinst = &gde_bind_class!T;
    private __gshared auto _unbind_funcinst = &gde_unbind_class!T;

    // Add documentation
    enum XMLDOC = xmldocOf!T;

    @section("__gde_registration")
    pragma(mangle, gdeMangleOf!(T, __registration))
    export GDEClassRegistrationInfo __registration = GDEClassRegistrationInfo(
        name: classNameOf!T,
        inheritDepth: getInheritanceDepth!T,
        docs: XMLDOC.length > 0 ? XMLDOC : null,
        registration: cast(typeof(GDEClassRegistrationInfo.registration))&gde_bind_class!T,
        unregistration: cast(typeof(GDEClassRegistrationInfo.unregistration))&gde_unbind_class!T,
    );
}

private {
    extern(C) extern GDEClassRegistrationInfo __start___gde_registration;
    extern(C) extern GDEClassRegistrationInfo __stop___gde_registration;
}