/**
    Bindings and utilities for the GDExtension API.
*/
module godot.core.gdextension;
import godot.core.registration;

public import godot.core.gdextension.iface;
public import godot.core.gdextension.variant_size;

/**
    The class library which will be set by godot on loading
    your extension.
*/
export __gshared GDExtensionClassLibraryPtr __godot_class_library;

/**
    Loads all of the godot extension interface functions.

    Params:
        getProcAddr = The GetProcAddress function godot provides to the extension.
*/
void loadGodot(GDExtensionInterfaceGetProcAddress getProcAddr) @nogc nothrow {
    loadGodotImpl!()(getProcAddr);
}

/**
    Injected entrypoint of your godot plugin.

    You do not need to call this yourself, godot calls it for you.
*/
extern(C) export GDExtensionBool __gde_library_initialize(GDExtensionInterfaceGetProcAddress p_get_proc_address, GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) @nogc nothrow {
    __godot_class_library = p_library;
    loadGodot(p_get_proc_address);

    r_initialization.initialize = &__gde_extension_init;
    r_initialization.deinitialize = &__gde_extension_shutdown;
    r_initialization.minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
    
    return true;
}

//
//              IMPLEMENTATION DETAILS
//
private:

// Gets the next depth value to instantiate.
size_t getNextDepth(size_t current, GDEClassRegistrationInfo[] classes) @nogc nothrow {
    size_t lowest = size_t.max;
    foreach(klass; classes) {
        if (klass.inheritDepth > current && klass.inheritDepth < lowest)
            lowest = klass.inheritDepth;
    }
    return lowest;
}

extern(C) void __gde_extension_init(void *p_userdata, GDExtensionInitializationLevel p_level) @nogc nothrow {
    if (p_level == GDEXTENSION_INITIALIZATION_SCENE) {
        GDEClassRegistrationInfo[] classes = gde_get_registrations();
        size_t loaded = 0;
        size_t toLoad = 0;
        while(loaded < classes.length) {
            toLoad = toLoad.getNextDepth(classes);
            foreach(klass; classes) {
                if (klass.inheritDepth == toLoad) {
                    klass.registration();
                    loaded++;
                }
            }
        }
    }
}

extern(C) void __gde_extension_shutdown(void *p_userdata, GDExtensionInitializationLevel p_level) @nogc nothrow {
    if (p_level == GDEXTENSION_INITIALIZATION_SCENE) {
        foreach(klass; gde_get_registrations()) {
            klass.unregistration();
        }
    }
}

template loadGodotImpl() {
    import godot.core.gdextension.iface;
    import std.meta;

    enum isFuncMember(alias member) = is(typeof(mixin(member))) && is(typeof(mixin(member)) == return);
    enum _FUNCS = Filter!(isFuncMember, __traits(allMembers, godot.core.gdextension.iface));
    alias _MAINFUNCS = AliasSeq!(_FUNCS[0..staticIndexOf!("register_main_loop_callbacks", _FUNCS)+1]);

    template stripEnumPrefix(string prefix) {
        enum pref_ = "GDEXTENSION_VARIANT_TYPE_";
        enum stripEnumPrefix = prefix[pref_.length..$];
    }

    template toLower(string value) {
        import str = std.string;
        enum toLower = str.toLower(value);
    }

    template nVariantFromFunc(string name) {
        enum nVariantFromFunc = "variant_from_"~toLower!(stripEnumPrefix!(name));
    }

    template nFromVariantFunc(string name) {
        enum nFromVariantFunc = toLower!(stripEnumPrefix!(name))~"_from_variant";
    }

    template nDestroyFunc(string name) {
        enum nDestroyFunc = toLower!(stripEnumPrefix!(name))~"_destroy";
    }

    pragma(inline, true)
    void loadGodotImpl(GDExtensionInterfaceGetProcAddress getProcAddr) @nogc nothrow {
        static foreach(func; _MAINFUNCS) {
            mixin(func) = cast(typeof(mixin(func)))getProcAddr(func);
        }

        static foreach(vt; __traits(allMembers, GDExtensionVariantType)[1..$-1]) {
            mixin(nVariantFromFunc!(vt)) = cast(typeof(mixin(nVariantFromFunc!(vt))))get_variant_from_type_constructor(mixin(vt));
            mixin(nFromVariantFunc!(vt)) = cast(typeof(mixin(nFromVariantFunc!(vt))))get_variant_to_type_constructor(mixin(vt));
    
            // object_destroy is handled elsewhere, ¯\_(ツ)_/¯
            static if(toLower!(stripEnumPrefix!(vt)) != "object")
                mixin(nDestroyFunc!(vt)) = cast(typeof(mixin(nDestroyFunc!(vt))))variant_get_ptr_destructor(mixin(vt));
        }
    }
}