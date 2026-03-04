/**
    Module which implements the needed infrastructure to wrap
    Godot objects with D objects.
*/
module godot.core.object;
import godot.core.gdextension;
import godot.core.lifetime;
import godot.core.traits;
import godot.core.wrap;
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
        Called by the implementation when initializing the type.
    */
    void onInitialize() { }

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
    final @property GDExtensionObjectPtr ptr() @system => nativePtr_;

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
    Calls a function by name and hash on this object instance.

    This function is provided as an escape hatch if you need
    to call a function not exposed by the API, it is *not*
    optimal.

    Params:
        name = The name of the method to call.
        hash = Hash of the method's signature.
        args = Arguments to pass to the method.
    
    Returns:
        The return value of the method called.
*/
RetT call(RetT = void, ClassT, Args...)(ClassT klass, string name, long hash, auto ref Args args) {
    return gde_ptrcall!(RetT, Args)(klass.ptr, gde_get_method_bind!(ClassT)(name, hash), args);
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
    import godot.core.wrap;
    import godot.core.bind;
    import godot.core.traits;
    
    extern extern(C) GDExtensionBool __gde_class_get_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc nothrow;
    extern extern(C) GDExtensionBool __gde_class_set_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc nothrow;
    extern extern(C) GDExtensionBool __gde_class_property_can_revert_func(void* p_instance, StringName* p_name) @nogc nothrow;
    extern extern(C) GDExtensionBool __gde_class_property_get_revert_func(void* p_instance, StringName* p_name, Variant* p_variant) @nogc nothrow;
    extern extern(C) void __gde_class_notification_func(void* p_instance, int p_what, GDExtensionBool p_reversed) @nogc nothrow;
    extern extern(C) void __gde_class_to_string_func(void* p_instance, GDExtensionBool* r_is_valid, String* r_out) @nogc nothrow;

    //
    //                  IMPLEMENTATION
    //

    static assert(!isGodotNativeClass!T, "Cannot register native godot classes as extension classes!");
    static if (is(T PT == super)) {

        // Startup binding
        @section("__gde_startup")
        pragma(mangle, gdeMangleOf!(T, __gde_class_startup))
        extern(C) GDClassStartupFunc __gde_class_startup = cast(GDClassStartupFunc)&__gde_register;
    
        // Shutdown binding
        @section("__gde_shutdown")
        pragma(mangle, gdeMangleOf!(T, __gde_class_shutdown))
        extern(C) GDClassShutdownFunc __gde_class_shutdown = cast(GDClassShutdownFunc)&__gde_unregister;


        // Registration function
        pragma(mangle, gdeMangleOf!(T, __gde_register))
        extern(C) void __gde_register() @nogc {
            gde_bind_class!T();
        }

        // Unregistration function
        pragma(mangle, gdeMangleOf!(T, __gde_unregister))
        extern(C) void __gde_unregister() @nogc {
            StringName className = classNameOf!T;
            classdb_unregister_extension_class(__godot_class_library, &className);
        }
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