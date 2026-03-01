/**
    Bindings and utilities for the GDExtension API.
*/
module godot.core.gdextension;
import godot.core.gdextension.iface;

/**
    The class library which will be set by godot on loading
    your extension.
*/
export GDExtensionClassLibraryPtr __godot_class_library;

/**
    Loads all of the godot extension interface functions.

    Params:
        getProcAddr = The GetProcAddress function godot provides to the extension.
*/
void loadGodot(GDExtensionInterfaceGetProcAddress getProcAddr) @nogc nothrow {
    loadGodotImpl!()(getProcAddr);
}


//
//              IMPLEMENTATION DETAILS
//
private:

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