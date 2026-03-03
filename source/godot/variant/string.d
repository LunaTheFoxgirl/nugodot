module godot.variant.string;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;
import numem.core.memory;
import numem.core.hooks;
import nulib.string;

/**
    A godot string.
*/
struct String {
private:
@nogc:
    void[VARIANT_SIZE_STRING] data_;

public:

    /**
        Point to this instance, for use with raw GDExtension interface functions.
    */
    @property GDExtensionStringPtr native_ptr() inout => cast(GDExtensionStringPtr)&this;

    // @property size_t length() {
        
    // }

    /// Destructor
    ~this() {
        string_destroy(&this);
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
        string_new_with_utf8_chars_and_len2(this.native_ptr, text.ptr, cast(int)text.length);
    }

    /**
        Constructs a new godot string from a D string.
    */
    this(wstring text) {
        string_new_with_utf16_chars_and_len2(this.native_ptr, text.ptr, cast(int)text.length, false);
    }

    /**
        Constructs a new godot string from a D string.
    */
    this(dstring text) {
        string_new_with_utf32_chars_and_len(this.native_ptr, text.ptr, cast(int)text.length);
    }

    /**
        Resizes the string to the given size.

        Params:
            size = The new size.
    */
    void resize(size_t size) {
        string_resize(this.native_ptr, cast(int)size+1);
        *string_operator_index(this.native_ptr, cast(int)size) = 0;
    }

    /**
        Gets a string representation of the godot string.

        Note:
            This string must be freed with nu_freea!
        
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
    Constructs a new heap allocated string.

    This string must be freed by your using $(D nogc_delete)!

    Params:
        value = The value to set the new string to.
    
    Returns:
        The newly constructed string.
*/
String* gde_make_string(string value) @nogc {
    String* result = cast(String*)nu_malloc(String.sizeof);
    string_new_with_utf8_chars_and_len2(result, value.ptr, cast(int)value.length);
    return result;
}

/**
    A string name.
*/
struct StringName {
private:
@nogc:
    void[VARIANT_SIZE_STRINGNAME] data_;

public:

    /**
        Point to this instance, for use with raw GDExtension interface functions.
    */
    @property GDExtensionStringNamePtr native_ptr() inout => cast(GDExtensionStringNamePtr)&this;

    /// Destructor.
    ~this() {
        string_name_destroy(&this);
    }

    /**
        Constructs a new StringName.
    */
    this(string name) {
        string_name_new_with_utf8_chars_and_len(&this, name.ptr, cast(int)name.length);
    }
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
}