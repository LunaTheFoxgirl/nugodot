/**
    Module which implements the needed infrastructure to wrap
    Godot objects with D objects.
*/
module godot.core.gdextension.object;
import godot.core.gdextension.iface;
import godot.core.gdextension.bind;
import godot.core.gdextension.lifetime;
import godot.core.gdextension;
import godot.variant.variant;
import godot.variant.string;
import numem;

/**
    Base class for all wrapped Godot objects.
*/
abstract
class GDEObject : NuObject {
private:
@nogc:
    debug GDExtensionObjectPtr recreateOwner_;
    GDExtensionObjectPtr object_;

protected:

    /**
        Function which must be implemented by subclasses.
    */
    abstract @property const(GDExtensionInstanceBindingCallbacks)* getBindingCallbacks();

    /**
        Constructs the object from a Godot Object pointer.
    */
    this(GDExtensionObjectPtr object) {
        this.object_ = object;
        object_set_instance(object_, className.native_ptr, cast(void*)this);
        object_set_instance_binding(object_, __godot_class_library, cast(void*)this, this.getBindingCallbacks());
    }

    /**
        Constructs the object from a Godot class name.
    */
    this(ref const(StringName) klass) {
        this(classdb_construct_object2(&klass));
    }

public:

    /**
        The static parent class name
    */
    @property ref const(StringName) parentClassName() => this.className;

    /**
        Name of the class.
    */
    @property ref const(StringName) className() {
        static StringName name;
        if (name == StringName.init)
            name = StringName(getGodotClassName!(typeof(this)));
        
        return name;
    }

    /**
        Gets the underlying godot object pointer.
    */
    @property GDExtensionObjectPtr native_ptr() @system => object_;

    /**
        Whether the object is an extension class.
    */
    @property bool isExtensionClass() => false;
}

/**
    Template which implements the neccessities of GDEObject.
*/
mixin template GDClass() {

    /**
        Constructs the class.
    */
    this() {
        super(this.parentClassName);
    }

    /**
        Whether the object is an extension class.
    */
    override @property bool isExtensionClass() => true;

    /**
        The static parent class name
    */
    override @property ref const(StringName) parentClassName() {
        static StringName name;
        if (name == StringName.init)
            name = StringName(getGodotClassName!(typeof(super)));
        
        return name;
    }

    /**
        Name of the class.
    */
    override @property ref const(StringName) className() {
        static StringName name;
        if (name == StringName.init)
            name = StringName(getGodotClassName!(typeof(this)));
        
        return name;
    }

    /**
        Static binding callbacks.
    */
    override @property const(GDExtensionInstanceBindingCallbacks)* getBindingCallbacks() {
        static const typeof(GDExtensionInstanceBindingCallbacks.create_callback) cbCreate = (void*, void*) @nogc { return null; };
        static const typeof(GDExtensionInstanceBindingCallbacks.free_callback) cbFree = (void*, void*, void*) @nogc { };
        static const typeof(GDExtensionInstanceBindingCallbacks.reference_callback) cbReference = (void*, void*, GDExtensionBool) @nogc { return true; };

        __gshared const _gde_binding_callbacks = GDExtensionInstanceBindingCallbacks(
            create_callback: cbCreate,
            free_callback: cbFree,
            reference_callback: cbReference
        );
        return &_gde_binding_callbacks;
    }
}

package(godot)
mixin template GDClassAlias() {

    /**
        The static parent class name
    */
    override @property ref const(StringName) parentClassName() {
        static StringName name;
        if (name == StringName.init)
            name = StringName(getGodotClassName!(typeof(super)));
        
        return name;
    }

    /**
        Name of the class.
    */
    override @property ref const(StringName) className() {
        static StringName name;
        if (name == StringName.init)
            name = StringName(getGodotClassName!(typeof(this)));
        
        return name;
    }

    /**
        Static binding callbacks.
    */
    override @property const(GDExtensionInstanceBindingCallbacks)* getBindingCallbacks() {
        static const typeof(GDExtensionInstanceBindingCallbacks.create_callback) cbCreate = (void* p_token, void* p_instance) {
            return cast(void*)gd_new!(typeof(this))(p_instance);
        };
        static const typeof(GDExtensionInstanceBindingCallbacks.free_callback) cbFree = (void* p_token, void* p_instance, void* p_binding) {
            typeof(this) p_bind = cast(typeof(this))p_binding;
            gd_delete(p_bind);
        };
        static const typeof(GDExtensionInstanceBindingCallbacks.reference_callback) cbReference = (void* p_token, void* p_instance, GDExtensionBool p_reference) {
            return true;
        };

        __gshared const _gde_binding_callbacks = GDExtensionInstanceBindingCallbacks(
            create_callback: cbCreate,
            free_callback: cbFree,
            reference_callback: cbReference
        );
        return &_gde_binding_callbacks;
    }
}

/**
    Validates the correctness of a given class.
*/
template gdValidateClass(T)
if (is(T : GDEObject)) {
    static assert(is(typeof(T.parentClassName)), T.stringof~" does not implement parentClassName!");
    static assert(is(typeof(T.className)), T.stringof~" does not implement className!");
}

/**
    Gets the Godot class name of the given type.
*/
template getGodotClassName(T)
if (is(T : GDEObject)) {
    import godot.core.gdextension.bind : class_name;
    import numem.core.traits : hasUDA, getUDAs;

    static if (hasUDA!(T, class_name)) {
        enum getGodotClassName = getUDAs!(T, class_name)[0].name;
    } else {
        enum getGodotClassName = __traits(identifier, T);
    }
}