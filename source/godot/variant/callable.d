module godot.variant.callable;
import godot.variant.string;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;
import godot.core.traits;
import godot.core.wrap;

/**
    A callable.
*/
struct Callable {
private:
@nogc:
    void[VARIANT_SIZE_CALLABLE] data_;
    
    /**
        Creates a new callable that calls a method on a given variant.

        Params:
            variant =   The variant to create a callable for
            method =    The method
        
        Returns:
            A $(D Callable).
    */
    static Callable create(T)(auto ref T variant, string method)
    if (variantTypeOf!T != GDEXTENSION_VARIANT_TYPE_NIL) {
        Variant p_variant = gde_wrap!T(variant);
        StringName p_method_name = StringName(method);
        auto p_callable = gde_bind_and_call!(GDEXTENSION_VARIANT_TYPE_CALLABLE, "create", 1709381114, Callable)(null, p_variant, p_method_name);
        return p_callable;
    }
    
    /**
        Calls the callable with the given arguments.
    */
    RetT call(RetT, Args...)(Args args) {
        __gshared GDExtensionPtrBuiltInMethod __bind;
        if (!__bind)
            __bind = gde_get_builtin_method(GDEXTENSION_VARIANT_TYPE_CALLABLE, "call", 3643564216);
        
        void*[Args.length] __params;
        static foreach_reverse(i, arg; args) {
            static if (is(typeof(param) : GDEObject))
                __params[i] = arg.ptr;
            else
                __params[i] = &arg;
        }

        static if (!is(RetT == void)) {
            RetT rval = void;

            __bind(ptr, __params.ptr, &rval, cast(int)Args.length);
            return rval;
        } else {
            __bind(ptr, __params.ptr, null, cast(int)Args.length);
        }
    }

    /**
        Alias for $(D call)

        See_Also:
            $(D call)
    */
    RetT opCall(RetT, Args...)(Args args) {
        return this.call!(RetT, Args)(args);
    }
}