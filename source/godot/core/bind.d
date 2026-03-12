module godot.core.bind;
import godot.core.gdextension;
import godot.core.lifetime;
import godot.core.traits;
import godot.core.wrap;
import godot.core;
import godot.variant;
import godot.globals;
import godot.resource;

import numem.core.hooks : nu_malloc, nu_free;
import numem : nogc_new, nogc_delete;

/**
    Binds a class and registers it with Godot.

    You generally do not need to call this yourself.
*/
extern(C) void gde_bind_class(T)() @nogc 
if (is(T : GDEObject)) {

    // Get icon of the class
    static if (getClassIconPath!T !is null) {
        __gshared String __gde_icon_path;
        String* __gde_icon_path_ptr = &__gde_icon_path;
    } else {
        String* __gde_icon_path_ptr = null;
    }


    alias ctors = gdeClassCtors!T;

    enum hasGetOverride = __traits(isOverrideFunction, T.get);
    enum hasSetOverride = __traits(isOverrideFunction, T.set);
    enum hasCanRevertOverride = __traits(isOverrideFunction, T.canRevertProperty);
    enum hasGetPropertyRevertOverride = __traits(isOverrideFunction, T.getPropertyRevert);
    enum hasNotificationOverride = __traits(isOverrideFunction, __traits(getMember, T, "onNotification"));
    
    static if (is(T PT == super)) {
        GDExtensionClassCreationInfo5 classInfo = GDExtensionClassCreationInfo5(
            is_virtual: false,
            is_abstract: __traits(isAbstractClass, T),
            is_exposed: true,
            is_runtime: true,
            icon_path: __gde_icon_path_ptr,
            to_string_func: cast(typeof(GDExtensionClassCreationInfo5.to_string_func))&__gde_class_to_string_func,
            create_instance_func: cast(typeof(GDExtensionClassCreationInfo5.create_instance_func))&ctors.__gde_class_create,
            free_instance_func: cast(typeof(GDExtensionClassCreationInfo5.free_instance_func))&ctors.__gde_class_free,
            recreate_instance_func: cast(typeof(GDExtensionClassCreationInfo5.recreate_instance_func))&ctors.__gde_class_recreate,

            // Optional overrides.
            notification_func: 
                hasNotificationOverride ? cast(typeof(GDExtensionClassCreationInfo5.notification_func))&__gde_class_notification_func : null,
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
        gde_register_extension_class(classNameOf!T, classNameOf!PT, classInfo);

        // Bind members
        static foreach(member; boundMembersOf!T) {
            gde_bind_member!(T, member)();
        }

        // Bind constructors
        static if (is(typeof(T.__ctor))) {
            gde_bind_ctors!T();
        }
    }
}

void gde_unbind_class(T)() @nogc {
    gde_unregister_extension_class(classNameOf!T);
}



//
//                  IMPLEMENTATION DETAILS
//
private:

template gdeClassCtors(T) 
if (is(T : GDEObject)) {
    static if (is(T PT == super)) {

        // Instance constructor forwarder.
        pragma(mangle, gdeMangleOf!(T, __gde_class_create))
        extern(C) __gshared GDExtensionObjectPtr __gde_class_create(void* p_userdata, GDExtensionBool p_postinit) @nogc {
            StringName parentClassName = classNameOf!PT;
            void* pObject = classdb_construct_object2(&parentClassName);
            cast(void)gde_alloc_class!T(pObject);

            if (p_postinit) {
                auto p_bind = gde_get_method_bind("Object", "notification", GDEXTENSION_NOTIFICATION_FUNC_HASH);
                gde_ptrcall(pObject, p_bind, 0, false);
            }
            return pObject;
        }

        // Instance free forwarder.
        pragma(mangle, gdeMangleOf!(T, __gde_class_free))
        extern(C) __gshared void __gde_class_free(void* p_userdata, GDExtensionClassInstancePtr p_instance) @nogc {
            if (GDEObject pObject = cast(GDEObject)p_instance)
                nogc_delete(pObject);
        }

        // Instance recreate forwarder.
        pragma(mangle, gdeMangleOf!(T, __gde_class_recreate))
        extern(C) __gshared GDExtensionClassInstancePtr __gde_class_recreate(void* p_userdata, GDExtensionObjectPtr p_object) @nogc {
            return cast(GDExtensionClassInstancePtr)gde_alloc_class!T(p_object);
        }
    }
}

void gde_bind_member(T, alias member)() @nogc
if (is(T : GDEObject)) {
    static if (isConstant!(T, member)) {
        gde_bind_const!(T, member);
    } else static if (isPropertyFunc!(T, member)) {
        gde_bind_property!(T, member);
    } else static if (isMethod!(T, member)) {
        gde_bind_method!(T, __traits(getMember, T, member))();
    } else {
        pragma(msg, "Could not bind "~member.stringof~"...");
    }
}

void gde_bind_method(T, alias method)(string name = null) @nogc
if (is(T : GDEObject)) {
    enum paramCount = parametersOf!(method).length;
    enum methodName = methodNameOf!method;
    string method_name = name ? name : methodName;
    string class_name = classNameOf!T;

    StringName p_classname = StringName(class_name);
    StringName p_methodname = StringName(method_name);
    GDExtensionClassMethodArgumentMetadata[paramCount] p_param_metas;
    GDExtensionPropertyInfo[paramCount] p_params;
    GDExtensionClassMethodArgumentMetadata p_return_meta;
    GDExtensionPropertyInfo p_return;
    GDExtensionClassMethodFlags p_methodflags = 
        cast(GDExtensionClassMethodFlags)methodFlagsOf!(method);

    // Fill out parameters.
    static foreach(i, param; parametersOf!method) {
        static if (is(__traits(identifier, param))) {
            p_params[i] = gde_make_property_info!(param)(__traits(identifier, param));
        } else {
            p_params[i] = gde_make_property_info!(param)("param"~(cast(int)i).stringof);
        }
    }

    static if (!is(returnTypeOf!method == void))
        p_return = gde_make_property_info!(ReturnType!method)("");

    // Registration
    GDExtensionClassMethodInfo p_methodinfo = GDExtensionClassMethodInfo(
        name: &p_methodname,
        call_func: gde_wrap_method_call!(T, method)(),
        ptrcall_func: gde_wrap_method_ptrcall!(T, method)(),
        method_flags: cast(uint)p_methodflags,
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

void gde_bind_ctors(T)() @nogc {
    alias __dctors = __traits(getOverloads, T, "__ctor");
    static if (__dctors.length == 1) {
        gde_bind_method!(T, __dctors[0])("_init");
    }

    // TODO: bind ctors with more 
}

void gde_bind_property(T, alias memberName)() @nogc {

    StringName p_classname = StringName(classNameOf!T);
    enum gdMemberName = toSnakeCase!(memberName);

    alias propType = getPropertyType!(T, memberName);
    alias propFuncs = getPropertyFunctions!(T, memberName);
    enum propHasGetter = !is(propFuncs[0] == void);
    enum propHasSetter = !is(propFuncs[1] == void);

    alias memberRef = __traits(getMember, T, memberName);
    
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
    
    static if (is(propType : Resource)) {

        // NOTE:    Resources need to be provided with a hint to get the correct resource type
        //          showing in the editor list.
        auto p_prop_info = gde_make_property_info!propType(gdMemberName, PROPERTY_HINT_RESOURCE_TYPE, classNameOf!propType);
        classdb_register_extension_class_property(__godot_class_library, &p_classname, &p_prop_info, p_setter_name, p_getter_name);
        gde_destroy_property_info(p_prop_info);

    } else {
    
        auto p_prop_info = gde_make_property_info!propType(gdMemberName);
        classdb_register_extension_class_property(__godot_class_library, &p_classname, &p_prop_info, p_setter_name, p_getter_name);
        gde_destroy_property_info(p_prop_info);
    }

    gde_free_string_name(p_getter_name);
    gde_free_string_name(p_setter_name);
}

void gde_bind_const(T, alias memberName)() @nogc {
    alias member = __traits(getMember, T, memberName);
    StringName p_classname = StringName(classNameOf!T);
    StringName p_enumname;
    StringName p_constname;
    GDExtensionInt p_value;
    
    static if (is(typeof(member) == enum)) {
        
        // Enums
        p_enumname = StringName(__traits(identifier, member));
        static foreach(enumMember; __traits(getMembers, member)) {
            p_constname = StringName(toScreamingSnakeCase!(__traits(identifier, enumMember)));
            p_value = cast(GDExtensionInt)__traits(getMember, T, memberName);
            classdb_register_extension_class_integer_constant(__godot_class_library, &p_classname, &p_enumname, &p_constname, p_value, false);
        }
    } else {

        // Manifest constants and consts
        p_constname = StringName(toScreamingSnakeCase!(__traits(identifier, member)));
        p_value = cast(GDExtensionInt)__traits(getMember, T, memberName);
        classdb_register_extension_class_integer_constant(__godot_class_library, &p_classname, &p_enumname, &p_constname, p_value, false);
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
    auto p_obj = cast(GDEObject)p_instance;
    gde_get_func_instance!(GDEObject, "onNotification")(p_obj)(p_obj, p_what, cast(bool)p_reversed);
}

extern(C) void __gde_class_to_string_func(void* p_instance, GDExtensionBool* r_is_valid, String* r_out) @nogc {
    if (p_instance) {
        *r_out = String((cast(GDEObject)p_instance).toString());
        *r_is_valid = true;
        return;
    }

    *r_is_valid = false;
}