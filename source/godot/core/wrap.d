/**
    Utilities for wrapping D types for Godot.
*/
module godot.core.wrap;
import godot.core.gdextension;
import godot.core.object;
import godot.core.traits;
import godot.variant;
import numem.core.hooks;


/**
    Godot class startup function type.
*/
alias GDClassStartupFunc = extern(C) void function() @nogc nothrow;

/**
    Godot class shutdown function type.
*/
alias GDClassShutdownFunc = extern(C) void function() @nogc nothrow;

private {
    // NOTE:    These are linker sections for startup and shutdown
    //          functions.
    //          LLVM will insert these symbols automatically at the
    //          start and end of user set variables at these symbols.

    extern(C) extern GDClassStartupFunc __start___gde_startup;
    extern(C) extern GDClassStartupFunc __stop___gde_startup;

    extern(C) extern GDClassShutdownFunc __start___gde_shutdown;
    extern(C) extern GDClassShutdownFunc __stop___gde_shutdown;
}

/**
    Fetches the extension class startup functions from this library.

    All initializers are stored in the `__gde_startup` section.

    Returns:
        A slice over all the functions.
*/
GDClassStartupFunc[] gde_get_class_startup_functions() @nogc nothrow {
    size_t startAddr = cast(size_t)(cast(void*)&__start___gde_startup);
    size_t stopAddr = cast(size_t)(cast(void*)&__stop___gde_startup);
    ptrdiff_t fCount = (stopAddr-startAddr)/(GDClassStartupFunc.sizeof);
    return (&__start___gde_startup)[0..fCount];
}

/**
    Fetches the extension class cleanup functions from this library.

    All initializers are stored in the `__gde_shutdown` section.

    Returns:
        A slice over all the functions.
*/
GDClassShutdownFunc[] gde_get_class_shutdown_functions() @nogc nothrow {
    size_t startAddr = cast(size_t)(cast(void*)&__start___gde_shutdown);
    size_t stopAddr = cast(size_t)(cast(void*)&__stop___gde_shutdown);
    ptrdiff_t fCount = (stopAddr-startAddr)/(GDClassShutdownFunc.sizeof);
    return (&__start___gde_shutdown)[0..fCount];
}

/**
    Wraps a given method of a class with a godot ptrcall wrapper.

    Params:
        T =         The class to wrap a function for
        method =    Alias of the method to wrap.
*/
pragma(inline, true)
GDExtensionClassMethodPtrCall gde_wrap_method_ptrcall(T, alias method)() @nogc
if (is(T : GDEObject)) {
    extern(C) GDExtensionClassMethodPtrCall fn = cast(GDExtensionClassMethodPtrCall)(void* method_userdata, GDExtensionClassInstancePtr p_instance, const(GDExtensionConstTypePtr)* p_args, GDExtensionTypePtr r_ret) @nogc {
        alias ReturnType = returnTypeOf!method;
        alias Params = parametersOf!method;
        
        T obj_ = cast(T)p_instance;

        // Get parameters.
        Params __args;
        static foreach(i; 0..__args.length) {
            __args[i] = *(cast(typeof(__args[i])*)p_args[i]);
        }

        // Call.
        static if (!is(ReturnType == void))
            *(cast(ReturnType*)r_ret) = __traits(getMember, obj_, __traits(identifier, method))(__args);
        else
            __traits(getMember, obj_, __traits(identifier, method))(__args);
    };

    return fn;
}

/**
    Wraps a given method of a class with a godot variant call wrapper.

    Params:
        T =         The class to wrap a function for.
        method =    Alias of the method to wrap.
*/
pragma(inline, true)
GDExtensionClassMethodCall gde_wrap_method_call(T, alias method)() @nogc {
    extern(C) GDExtensionClassMethodCall fn = cast(GDExtensionClassMethodCall)(void* method_userdata, GDExtensionClassInstancePtr p_instance, const(GDExtensionConstVariantPtr)* p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError* r_error) {
        alias ReturnType = returnTypeOf!method;
        alias Params = parametersOf!method;

        // Types
        Params __args;
        T obj_ = cast(T)p_instance;

        // Too few args
        if (p_argument_count < Params.length) {
            r_error.error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
            r_error.expected = Params.length;
            return;
        }

        // Too many arguments.
        if (p_argument_count > Params.length) {
            r_error.error = GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
            r_error.expected = Params.length;
            return;
        }

        // Invalid instance.
        if (!obj_) {
            r_error.error = GDEXTENSION_CALL_ERROR_INSTANCE_IS_NULL;
            return;
        }

        // Type cast variants.
        Variant*[] p_vargs = (cast(Variant**)p_args)[0..p_argument_count];

        // Unwrap the arguments into ones that the DLang side understands.
        static foreach(i; 0..__args.length) {
            __args[i] = gde_unwrap!(typeof(__args[i]))(*p_vargs[i]);
        }

        // Wrap the return value to something that Godot understands, if needed.
        static if (!is(ReturnType == void)) {
            *(cast(Variant*)r_return) = gde_wrap!ReturnType(__traits(getMember, obj_, __traits(identifier, method))(__args));
        } else {
            __traits(getMember, obj_, __traits(identifier, method))(__args);
        }

        static foreach(i; 0..__args.length) {
            variant_destroy(p_vargs[i]);
        }
    };
    
    return fn;
}

