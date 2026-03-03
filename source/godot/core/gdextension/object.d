/**
    Module which implements the needed infrastructure to wrap
    Godot objects with D objects.
*/
module godot.core.gdextension.object;
import godot.core.gdextension.lifetime;
import godot.core.gdextension.iface;
import godot.core.gdextension;
import godot.variant.variant;
import godot.variant.string;
import numem.core.traits;
import numem;

/**
    Specifies the name a class should be bound as.
*/
struct class_name { string name; } // @suppress(dscanner.style.phobos_naming_convention)

/**
    Specifies the icon to use for the type.
*/
struct class_icon { string path; }

/**
    Exports a given property in the inspector.
*/
struct gd_export; // @suppress(dscanner.style.phobos_naming_convention)module godot.core.gde.object;

/**
    Base class for all wrapped Godot objects.

    Godot Objects *must* be constructed with `gde_new`!
*/
abstract
class GDEObject : NuObject {
private:
@nogc:
    GDExtensionObjectPtr nativePtr_;

protected:

    /**
        Called by the implementation before initializing the type.
    */
    void onPreInitialize() { }

    /**
        Called by the implementation after initializing the type.
    */
    void onPostInitialize() { }

    /**
        Called when the object gets a notification.

        Params:
            what =      What notification was recieved.
            reversed =  Whether the order of operations is reversed.
    */
    void onNotification(int what, bool reversed) { }

public:

    /**
        Gets the underlying godot object pointer.
    */
    final @property GDExtensionObjectPtr native_ptr() @system => nativePtr_;

    /**
        Sets the given property to the given value.

        Params:
            name =  The name of the property.
            value = The value to set.
        
        Returns:
            Whether the operation succeeded.
    */
    bool set(in StringName name, in Variant value) { return false; }

    /**
        Sets the given property to the given value.

        Params:
            name =  The name of the property.
            dest =  The destination value to store the value in. 
        
        Returns:
            Whether the operation succeeded.
    */
    bool get(in StringName name, ref Variant dest) { return false; }

    /**
        Gets whether a property with the given name can be
        reverted.

        Params:
            name = The name of the property.
        
        Returns:
            $(D true) if the property can be reverted,
            $(D false) otherwise.
    */
    bool canRevertProperty(in StringName name) { return false; }

    /**
        Gets the value the given named property will be reverted to.

        Params:
            name = The name of the property.
            dest =  The destination value to store the value in. 
        
        Returns:
            $(D true) if the operation succeded,
            $(D false) otherwise.
    */
    bool getPropertyRevert(in StringName name, ref Variant dest) { return false; }

    /**
        Gets a string representation of this type.
    */
    override string toString() { return typeid(this).name; }
}

/**
    Allocates a class for the given type and object pointer.

    Params:
        ptr = The object pointer to associate with the class.
    
    Returns:
        A newly allocated wrapper class.
*/
T gde_alloc_class(T)(GDExtensionObjectPtr ptr) @system @nogc
if (is(T : GDEObject)) {
    import numem.core.hooks : nu_malloc, nu_memcpy;

    static if (!__traits(isAbstractClass, T)) {

        // NOTE:    Allocate and base initialize the class.
        //          This will NOT call any constructors.
        const void[] __initSym = __traits(initSymbol, T);
        T obj = cast(T)nu_malloc(AllocSize!T);
        nu_memcpy(cast(void*)obj, cast(void*)__initSym.ptr, __initSym.length);
        (cast(GDEObject)obj).nativePtr_ = ptr;
        
        // Apply our wrapper to the object.
        StringName __className = StringName(classNameOf!T);
        object_set_instance(ptr, &__className, cast(void*)obj);
        object_set_instance_binding(ptr, __godot_class_library, cast(void*)obj, &__nu_gde_instance_callbacks!T);
        return obj;
    } else {

        assert(0, "Tried to instantiate an abstract class!");
        return null;
    }
}

/**
    Gets the icon path for a given Godot class.
*/
template getClassIconPath(T) {
    static if(is(T : GDEObject) && hasUDA!(T, class_icon)) {
        enum string getClassIconPath = getUDAs!(T, class_icon)[0].path;
    } else {
        enum string getClassIconPath = null;
    }
}

