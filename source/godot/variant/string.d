module godot.variant.string;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;
import numem.core.memory;
import numem.core.hooks;
import godot.variant.variant;

/**
    A godot string.
*/
struct String {
private:
@nogc:
    void[VARIANT_SIZE_STRING] data_;

public:

    /**
        Pointer to the underlying string data.
    */
    @property const(dchar)* ptr() => string_operator_index_const(&this, 0);

    /**
        Length of the string in UTF-32 units.
    */
    @property size_t length() => string_to_utf32_chars(&this, null, 0);

    /**
        Length of the string in UTF-8 bytes.
    */
    @property size_t utf8Length() => string_to_utf8_chars(&this, null, 0);

    /// Destructor
    ~this() {
        string_destroy(&this);
    }

    /**
        Constructs a string from a variant.
    */
    this(ref Variant variant) {
        string_from_variant(&this, &variant);
    }

    /**
        Makes a copy of the string.
    */
    this(ref return scope String other) {
        this.data_[0..$] = other.data_[0..$];
    }

    /**
        Constructs a new godot string from a D string.
    */
    this(string text) {
        string_new_with_utf8_chars_and_len2(&this, text.ptr, cast(int)text.length);
    }

    /**
        Constructs a new godot string from a D string.
    */
    this(wstring text) {
        string_new_with_utf16_chars_and_len2(&this, text.ptr, cast(int)text.length, false);
    }

    /**
        Constructs a new godot string from a D string.
    */
    this(dstring text) {
        string_new_with_utf32_chars_and_len(&this, text.ptr, cast(int)text.length);
    }

    /**
        Resizes the string to the given size.

        Params:
            size = The new size.
    */
    void resize(size_t size) {
        string_resize(&this, cast(int)size+1);
        *string_operator_index(&this, cast(int)size) = 0;
    }

    /**
        Allows appending to the string.

        Params:
            value = The value to append.
    */
    auto opOpAssign(string op = "~", T)(auto ref T value) {
        import nulib.string : isSomeString;

        static if (is(T == char)) {
            import nulib.text.unicode.utf8 : decode;
            
            char[4] c = [value, 0, 0, 0];
            string_operator_plus_eq_char(&this, decode(c));
        } else static if (is(T == dchar)) {
            import nulib.text.unicode.utf16 : decode;

            size_t throwaway;
            wchar[2] c = [value, 0];
            string_operator_plus_eq_char(&this, decode(c, throwaway));
        } else static if (isSomeString!T) {
            import nulib.text.unicode : toUTF32;

            auto str = toUTF32(value, false);
            string_operator_plus_eq_c32str(&this, str.ptr);
        } else static if (is(T == String*)) {

            string_operator_plus_eq_string(&this, value);
        } else static if (is(T == String)) {

            string_operator_plus_eq_string(&this, &value);
        } else {
            static assert(0, "Can't append "~T.stringof~" to String.");
        }
        return this;
    }

    /**
        Gets a string representation of the godot string.

        Note:
            This string must be freed with $(D nu_freea)!
        
        Returns:
            A D string representation of this string.
    */
    string toString() const {
        char[] str_ = nu_malloca!char(string_to_utf8_chars(&this, null, 0));
        string_to_utf8_chars(&this, cast(char*)str_.ptr, cast(int)str_.length);
        return cast(string)str_;
    }
}

/**
    Constructs a new heap allocated $(D String).

    This string must be freed by your using $(D gde_free_string)!

    Params:
        value = The value to set the new string to.
    
    Returns:
        The newly constructed $(D String).
    
    See_Also:
        $(D gde_free_string)
*/
pragma(inline, true)
String* gde_make_string(string value) @nogc nothrow {
    String* result = cast(String*)nu_malloc(String.sizeof);
    string_new_with_utf8_chars_and_len2(result, value.ptr, cast(int)value.length);
    return result;
}

/**
    Frees a heap-allocated $(D String).

    Params:
        str = The string to free.

    See_Also:
        $(D gde_make_string)
*/
pragma(inline, true)
void gde_free_string(ref String* str) @nogc nothrow {
    string_destroy(str);
    nu_free(str);
    str = null;
}

/**
    A string name.
*/
struct StringName {
private:
@nogc:
    void[VARIANT_SIZE_STRINGNAME] data_;

public:

    /// Destructor.
    ~this() {
        string_name_destroy(&this);
    }

    /**
        Constructs a StringName from a variant.
    */
    this(ref Variant variant) {
        string_name_from_variant(&this, &variant);
    }

    /**
        Constructs a new StringName.
    */
    this(string name) {
        string_name_new_with_utf8_chars_and_len(&this, name.ptr, cast(int)name.length);
    }
}

/**
    Constructs a new heap allocated $(D StringName).

    This string must be freed by your using $(D gde_free_string_name)!

    Params:
        value = The value to set the new string to.
    
    Returns:
        The newly constructed $(D StringName).
    
    See_Also:
        $(D gde_free_string_name)
*/
pragma(inline, true)
StringName* gde_make_string_name(string value) @nogc nothrow {
    StringName* result = cast(StringName*)nu_malloc(StringName.sizeof);
    string_name_new_with_utf8_chars_and_len(result, value.ptr, cast(int)value.length);
    return result;
}


/**
    Frees a heap-allocated $(D StringName).

    Params:
        str = The string to free.

    See_Also:
        $(D gde_make_string_name)
*/
pragma(inline, true)
void gde_free_string_name(ref StringName* name) @nogc nothrow {
    string_name_destroy(name);
    nu_free(name);
    name = null;
}

/**
    A node path.
*/
struct NodePath {
private:
@nogc:
    void[VARIANT_SIZE_NODEPATH] data;

public:

    /// Destructor
    ~this() {
        node_path_destroy(&this);
    }

    /**
        Constructs a StringName from a variant.
    */
    this(ref Variant variant) {
        node_path_from_variant(&this, &variant);
    }
}