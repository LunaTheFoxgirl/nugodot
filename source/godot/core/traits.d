/**
    Traits for Godot type introspection.
*/
module godot.core.traits;
import godot.core.gdextension;
import godot.core.object;
import godot.core.wrap;
import godot.core.attribs;

public import numem.core.traits;
public import numem.core.meta;
public import numem.core.math;

/**
    Gets the godot XML documentation for the given class.

    Params:
        T = The type to get the Godot xml documentation of.
*/
template xmldocOf(T) 
if (is(T : GDEObject)) {
    static if (is(typeof(import(classNameOf!(T)~".xml")))) {
        enum string xmldocOf = import(classNameOf!(T)~".xml");
    } else {
        enum string xmldocOf = "";
    }
}

/**
    Gets the Godot class name of the given type.

    Params:
        T = The type to get the Godot classname of.
*/
template classNameOf(T)
if (is(T : GDEObject)) {
    static if (hasUDA!(T, class_name)) {
        enum classNameOf = getUDAs!(T, class_name)[0].name;
    } else {
        enum classNameOf = __traits(identifier, T);
    }
}

/**
    Gets the name of a method.
*/
enum methodNameOf(alias method) = godotNameOf!(method, true);

/**
    Gets the name of a signal.
*/
enum signalNameOf(alias signal) = godotNameOf!(signal, true);

/**
    Gets the Godot name of a given symbol based on the
    symbol's name or its gd_name annotation.

    Params:
        method =    The symbol to get the name of.
        recursive = Whether subclasses should be recursed through.
*/
template godotNameOf(alias symbol, bool recursive) {
    static if (is(typeof(symbol) : GDEObject)) {
        enum godotNameOf = classNameOf!(typeof(symbol));
    } else static if (hasUDA!(symbol, gd_name)) {
        enum godotNameOf = getUDAs!(symbol, gd_name)[0].name;
    } else static if (__traits(isOverrideFunction, symbol)) {
        static if (is(__traits(parent, symbol) PT == super)) {
            enum godotNameOf = godotNameOf!(__traits(getMember, PT, __traits(identifier, symbol)), recursive);
        }
    } else {
        enum godotNameOf = toSnakeCase!(__traits(identifier, symbol));
    }
}

/**
    Gets the variant type tag of the given D type.

    Params:
        T = The type to get the variant type of.
*/
template variantTypeOf(T) {
    import godot.variant;

    static if (is(T == bool))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_BOOL;
    else static if (__traits(isIntegral, T))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_INT;
    else static if (__traits(isFloating, T))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_FLOAT;
    else static if (is(T == String) || is(T == string))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_STRING;
    else static if (is(T == Vector2))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_VECTOR2;
    else static if (is(T == Vector2i))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_VECTOR2I;
    else static if (is(T == Rect2))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_RECT2;
    else static if (is(T == Rect2i))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_RECT2I;
    else static if (is(T == Vector3))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_VECTOR3;
    else static if (is(T == Vector3i))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_VECTOR3I;
    else static if (is(T == Transform2D))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_TRANSFORM2D;
    else static if (is(T == Vector4))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_VECTOR4;
    else static if (is(T == Vector4i))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_VECTOR4I;
    else static if (is(T == Plane))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PLANE;
    else static if (is(T == Quaternion))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_QUATERNION;
    else static if (is(T == AABB))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_AABB;
    else static if (is(T == Basis))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_BASIS;
    else static if (is(T == Transform3D))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_TRANSFORM3D;
    else static if (is(T == Projection))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PROJECTION;
    else static if (is(T == Color))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_COLOR;
    else static if (is(T == StringName))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_STRING_NAME;
    else static if (is(T == NodePath))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_NODE_PATH;
    else static if (is(T == RID))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_RID;
    else static if (is(T : GDEObject))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_OBJECT;
    else static if (is(T == Callable))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_CALLABLE;
    else static if (is(T == Signal!U, U...))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_SIGNAL;
    else static if (is(T == TypedDictionary!U, U...))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_DICTIONARY;
    else static if (is(T == TypedArray!U, U))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_ARRAY;
    else static if (is(Unref!T == PackedByteArray))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_BYTE_ARRAY;
    else static if (is(Unref!T == PackedInt32Array))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_INT32_ARRAY;
    else static if (is(Unref!T == PackedInt64Array))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_INT64_ARRAY;
    else static if (is(Unref!T == PackedFloat32Array))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT32_ARRAY;
    else static if (is(Unref!T == PackedFloat64Array))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_FLOAT64_ARRAY;
    else static if (is(Unref!T == PackedVector2Array))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR2_ARRAY;
    else static if (is(Unref!T == PackedVector3Array))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR3_ARRAY;
    else static if (is(Unref!T == PackedVector4Array))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_VECTOR4_ARRAY;
    else static if (is(Unref!T == PackedColorArray))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_COLOR_ARRAY;
    else static if (is(Unref!T == PackedStringArray))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_PACKED_STRING_ARRAY;
    else static if (is(T == Variant))
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_VARIANT_MAX;
    else
        enum variantTypeOf = GDEXTENSION_VARIANT_TYPE_NIL;
}