/**
    Makes a property info for a given type.

    Params:
        name =          Name for the property.
        hint =          Hint for the property.
        hintString =    Hint string for the property.
        usageFlags =    Usage flags for the property.

    Returns:
        A property info that must be freed with $(D gde_destroy_property_info)
        after use.

    See_Also:
        $(D gde_destroy_property_info)
*/
pragma(inline, true)
GDExtensionPropertyInfo gde_make_property_info(T)(string name, uint hint = 0, string hintString = null, uint usageFlags = 0) @nogc {
    static if (is(T : GDEObject))
        string class_name = classNameOf!T;
    else
        string class_name;

    StringName* p_name = cast(StringName*)nu_malloc(StringName.sizeof);
    string_name_new_with_utf8_chars_and_len(p_name, name.ptr, cast(int)name.length);
    
    StringName* p_classname = cast(StringName*)nu_malloc(StringName.sizeof);
    string_name_new_with_utf8_chars_and_len(p_classname, class_name.ptr, cast(int)class_name.length);

    String* p_hint_string = cast(String*)nu_malloc(String.sizeof);
    string_new_with_utf8_chars_and_len2(p_hint_string, hintString.ptr, cast(int)hintString.length);

    return GDExtensionPropertyInfo(
        type: variantTypeOf!T,
        name: p_name,
        class_name: p_classname,
        hint: hint,
        hint_string: p_hint_string,
        usage: usageFlags,
    );
}

/**
    Destroys a $(D GDExtensionPropertyInfo) created by $(D gde_make_property_info).

    Params:
        info = The property info to destroy.

    See_Also:
        $(D gde_make_property_info)
*/
pragma(inline, true)
void gde_destroy_property_info(ref GDExtensionPropertyInfo info) @nogc {
    if (info.name) {
        string_name_destroy(info.name);
        nu_free(info.name);
        info.name = null;
    }

    if (info.class_name) {
        string_name_destroy(info.class_name);
        nu_free(info.class_name);
        info.class_name = null;
    }

    if (info.hint_string) {
        string_destroy(info.hint_string);
        nu_free(info.hint_string);
        info.hint_string = null;
    }
}

/**
    Wraps the given D type in a variant.

    Params:
        value = The value to wrap.

    Returns:
        The wrapped value.
*/
Variant gde_wrap(T)(auto ref T value) @nogc
if (variantTypeOf!T != GDEXTENSION_VARIANT_TYPE_NIL) {
    import nulib.string;

    Variant result;
    static if (is(T == bool)) {

        variant_from_bool(&result, &value);
    } else static if (__traits(isIntegral, T)) {

        static if (__traits(isUnsigned, T))
            ulong _tmp = cast(ulong)value;
        else
            long _tmp = cast(long)value;
        
        variant_from_int(&result, &_tmp);
    } else static if (__traits(isFloating, T)) {
        
        double _tmp = cast(double)value;
        variant_from_float(&result, &_tmp);
    } else static if(is(T == Vector2)) {

        variant_from_vector2(&result, &value);
    } else static if(is(T == Vector2i)) {

        variant_from_vector2i(&result, &value);
    } else static if(is(T == Vector3)) {

        variant_from_vector3(&result, &value);
    } else static if(is(T == Vector3i)) {

        variant_from_vector3i(&result, &value);
    } else static if(is(T == Vector4)) {

        variant_from_vector4(&result, &value);
    } else static if(is(T == Vector4i)) {

        variant_from_vector4i(&result, &value);
    } else static if (is(T == String)) {
        
        variant_from_string(&result, &value);
    } else static if (is(T == string)) {

        variant_from_string(&result, gde_make_string(value));
    } else static if (is(T == StringName)) {
        
        variant_from_string_name(&result, &value);
    } else static if (is(T : GDEObject)) {

        variant_from_object(&result, value.native_ptr);
    } else {
        static assert(0, "Wrapping of type "~T.stringof~" is not currently supported!");
    }
    return result;
}

/**
    Unwraps the given variant to a D type.

    Params:
        from = The variant to unwrap.

    Returns:
        The unwrapped value.
*/
T gde_unwrap(T)(ref Variant from) @nogc
if (variantTypeOf!T != GDEXTENSION_VARIANT_TYPE_NIL) {
    import godot.core.lifetime : gde_get;
    
    T result;
    static if (is(T == bool)) {
        bool_from_variant(&result, &from);
    } else static if (__traits(isIntegral, T)) {
        static if (__traits(isUnsigned, T))
            ulong _tmp;
        else
            long _tmp;
        
        int_from_variant(&_tmp, &from);
        result = cast(T)_tmp;
    } else static if (__traits(isFloating, T)) {

        double _tmp;
        float_from_variant(&_tmp, &from);
        result = cast(T)_tmp;
    } else static if(is(T == Vector2)) {

        vector2_from_variant(&result, &from);
    } else static if(is(T == Vector2i)) {

        vector2i_from_variant(&result, &from);
    } else static if(is(T == Vector3)) {

        vector3_from_variant(&result, &from);
    } else static if(is(T == Vector3i)) {

        vector3i_from_variant(&result, &from);
    } else static if(is(T == Vector4)) {

        vector4_from_variant(&result, &from);
    } else static if(is(T == Vector4i)) {

        vector4i_from_variant(&result, &from);
    } else static if (is(T == String)) {
        
        string_from_variant(&result, &from);
    } else static if (is(T == StringName)) {
        
        string_name_from_variant(&result, &from);
    } else static if (is(T == string)) {
        
        result = String(from).toString();
    } else static if (is(T : GDEObject)) {
        GDExtensionObjectPtr _tmp;
        object_from_variant(&_tmp, &from);
        result = gde_get!T(_tmp);
    } else {
        static assert(0, "Unwrapping of type "~T.stringof~" is not currently supported!");
    }
    return result;
}



//
//              IMPLEMENTATION DETAILS
//
private:
