module godot.variant.variant;
import godot.core.gdextension;
import godot.variant.string;
import godot.variant.rect;
import godot.variant.vector;
import godot.variant.aabb;
import numem;

/**
    Variant type tags.
*/
enum VariantType {
    NIL = 0,
    BOOL = 1,
    INT = 2,
    FLOAT = 3,
    STRING = 4,
    VECTOR2 = 5,
    VECTOR2I = 6,
    RECT2 = 7,
    RECT2I = 8,
    VECTOR3 = 9,
    VECTOR3I = 10,
    TRANSFORM2D = 11,
    VECTOR4 = 12,
    VECTOR4I = 13,
    PLANE = 14,
    QUATERNION = 15,
    AABB = 16,
    BASIS = 17,
    TRANSFORM3D = 18,
    PROJECTION = 19,
    COLOR = 20,
    STRING_NAME = 21,
    NODE_PATH = 22,
    RID = 23,
    OBJECT = 24,
    CALLABLE = 25,
    SIGNAL = 26,
    DICTIONARY = 27,
    ARRAY = 28,
    PACKED_BYTE_ARRAY = 29,
    PACKED_INT32_ARRAY = 30,
    PACKED_INT64_ARRAY = 31,
    PACKED_FLOAT32_ARRAY = 32,
    PACKED_FLOAT64_ARRAY = 33,
    PACKED_STRING_ARRAY = 34,
    PACKED_VECTOR2_ARRAY = 35,
    PACKED_VECTOR3_ARRAY = 36,
    PACKED_COLOR_ARRAY = 37,
    PACKED_VECTOR4_ARRAY = 38,
}

/**
    A godot variant type.
*/
struct Variant {
private:
@nogc:
    void[VARIANT_SIZE_VARIANT] data_;
    @property GDExtensionVariantPtr ptr() => cast(GDExtensionVariantPtr)data_.ptr;

public:

    /**
        The type of this variant.
    */
    @property VariantType type() => cast(VariantType)variant_get_type(ptr);

    /**
        The name of the type stored in the variant.
    */
    @property String typeName() {
        String value;
        variant_get_type_name(cast(GDExtensionVariantType)type, &value);
        return value;
    }

    /// Destructor
    ~this() {
        variant_destroy(this.ptr);
    }

    /**
        Constructs a new variant from a pointer.
    */
    this(GDExtensionVariantPtr ptr) {
        variant_new_copy(this.ptr, ptr);
    }

    /**
        Makes a copy of the variant.
    */
    this(ref return scope Variant other) {
        variant_new_copy(this.ptr, other.ptr);
    }

    /**
        Constructs a variant from an boolean.

        Params:
            value = The new value to give the variant.
    */
    this()(bool value) {
        variant_from_bool(this.ptr, &value);
    }

    /**
        Constructs a variant from an integer.

        Params:
            value = The new value to give the variant.
    */
    this(T)(T value)
    if (__traits(isIntegral, T)) {
        long tmp_ = value;
        variant_from_int(this.ptr, &tmp_);
    }

    /**
        Constructs a variant from a double.

        Params:
            value = The new value to give the variant.
    */
    this(T)(T value)
    if (__traits(isFloating, T)) {
        double tmp_ = value;
        variant_from_float(this.ptr, &tmp_);
    }

    /**
        Constructs a variant from a D string.

        Params:
            value = The new value to give the variant.
    */
    this(string value) {
        String str = value;
        variant_from_string(&this, &str);
    }

    /**
        Constructs a variant from a string.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref String value) {
        variant_from_string(&this, &value);
    }

    /**
        Constructs a variant from a string name.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref StringName value) {
        variant_from_string_name(&this, &value);
    }

    /**
        Constructs a variant from a vector.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref Vector2 value) {
        variant_from_vector2(&this, &value);
    }

    /**
        Constructs a variant from a vector.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref Vector2i value) {
        variant_from_vector2i(&this, &value);
    }

    /**
        Constructs a variant from a vector.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref Vector3 value) {
        variant_from_vector3(&this, &value);
    }

    /**
        Constructs a variant from a vector.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref Vector3i value) {
        variant_from_vector3i(&this, &value);
    }

    /**
        Constructs a variant from a vector.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref Vector4 value) {
        variant_from_vector4(&this, &value);
    }

    /**
        Constructs a variant from a vector.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref Vector4i value) {
        variant_from_vector4i(&this, &value);
    }

    /**
        Constructs a variant from a 2D rectangle.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref Rect2 value) {
        variant_from_rect2(&this, &value);
    }

    /**
        Constructs a variant from a 2D rectangle.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref Rect2i value) {
        variant_from_rect2i(&this, &value);
    }

    /**
        Constructs a variant from an axis aligned bounding box.

        Params:
            value = The new value to give the variant.
    */
    this()(auto ref AABB value) {
        variant_from_aabb(&this, &value);
    }

    /**
        Makes a copy of the variant.

        Params:
            deep = Whether to perform a deep copy.
        
        Returns:
            A new $(D GDVariant) with the contents copied from the source.
    */
    Variant duplicate(bool deep) {
        Variant result;
        variant_duplicate(&result, &this, deep);
        return result;
    }
}