/**
    Gets the inheritance depth of a given type.
*/
template getInheritanceDepth(T)
if (is(T : GDEObject)) {
    static if (is(T == GDEObject)) {
        enum getInheritanceDepth = 0;
    } else static if (is(T PT == super)) {
        enum getInheritanceDepth = getInheritanceDepth!(PT)+1;
    } else {
        enum getInheritanceDepth = -1;
    }
}

/**
    Gets whether the given class is a native godot class.
    This is determined by whether the class is located
    within the `godot.` module.
*/
template isGodotNativeClass(T) 
if (is(T : GDEObject)) {
    enum GODOT_MODULE_PATH = "godot.";
    enum FQN = __traits(fullyQualifiedName, T);
    
    enum FQN_PREFIX = FQN[0..nu_min(FQN.length, GODOT_MODULE_PATH.length)];
    enum isGodotNativeClass = FQN_PREFIX == GODOT_MODULE_PATH;
}

/**
    Gets the icon path for a given Godot class.

    Params:
        T = The class to get the icon path for.
    
    Returns:
        A string with the icon path.
*/
template getClassIconPath(T)
if (is(T : GDEObject)) {
    static if(hasUDA!(T, class_icon)) {
        enum string getClassIconPath = getUDAs!(T, class_icon)[0].path;
    } else {
        enum string getClassIconPath = null;
    }
}

/**
    Gets whether the given function is a property function.

    Params:
        func = Alias to the function to test.
*/
template isPropertyFunc(T, alias func) {
    enum isPropertyAttrib(string attrib) = attrib == "@property";
    enum isPropertyFunc = isMethod!(T, func) && Filter!(isPropertyAttrib, __traits(getFunctionAttributes, __traits(getMember, T, func))).length != 0;
}

/**
    Gets whether the given member is a method.

    Params:
        T =     The class to check
        func =  Name of the member
*/
template isMethod(T, string member) {
    enum isMethod = is(typeof(__traits(getMember, T, member)) == return) ||
        is(FunctionTypeOf!(__traits(getMember, T, member)) == return);
}

/**
    Gets whether the given member is a godot constant.

    Params:
        T =     The class to check
        func =  Name of the member
*/
template isConstant(T, string member) {
    alias MT = typeof(__traits(getMember, T, member));

    static if (is(MT MTY == enum)) {
        enum isConstant = __traits(isIntegral, MTY);
    } else static if (is(typeof(() => __traits(getMember, T, member)))) {
        enum isConstant = __traits(isIntegral, MT);
    } else {
        enum isConstant = false;
    }
}

/**
    Gets whether the given member symbol is a signal.

    Params:
        T =         The owning class of the member.
        member =    Name of the member
*/
template isSignal(T, string member) {
    import godot.variant : Signal;
    enum isSignal = is(typeof(__traits(getMember, T, member)) == Signal!U, U...);
}

/**
    Gets the getter and setter functions for a given property name.

    Params:
        T =             The GDEObject derived class to get properties for.
        memberName =    The name of the property to get the functions for.
    
    Returns:
        An alias sequence with a getter and setter; if a function isn't found
        its type will be `void`.
*/
template getPropertyFunctions(T, alias memberName)
if (is(T : GDEObject)) {
    alias getPropertyFunctions = AliasSeq!(getGetterFunc!(T, memberName), getSetterFunc!(T, memberName));
}

/**
    Gets the type of a property within a class.

    Params:
        T =             The GDEObject derived class to get properties for.
        memberName =    The name of the property to get the type for.
*/
template getPropertyType(T, alias memberName) 
if (is(T : GDEObject)) {
    static if (is(typeof(mixin(T, ".", memberName)))) {
        alias getPropertyType = typeof(mixin(T, ".", memberName));
    } else static if (parametersOf!(getSetterFunc!(T, memberName)).length == 1) {
        alias getPropertyType = parametersOf!(getSetterFunc!(T, memberName))[0];
    } else {
        alias getPropertyType = void;
    }
}

/**
    Gets an alias sequence of the methods that are bound for a given class.
    
    Notes:
        Valid methods are determined by a few factors:
        $(P
            1. Methods must be derived (declared in the class).
            2. Methods must **not** start with $(D_INLINECODE __)
            3. Methods must be callable.
            4. Methods must be protected or public
        )

    Params:
        T = The GDEObject derived class to get methods for.
*/
template boundMethodsOf(T) 
if (is(T : GDEObject)) {
    enum isMethod(string memberName) = is(FunctionTypeOf!(__traits(getMember, T, memberName)) == return);
    alias boundMethodsOf = Filter!(isMethod, boundMembersOf!T);
}

/**
    Gets an alias sequence of the signals that are bound for a given class.

    Params:
        T = The GDEObject derived class to get signals for.
*/
template boundSignalsOf(T) 
if (is(T : GDEObject)) {
    import godot.variant : Signal;

    enum isSignal(string memberName) = is(typeof(__traits(getMember, T, memberName)) == Signal!U, U...);
    alias boundSignalsOf = Filter!(isSignal, boundMembersOf!T);
}