/**
    Gets the Godot class name of the given type.
*/
template classNameOf(T)
if (is(T : GDEObject)) {
    import godot.core.gdextension.object : class_name;
    import numem.core.traits : hasUDA, getUDAs;

    static if (hasUDA!(T, class_name)) {
        enum classNameOf = getUDAs!(T, class_name)[0].name;
    } else {
        enum classNameOf = __traits(identifier, T);
    }
}

/**
    Gets whether the given class is a native godot class.
    This is determined by whether the class is located
    within the `godot.` module.
*/
template isGodotNativeClass(T) {
    enum GODOT_MODULE_PATH = "godot.";
    enum FQN = __traits(fullyQualifiedName, T);
    
    enum FQN_PREFIX = FQN[0..nu_min(FQN.length, GODOT_MODULE_PATH.length)];
    enum isGodotNativeClass = FQN_PREFIX == GODOT_MODULE_PATH;
}

/**
    Registers a class with Godot.
*/
template GodotClass(T)
if (is(T : GDEObject)) {
    import ldc.attributes;
    import godot.core.gdextension.iface;
    import godot.core.gdextension.lifetime;
    import godot.core.gdextension : __godot_class_library;
    import godot.core.gdextension.utils : GDClassStartupFunc, GDClassCleanupFunc;
    import numem.core.hooks : nu_malloc, nu_free;
    import numem : nogc_new, nogc_delete;

    
    extern extern(C) GDExtensionBool __gde_class_get_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc nothrow;
    extern extern(C) GDExtensionBool __gde_class_set_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc nothrow;
    extern extern(C) GDExtensionBool __gde_class_property_can_revert_func(void* p_instance, StringName* p_name) @nogc nothrow;
    extern extern(C) GDExtensionBool __gde_class_property_get_revert_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc nothrow;
    extern extern(C) void __gde_class_notification_func(void* p_instance, int p_what, GDExtensionBool p_reversed) @nogc nothrow;
    extern extern(C) void __gde_class_to_string_func(void* p_instance, GDExtensionBool* r_is_valid, String* r_out) @nogc nothrow;



    //
    //                  HELPER TEMPLATES.
    //

    private template getMemberFuncs(T) {
        import numem.core.math : nu_min;
        import numem.core.meta : Filter;
        import numem.core.traits : FunctionTypeOf;

        enum isMethod(alias member) = is(FunctionTypeOf!(mixin(T, ".", member)) == return) && !(member[0..nu_min(2, member.length)] == "__");
        alias getMemberFuncs = Filter!(isMethod, __traits(derivedMembers, T));
    }

    private template isPropertyFunc(alias func) {
        import numem.core.meta : Filter;

        enum isPropertyAttrib(string attrib) = attrib == "@property";
        enum isPropertyFunc = Filter!(isPropertyAttrib, __traits(getFunctionAttributes, func)).length != 0;
    }

    private template methodFlagsOf(alias func) {
        enum uint methodFlagsOf = 
            GDEXTENSION_METHOD_FLAG_NORMAL | 
            (__traits(isStaticFunction, func) ? cast(uint)GDEXTENSION_METHOD_FLAG_STATIC : 0) |
            (__traits(isAbstractFunction, func) ? cast(uint)GDEXTENSION_METHOD_FLAG_VIRTUAL_REQUIRED : 0) |
            (__traits(isVirtualMethod, func) ? cast(uint)GDEXTENSION_METHOD_FLAG_VIRTUAL : 0);
    }

    private template getGetterFunc(T, alias name) {
        import numem.core.traits : ReturnType, Parameters;
        import numem.core.meta : Filter;

        enum isGetterFunc(alias func) = Parameters!(func).length == 0 && !is(ReturnType!(func) == void);
        alias getterFunc = Filter!(isGetterFunc, __traits(getOverloads, T, name));

        static if (getterFunc.length > 0)
            alias getGetterFunc = getterFunc[0];
    }

    private template getSetterFunc(T, alias name) {
        import numem.core.traits : ReturnType, Parameters;
        import numem.core.meta : Filter;

        enum isSetterFunc(alias func) = Parameters!(func).length == 1;
        alias setterFunc = Filter!(isSetterFunc, __traits(getOverloads, T, name));

        static if (setterFunc.length > 0)
            alias getSetterFunc = setterFunc[0];
    }

    private template getPropertyType(T, alias name) {
        import numem.core.traits : ReturnType, Parameters;

        static if (is(typeof(mixin(T, ".", name)))) {
            alias getPropertyType = typeof(mixin(T, ".", name));
        } else static if (Parameters!(getSetterFunc!(T, name)).length == 1) {
            alias getPropertyType = Parameters!(getSetterFunc!(T, name))[0];
        } else {
            static assert(0, "No valid getters or setters found for property ", name, "!");
        }
    }

    private template toSnakeCase(string value) {
        enum toSnakeCase = (string v) {
            if (__ctfe) {
                import std.uni : isUpper, toLower;

                string out_;
                foreach(c; v) {
                    if (isUpper(c)) {
                        out_ ~= "_";
                        out_ ~= toLower(c);
                        continue;
                    }

                    out_ ~= c;
                }
                return out_;
            }
            return null;
        }(value);
    }

    pragma(inline, true)
    private void gde_bind_member(T, alias member)() @nogc {
        static if (isPropertyFunc!(mixin(T, ".", member))) {
            gde_bind_property!(T, member)();
        } else {
            gde_bind_method!(T, mixin(T, ".", member))();
        }
    }

    pragma(inline, true)
    private void gde_bind_method(T, alias method)(string name = null) @nogc {
        import numem.core.traits : ReturnType, Parameters;

        enum paramCount = Parameters!method.length;
        enum methodName = toSnakeCase!(__traits(identifier, method));

        StringName p_classname = StringName(classNameOf!T);
        StringName p_methodname = StringName(name ? name : methodName);
        GDExtensionClassMethodArgumentMetadata[paramCount] p_param_metas;
        GDExtensionPropertyInfo[paramCount] p_params;
        GDExtensionClassMethodArgumentMetadata p_return_meta;
        GDExtensionPropertyInfo p_return;
        GDExtensionClassMethodFlags p_methodflags = 
            cast(GDExtensionClassMethodFlags)methodFlagsOf!(method);

        // Fill out parameters.
        static foreach(i, param; Parameters!method) {
            static if (is(__traits(identifier, param))) {
                p_params[i] = gde_make_property_info!(param)(__traits(identifier, param));
            } else {
                p_params[i] = gde_make_property_info!(param)("_param_"~(cast(int)i).stringof);
            }
        }

        static if (!is(ReturnType!method == void))
            p_return = gde_make_property_info!(ReturnType!method)("");

        // Registration
        GDExtensionClassMethodInfo p_methodinfo = GDExtensionClassMethodInfo(
            name: &p_methodname,
            call_func: gde_wrap_method_call!(T, method)(),
            ptrcall_func: gde_wrap_method_ptrcall!(T, method)(),
            method_flags: p_methodflags,
            has_return_value: !is(ReturnType!method == void),
            return_value_info: &p_return,
            return_value_metadata: p_return_meta,
            argument_count: cast(int)paramCount,
            arguments_info: p_params.ptr,
            arguments_metadata: p_param_metas.ptr,
        );
        classdb_register_extension_class_method(__godot_class_library, &p_classname, &p_methodinfo);

        // Clean up parameters.
        static foreach(i; 0..paramCount)
            gde_destroy_property_info(p_params[i]);
    }


    pragma(inline, true)
    private void gde_bind_property(T, alias memberName)() @nogc {
        import numem.core.traits : ReturnType, Parameters, FunctionTypeOf;
        
        StringName p_classname = StringName(classNameOf!T);
        enum gdMemberName = toSnakeCase!(memberName);

        alias memberRef = mixin(T, ".", memberName);
        alias propType = getPropertyType!(T, memberName);
        enum propHasGetter = is(typeof(() => mixin(T, ".init.", memberName, "()")));
        enum propHasSetter = is(typeof(() => mixin(T, ".init.", memberName, "(", propType, ".init", ")")));
        
        static if (propHasGetter) {
            enum getterName = "_get_"~gdMemberName;
            gde_bind_method!(T, getGetterFunc!(T, memberName))(getterName);
        } else {
            enum getterName = "";
        }

        static if (propHasSetter) {
            enum setterName = "_set_"~gdMemberName;
            gde_bind_method!(T, getSetterFunc!(T, memberName))(setterName);
        } else {
            enum setterName = "";
        }

        StringName* p_getter_name = gde_make_string_name(getterName);
        StringName* p_setter_name = gde_make_string_name(setterName);

        auto p_prop_info = gde_make_property_info!propType(gdMemberName);
        classdb_register_extension_class_property(__godot_class_library, &p_classname, &p_prop_info, p_setter_name, p_getter_name);
        gde_destroy_property_info(p_prop_info);

        gde_free_string_name(p_getter_name);
        gde_free_string_name(p_setter_name);
    }

    pragma(inline, true)
    private GDExtensionClassMethodPtrCall gde_wrap_method_ptrcall(T, alias method)() @nogc {
        import numem.core.traits;
        import numem.core.meta;
        
        return cast(GDExtensionClassMethodPtrCall)(void* method_userdata, GDExtensionClassInstancePtr p_instance, const(GDExtensionConstTypePtr)* p_args, GDExtensionTypePtr r_ret) @nogc {
            static if (is(ReturnType!(mixin(method))))
                alias returnType = ReturnType!(mixin(method));
            else
                alias returnType = void;
            
            T obj_ = cast(T)p_instance;
            Parameters!(method) __args;
            static foreach(i; 0..__args.length) {
                __args[i] = *(cast(typeof(__args[i])*)p_args[i]);
            }

            static if (!is(returnType == void))
                *(cast(returnType*)r_ret) = __traits(getMember, obj_, __traits(identifier, method))(__args);
            else
                __traits(getMember, obj_, __traits(identifier, method))(__args);
        };
    }

    pragma(inline, true)
    private GDExtensionClassMethodCall gde_wrap_method_call(T, alias method)() @nogc {
        import numem.core.traits;
        import numem.core.meta;

        return cast(GDExtensionClassMethodCall)(void* method_userdata, GDExtensionClassInstancePtr p_instance, const(GDExtensionConstVariantPtr)* p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError* r_error) {
            static if (is(ReturnType!(FunctionTypeOf!method)))
                alias returnType = ReturnType!(FunctionTypeOf!method);
            else
                alias returnType = void;

            enum paramCount = Parameters!(method).length;

            // Types
            Parameters!(method) __args;
            T obj_ = cast(T)p_instance;

            // Too few args
            if (p_argument_count < paramCount) {
                r_error.error = GDEXTENSION_CALL_ERROR_TOO_FEW_ARGUMENTS;
                r_error.expected = paramCount;
                return;
            }

            // Too many arguments.
            if (p_argument_count > paramCount) {
                r_error.error = GDEXTENSION_CALL_ERROR_TOO_MANY_ARGUMENTS;
                r_error.expected = paramCount;
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
                __args[i] = unwrap!(typeof(__args[i]))(*p_vargs[i]);
            }

            // Wrap the return value to something that Godot understands, if needed.
            static if (!is(returnType == void)) {
                *(cast(Variant*)r_return) = wrap!returnType(__traits(getMember, obj_, __traits(identifier, method))(__args));
            } else {
                __traits(getMember, obj_, __traits(identifier, method))(__args);
            }

            static foreach(i; 0..__args.length) {
                variant_destroy(p_vargs[i]);
            }
        };
    }

    pragma(inline, true)
    private GDExtensionPropertyInfo gde_make_property_info(T)(string name, uint hint = 0, string hintString = null, uint usageFlags = 0) @nogc {
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

    pragma(inline, true)
    private StringName* gde_make_string_name(string value) @nogc {
        StringName* result = cast(StringName*)nu_malloc(StringName.sizeof);
        string_name_new_with_utf8_chars_and_len(result, value.ptr, cast(int)value.length);
        return result;
    }

    pragma(inline, true)
    private void gde_free_string_name(ref StringName* name) @nogc {
        string_name_destroy(name);
        nu_free(name);
        name = null;
    }

    pragma(inline, true)
    private String* gde_make_string(string value) @nogc {
        String* result = cast(String*)nu_malloc(String.sizeof);
        string_new_with_utf8_chars_and_len2(result, value.ptr, cast(int)value.length);
        return result;
    }

    pragma(inline, true)
    private void gde_free_string(ref String* str) @nogc {
        string_destroy(str);
        nu_free(str);
        str = null;
    }


    //
    //                  IMPLEMENTATION
    //

    static assert(!isGodotNativeClass!T, "Cannot register native godot classes as extension classes!");
    static if (is(T PT == super)) {

        // Instance constructor forwarder.
        pragma(mangle, "__gde_class_create_"~classNameOf!T)
        extern(C) GDExtensionObjectPtr __gde_class_create(void* p_userdata, GDExtensionBool p_postinit) @nogc {
            StringName parentClassName = classNameOf!PT;
            void* pObject = classdb_construct_object2(&parentClassName);
            cast(void)gde_alloc_class!T(pObject);
            return pObject;
        }

        // Instance free forwarder.
        pragma(mangle, "__gde_class_free_"~classNameOf!T)
        extern(C) void __gde_class_free(void* p_userdata, GDExtensionClassInstancePtr p_instance) @nogc {
            GDEObject pObject = cast(GDEObject)p_instance;
            nogc_delete(pObject);
        }

        // Instance recreate forwarder.
        pragma(mangle, "__gde_class_recreate_"~classNameOf!T)
        extern(C) GDExtensionClassInstancePtr __gde_class_recreate(void* p_userdata, GDExtensionObjectPtr p_object) @nogc {
            return cast(GDExtensionClassInstancePtr)gde_alloc_class!T(p_object);
        }

        // Registration function
        pragma(mangle, "__gde_class_register_"~classNameOf!T)
        extern(C) void __gde_register() @nogc {
            static if (getClassIconPath!T !is null) {
                __gshared String __gde_icon_path;
                String* __gde_icon_path_ptr = &__gde_icon_path;
            } else {
                String* __gde_icon_path_ptr = null;
            }

            enum hasGetOverride = __traits(isOverrideFunction, T.get);
            enum hasSetOverride = __traits(isOverrideFunction, T.set);
            enum hasCanRevertOverride = __traits(isOverrideFunction, T.canRevertProperty);
            enum hasGetPropertyRevertOverride = __traits(isOverrideFunction, T.getPropertyRevert);

            static if (is(T PT == super)) {
                GDExtensionClassCreationInfo5 classInfo = GDExtensionClassCreationInfo5(
                    is_virtual: false,
                    is_abstract: __traits(isAbstractClass, T),
                    is_exposed: true,
                    is_runtime: true,
                    icon_path: __gde_icon_path_ptr,
                    notification_func: cast(typeof(GDExtensionClassCreationInfo5.notification_func))&__gde_class_notification_func,
                    to_string_func: cast(typeof(GDExtensionClassCreationInfo5.to_string_func))&__gde_class_to_string_func,
                    create_instance_func: cast(typeof(GDExtensionClassCreationInfo5.create_instance_func))&__gde_class_create,
                    free_instance_func: cast(typeof(GDExtensionClassCreationInfo5.free_instance_func))&__gde_class_free,
                    recreate_instance_func: cast(typeof(GDExtensionClassCreationInfo5.recreate_instance_func))&__gde_class_recreate,

                    // Optional overrides.
                    set_func:
                        hasGetOverride ? cast(typeof(GDExtensionClassCreationInfo5.set_func))&__gde_class_set_func : null,
                    get_func:
                        hasSetOverride ? cast(typeof(GDExtensionClassCreationInfo5.get_func))&__gde_class_get_func : null,
                    property_can_revert_func:
                        hasCanRevertOverride ? cast(typeof(GDExtensionClassCreationInfo5.property_can_revert_func))&__gde_class_property_can_revert_func : null,
                    property_get_revert_func:
                        hasGetPropertyRevertOverride ? cast(typeof(GDExtensionClassCreationInfo5.property_get_revert_func))&__gde_class_property_get_revert_func : null,
                );

                // Register class
                StringName className = classNameOf!T;
                StringName pClassName = classNameOf!PT;
                classdb_register_extension_class5(__godot_class_library, &className, &pClassName, &classInfo);

                // Bind methods and properties.
                static foreach(member; getMemberFuncs!T) {
                    gde_bind_member!(T, member)();
                }
            }
        }

        // Registration function
        pragma(mangle, "__gde_class_unregister_"~classNameOf!T)
        extern(C) void __gde_unregister() @nogc {
            StringName className = classNameOf!T;
            classdb_unregister_extension_class(__godot_class_library, &className);
        }

        @section("__gde_startup")
        pragma(mangle, "__gde_class_startup_"~classNameOf!T)
        extern(C) GDClassStartupFunc __startup_func = cast(GDClassStartupFunc)&__gde_register;
    
        @section("__gde_shutdown")
        pragma(mangle, "__gde_class_shutdown_"~classNameOf!T)
        extern(C) GDClassCleanupFunc __shutdown_func = cast(GDClassCleanupFunc)&__gde_unregister;
    }
}

//
//              IMPLEMENTATION DETAILS
//
private:

template __nu_gde_instance_callbacks(T) {
    static if (isGodotNativeClass!T) {
        pragma(mangle, "__nu_gde_create_callback_"~__traits(identifier, T))
        extern(C) void __nu_gde_create_callback(void *p_token, void *p_instance) @nogc {
            return gde_alloc_class!T(p_instance);
        }

        pragma(mangle, "__nu_gde_free_callback_"~__traits(identifier, T))
        extern(C) void __nu_gde_free_callback(void *p_token, void *p_instance, void *p_binding) @nogc {
            GDEObject object = cast(GDEObject)p_binding;
            nogc_delete(object);
        }

        pragma(mangle, "__nu_gde_reference_callback_"~__traits(identifier, T))
        extern(C) void __nu_gde_reference_callback(void *p_token, void *p_instance, GDExtensionBool p_reference) @nogc {
            return true;
        }

        pragma(mangle, "__nu_gde_instance_callbacks_"~__traits(identifier, T))
        extern(C) __gshared const GDExtensionInstanceBindingCallbacks __nu_gde_instance_callbacks = GDExtensionInstanceBindingCallbacks(
            create_callback: &__nu_gde_create_callback,
            free_callback: &__nu_gde_free_callback,
            reference_callback: &__nu_gde_reference_callback
        );
    } else {
        pragma(mangle, "__nu_gde_create_callback_"~__traits(identifier, T))
        extern(C) void* __nu_gde_create_callback(void *p_token, void *p_instance) @nogc {
            return null;
        }

        pragma(mangle, "__nu_gde_free_callback_"~__traits(identifier, T))
        extern(C) void __nu_gde_free_callback(void *p_token, void *p_instance, void *p_binding) @nogc {
        }

        pragma(mangle, "__nu_gde_reference_callback_"~__traits(identifier, T))
        extern(C) GDExtensionBool __nu_gde_reference_callback(void *p_token, void *p_instance, GDExtensionBool p_reference) @nogc {
            return true;
        }

        extern(C) __gshared GDExtensionInstanceBindingCallbacks __nu_gde_instance_callbacks = GDExtensionInstanceBindingCallbacks(
            create_callback: cast(typeof(GDExtensionInstanceBindingCallbacks.create_callback))&__nu_gde_create_callback,
            free_callback: cast(typeof(GDExtensionInstanceBindingCallbacks.free_callback))&__nu_gde_free_callback,
            reference_callback: cast(typeof(GDExtensionInstanceBindingCallbacks.reference_callback))&__nu_gde_reference_callback
        );
    }
}

// Following is C functions that forward 

extern(C) GDExtensionBool __gde_class_get_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc {
    return (cast(GDEObject)p_instance).get(*p_name, *p_variant);
}

extern(C) GDExtensionBool __gde_class_set_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc {
    return (cast(GDEObject)p_instance).set(*p_name, *p_variant);
}

extern(C) GDExtensionBool __gde_class_property_can_revert_func(void* p_instance, StringName* p_name) @nogc {
    return (cast(GDEObject)p_instance).canRevertProperty(*p_name);
}

extern(C) GDExtensionBool __gde_class_property_get_revert_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc {
    return (cast(GDEObject)p_instance).getPropertyRevert(*p_name, *p_variant);
}

extern(C) void __gde_class_notification_func(void* p_instance, int p_what, GDExtensionBool p_reversed) @nogc {
    (cast(GDEObject)p_instance).onNotification(p_what, cast(bool)p_reversed);
}

extern(C) void __gde_class_to_string_func(void* p_instance, GDExtensionBool* r_is_valid, String* r_out) @nogc {
    if (p_instance) {
        *r_out = String((cast(GDEObject)p_instance).toString());
        *r_is_valid = true;
        return;
    }

    *r_is_valid = false;
}