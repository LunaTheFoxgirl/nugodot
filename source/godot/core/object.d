/**
    Module which implements the needed infrastructure to wrap
    Godot objects with D objects.
*/
module godot.core.object;
import godot.core.gdextension;
import godot.core.lifetime;
import godot.core.traits;
import godot.core;
import godot.variant.variant;
import godot.variant.string;
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

        // NOTE:    Allocate and base-initialize the class.
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
    Registers a class with Godot.
*/
template GodotClass(T)
if (is(T : GDEObject)) {
    import ldc.attributes;
    import godot.core.gdextension;
    import godot.core.lifetime;
    import godot.core.traits;
    import godot.core.wrap;
    import godot.core;
    import godot.variant.string;

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

        alias propType = getPropertyType!(T, memberName);
        alias propFuncs = getPropertyFunctions!(T, memberName);
        enum propHasGetter = !is(propFuncs[0] == void);
        enum propHasSetter = !is(propFuncs[1] == void);

        alias memberRef = mixin(T, ".", memberName);
        
        static if (propHasGetter) {
            enum getterName = "_get_"~gdMemberName;
            gde_bind_method!(T, propFuncs[0])(getterName);
        } else {
            enum getterName = "";
        }

        static if (propHasSetter) {
            enum setterName = "_set_"~gdMemberName;
            gde_bind_method!(T, propFuncs[1])(setterName);
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


    //
    //                  IMPLEMENTATION
    //

    static assert(!isGodotNativeClass!T, "Cannot register native godot classes as extension classes!");
    static if (is(T PT == super)) {

        // Instance constructor forwarder.
        pragma(mangle, gdeMangleOf!(T, __gde_class_create))
        extern(C) GDExtensionObjectPtr __gde_class_create(void* p_userdata, GDExtensionBool p_postinit) @nogc {
            StringName parentClassName = classNameOf!PT;
            void* pObject = classdb_construct_object2(&parentClassName);
            cast(void)gde_alloc_class!T(pObject);
            return pObject;
        }

        // Instance free forwarder.
        pragma(mangle, gdeMangleOf!(T, __gde_class_free))
        extern(C) void __gde_class_free(void* p_userdata, GDExtensionClassInstancePtr p_instance) @nogc {
            GDEObject pObject = cast(GDEObject)p_instance;
            nogc_delete(pObject);
        }

        // Instance recreate forwarder.
        pragma(mangle, gdeMangleOf!(T, __gde_class_recreate))
        extern(C) GDExtensionClassInstancePtr __gde_class_recreate(void* p_userdata, GDExtensionObjectPtr p_object) @nogc {
            return cast(GDExtensionClassInstancePtr)gde_alloc_class!T(p_object);
        }

        // Registration function
        pragma(mangle, gdeMangleOf!(T, __gde_register))
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
                static foreach(member; boundMethodsOf!T) {
                    gde_bind_member!(T, member)();
                }
            }
        }

        // Registration function
        pragma(mangle, gdeMangleOf!(T, __gde_unregister))
        extern(C) void __gde_unregister() @nogc {
            StringName className = classNameOf!T;
            classdb_unregister_extension_class(__godot_class_library, &className);
        }

        @section("__gde_startup")
        pragma(mangle, gdeMangleOf!(T, __gde_class_startup))
        extern(C) GDClassStartupFunc __gde_class_startup = cast(GDClassStartupFunc)&__gde_register;
    
        @section("__gde_shutdown")
        pragma(mangle, gdeMangleOf!(T, __gde_class_shutdown))
        extern(C) GDClassShutdownFunc __gde_class_shutdown = cast(GDClassShutdownFunc)&__gde_unregister;
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




// 
// These functions implement forwarders for basic godot class functions  
// They just forward calls to the GDEObject class type.
// 

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