/**
    Gets an alias sequence of the members that are bound for a given class.
    
    Notes:
        Valid members are determined by a few factors:
        $(P
            1. Members must be derived (declared in the class).
            2. Members must **not** start with $(D_INLINECODE __)
            3. Members must be protected or public
        )

    Params:
        T = The GDEObject derived class to get members for.
*/
template boundMembersOf(T) 
if (is(T : GDEObject)) {
    template isAllowedMember(alias memberName) {
        enum visibility = __traits(getVisibility, __traits(getMember, T, memberName));

        enum isVisible = (visibility == "public" || visibility == "export") && !hasUDA!(__traits(getMember, T, memberName), gd_hide);
        enum isAllowedName = memberName[0..nu_min(2, memberName.length)] != "__";
        enum isAllowedMember = isVisible && isAllowedName;
    }
    alias boundMembersOf = Filter!(isAllowedMember, __traits(derivedMembers, T));
}

/**
    Gets the godot method flags of a given method.

    Params:
        method = An alias to a method.
*/
template methodFlagsOf(alias method) {
    enum uint methodFlagsOf = 
        GDEXTENSION_METHOD_FLAG_NORMAL | 
        (__traits(isStaticFunction, method) ? cast(uint)GDEXTENSION_METHOD_FLAG_STATIC : 0) |
        (__traits(isAbstractFunction, method) ? cast(uint)GDEXTENSION_METHOD_FLAG_VIRTUAL_REQUIRED : 0) |
        (__traits(isVirtualMethod, method) ? cast(uint)GDEXTENSION_METHOD_FLAG_VIRTUAL : 0);
}

/**
    Gets the method from its symbol alias or reference (via mixin).
*/
template methodOf(alias methodOrRef) {
    static if (is(methodOrRef))
        alias methodOf = methodOrRef;
    else static if (is(mixin(methodOrRef)))
        alias methodOf = mixin(methodOrRef);
    else
        static assert(0, "Could not convert ", methodOrRef, " to a method alias!");
}

/**
    Gets the return type of a given method.

    Params:
        method = An alias to a method.
    
    Returns:
        A type, or `void`.
*/
template returnTypeOf(alias method) {
    static if (is(ReturnType!(method)))
        alias returnTypeOf = ReturnType!(method);
    else static if (is(ReturnType!(mixin(method))))
        alias returnTypeOf = ReturnType!(mixin(method));
    else
        alias returnTypeOf = void;
}

/**
    Gets an alias sequence of parameters for a symbol.

    Params:
        symbol = An alias to a symbol.
    
    Returns:
        An alias sequence of parameters.
*/
template parametersOf(alias symbol) {
    import godot.variant : Signal;

    static if (is(typeof(symbol) == Signal!U, U...))
        alias parametersOf = symbol.ArgsT;
    else static if (is(Parameters!(symbol)))
        alias parametersOf = Parameters!(symbol);
    else static if (is(Parameters!(mixin(symbol))))
        alias parametersOf = Parameters!(mixin(symbol));
    else
        alias parametersOf = AliasSeq!();
}

/**
    Creates a name mangling of the given function that
    is compatible with C mangling rules as needed by GDExtension.

    Params:
        T =     The owner type
        func =  The function to mangle.
*/
template gdeMangleOf(T, alias func) {
    enum gdeMangleOf = __traits(identifier, func)~"_"~toSnakeCase!(classNameOf!T);
}

/**
    Converts the given string to snake case at compile time.

    Params:
        value = The string to convert to snake case.
*/
template toSnakeCase(string value) {
    enum toSnakeCase = (string v) {
        if (__ctfe) {
            import std.uni : isUpper, toLower;

            string out_;
            foreach(i, c; v) {
                if (isUpper(c)) {
                    if (i != 0)
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

/**
    Converts the given string to screaming snake case at compile time.

    Params:
        value = The string to convert to snake case.
*/
template toScreamingSnakeCase(string value) {
    enum toScreamingSnakeCase = (string v) {
        if (__ctfe) {
            import std.uni : isUpper, toUpper;

            string out_;
            foreach(i, c; v) {
                if (isUpper(c)) {
                    if (i != 0)
                        out_ ~= "_";
                    
                    out_ ~= c;
                    continue;
                }

                out_ ~= toUpper(c);
            }
            return out_;
        }
        return null;
    }(value);
}


//
//              IMPLEMENTATION DETAILS
//
private:

template getGetterFunc(T, alias name) {
    enum isGetterFunc(alias func) = Parameters!(func).length == 0 && !is(ReturnType!(func) == void);
    alias getterFunc = Filter!(isGetterFunc, __traits(getOverloads, T, name));

    static if (getterFunc.length > 0)
        alias getGetterFunc = getterFunc[0];
    else
        alias getGetterFunc = void;
}

template getSetterFunc(T, alias name) {
    enum isSetterFunc(alias func) = Parameters!(func).length == 1;
    alias setterFunc = Filter!(isSetterFunc, __traits(getOverloads, T, name));

    static if (setterFunc.length > 0)
        alias getSetterFunc = setterFunc[0];
    else
        alias getSetterFunc = void;
}