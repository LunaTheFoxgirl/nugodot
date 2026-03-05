/**
    Utilities for wrapping D types for Godot.
*/
module godot.core.wrap;
import godot.core.gdextension;
import godot.core.object;
import godot.core.traits;
import godot.variant;
import numem.core.hooks;
import numem.core.lifetime;


/**
    Godot class startup function type.
*/
alias GDClassStartupFunc = void function() @nogc nothrow;

/**
    Godot class shutdown function type.
*/
alias GDClassShutdownFunc = void function() @nogc nothrow;

private {
    import ldc.attributes;

    // NOTE:    These are linker sections for startup and shutdown
    //          functions.
    //          LLVM will insert these symbols automatically at the
    //          start and end of user set variables at these symbols.

    export extern(C) extern GDClassStartupFunc __start___gde_startup;
    export extern(C) extern GDClassStartupFunc __stop___gde_startup;

    export extern(C) extern GDClassShutdownFunc __start___gde_shutdown;
    export extern(C) extern GDClassShutdownFunc __stop___gde_shutdown;
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
    Gets a GDExtension MethodBindPtr for a given name and hash.

    Params:
        name =      Name of the binding to get.
        hash =      Hash of the binding to get.
    
    Returns:
        A method bind for the given name and hash on success,
        $(D null) otherwise.
*/
GDExtensionMethodBindPtr gde_get_method_bind(ClassT)(string name, long hash) @nogc nothrow {
    auto p_classname = gde_make_string_name(classNameOf!ClassT);
    auto p_methodname = gde_make_string_name(name);
    auto p_method = classdb_get_method_bind(p_classname, p_methodname, hash);
    gde_free_string_name(p_classname);
    gde_free_string_name(p_methodname);
    return p_method;
}

/**
    Gets a GDExtension MethodBindPtr for a given classname, name and hash.

    Params:
        className = Name of the class to get the method bind for.
        name =      Name of the binding to get.
        hash =      Hash of the binding to get.
    
    Returns:
        A method bind for the given classname, name and hash on success,
        $(D null) otherwise.
*/
GDExtensionMethodBindPtr gde_get_method_bind(string className, string name, long hash) @nogc nothrow {
    auto p_classname = gde_make_string_name(className);
    auto p_methodname = gde_make_string_name(name);
    auto p_method = classdb_get_method_bind(p_classname, p_methodname, hash);
    gde_free_string_name(p_classname);
    gde_free_string_name(p_methodname);
    return p_method;
}

/**
    Registers an extension class by name, parent class name and creation info.

    Params:
        className =         Name of the class to register
        parentClassName =   Name of the parent class to register.
        info =              Information to register.
*/
void gde_register_extension_class(string className, string parentClassName, ref GDExtensionClassCreationInfo5 info) @nogc {
    StringName p_classname = className;
    StringName p_parent_classname = parentClassName;
    classdb_register_extension_class5(__godot_class_library, &p_classname, &p_parent_classname, &info);
}

/**
    Unregisters an extension class.
    
    Params:
        className = The name of the extension class to unregister.
*/
void gde_unregister_extension_class(string className) @nogc {
    StringName p_classname = className;
    classdb_unregister_extension_class(__godot_class_library, &p_classname);
}

/**
    Calls a function on a given object object.

    Params:
        obj =       The object to call the method on.
        method =    The method bind instance to call.
        args =      The arguments to the function.

    Returns:
        The return value of the method bind
*/
RetT gde_ptrcall(RetT = void, Args...)(GDExtensionObjectPtr obj, GDExtensionMethodBindPtr method, auto ref Args args) @nogc @system {

    // Fill out arguments
    void*[Args.length] args_;
    static foreach(arg; args) {
        static if (is(typeof(arg) : GDEObject)) {
            args_ = arg.ptr;
        } else {
            args_ = cast(void*)&arg;
        }
    }
    
    // Call
    static if (!is(RetT == void)) {
        static if (is(RetT : GDEObject)) {
            import godot.core.lifetime : gde_get;
            
            GDExtensionObjectPtr objptr_;
            object_method_bind_ptrcall(method, obj, args_.ptr, &objptr_);
            return gde_get!RetT(objptr_);
        } else {
            RetT ret_;
            object_method_bind_ptrcall(method, obj, args_.ptr, &ret_);
            return ret_;
        }
    } else {
        object_method_bind_ptrcall(method, obj, args_.ptr, null);
    }
}

/**
    Gets an instance of the given function for the given type,
    while respecting virtual functions.

    Notes:
        The function returned is stripped of all of its normal attributes,
        this function is **UNSAFE** unless you know what you're doing.

    Params:
        instance =  The class instance.
        method =    The method to get.
*/
auto gde_get_func_instance(T, string method)(Object instance) @system @nogc nothrow {
    alias methodT = __traits(getMember, T, method);
    alias rt = returnTypeOf!methodT function(T, parametersOf!methodT) @nogc nothrow;

    static if (__traits(isVirtualMethod, methodT)) {
        enum vtblOffset = __traits(getVirtualIndex, methodT);
        return (Object p_instance) {
            return cast(rt)p_instance.__vptr[vtblOffset];
        }(cast(Object)instance);
    } else {
        pragma(mangle, methodT.mangleof)
        static extern returnTypeOf!(methodT) __func (T, parametersOf!methodT) @nogc nothrow;

        return cast(rt)&__func;
    }
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
GDExtensionPropertyInfo gde_make_property_info(T)(string name, uint hint = 0, string hintString = null, uint usageFlags = 6) @nogc {
    static if (is(T : GDEObject))
        string class_name = classNameOf!T;
    else
        string class_name;

    StringName* p_name = gde_make_string_name(name);
    StringName* p_classname = gde_make_string_name(class_name);
    String* p_hint_string = gde_make_string(hintString);
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
    gde_free_string_name(cast(StringName*)info.name);
    gde_free_string_name(cast(StringName*)info.class_name);
    gde_free_string(cast(String*)info.hint_string);
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
    } else static if (is(T == RID)) {
        
        variant_from_rid(&result, &value);
    } else static if (is(T : GDEObject)) {

        variant_from_object(&result, value.ptr);
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
    } else static if (is(T == RID)) {
        
        rid_from_variant(&result, &from);
    } else static if (is(T : GDEObject)) {
        GDExtensionObjectPtr _tmp;
        object_from_variant(&_tmp, &from);
        result = gde_get!T(_tmp);
    } else {
        static assert(0, "Unwrapping of type "~T.stringof~" is not currently supported!");
    }
    return result;
}