module godot.variant.signal;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;
import godot.core.wrap;
import godot.core.traits;
import godot.core.object;
import godot.variant.array;
import godot.variant.callable;
import godot.variant.string;

/**
    A godot signal
*/
struct Signal(Args...) {
private:
@nogc:
    void[VARIANT_SIZE_SIGNAL] data_;

public:

    /// Type of arguments to the signal.
    alias ArgsT = Args;

    /// Destructor
    ~this() {
        signal_destroy(&this);
    }

    /**
        Constructs a new signal from an existing signal.

        Params:
            signal = The signal to construct this one from.
    */
    this(Signal signal) {
        gde_bind_and_call_ctor!(typeof(this), 1)(this, signal);
    }

    /**
        Constructs a new signal from the object and its signal name.

        Params:
            object = The owning object
            signal = The name of the signal.
    */
    this(GDEObject object, StringName signal) {
        gde_bind_and_call_ctor!(typeof(this), 2)(this, object.ptr, signal);
    }

    /**
        Whether the signal is null
    */
    @property bool isNull() => cast(bool)gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "is_null", 3918633141, bool)(&this);

    /**
        Whether the signal has any connections
    */
    @property bool hasConnections() => gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "has_connections", 3918633141, bool)(&this);

    /**
        The name of this signal
    */
    @property StringName name() => gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "get_name", 1825232092, StringName)(&this);

    /**
        The Object this signal applies to.
    */
    @property GDEObject object() => gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "get_object", 4008621732, GDEObject)(&this);

    /**
        The ID of the object this signal applies to.
    */
    @property GDExtensionInt objectId() => gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "get_object_id", 3173160232, GDExtensionInt)(&this);

    /**
        Gets the active connections of the signal.

        Returns:
            An array of variants containing the active
            signal connections.
    */
    Array getConnections() {
        return gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "get_connections", 4144163970, Array)(&this);
    }

    /**
        Gets whether the signal is connected to the given callable.

        Params:
            callable = The callable to query.
        
        Returns:
            $(D true) if the signal is connected,
            $(D false) otherwise.
    */
    bool isConnectedTo(Callable callable) {
        return gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "is_connected", 4129521963, bool)(&this, callable);
    }

    /**
        Connects a callable to the signal.

        Params:
            callable =  The callable to connect.
            flags =     The flags for the connection, of type $(D Object.ConnectFlags)
        
        Returns:
            $(D Error.OK) on success, 
            Any other $(D Error) otherwise.
    */
    int connect(Callable callable, GDExtensionInt flags = 0) {
        return cast(int)gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "connect", 979702392, GDExtensionInt)(&this, callable, flags);
    }

    /**
        Disconnects a callable from the signal.

        Params:
            callable =  The callable to disconnect.
    */
    void disconnect(Callable callable) {
        gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_SIGNAL, "disconnect", 3470848906)(&this, callable);
    }

    /**
        Emits the signal

        Params:
            args = The arguments to pass to the signal
    */
    void emit(Args args) {
        __gshared GDExtensionPtrBuiltInMethod __bind;
        if (!__bind)
            __bind = gde_get_builtin_method(GDEXTENSION_VARIANT_TYPE_SIGNAL, "emit", 3286317445);
        
        void*[Args.length] __params;
        static foreach_reverse(i, arg; args) {
            static if (is(typeof(param) : GDEObject))
                __params[i] = arg.ptr;
            else
                __params[i] = &arg;
        }

        __bind(&this, __params.ptr, null, cast(int)Args.length);
    }

    /**
        Alias for $(D emit).

        Params:
            args = The arguments to pass to the signal

        See_Also:
            $(D emit)
    */
    void opCall(Args args) {
        this.emit(args);
    }
}