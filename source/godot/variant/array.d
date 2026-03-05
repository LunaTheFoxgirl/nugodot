module godot.variant.array;
import godot.variant.string;
import godot.variant.vector;
import godot.variant.color;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;

/**
    An array.
*/
struct Array {
private:
@nogc:
    void[VARIANT_SIZE_ARRAY] data_;

public:

}

/**
    A typed array.
*/
struct TypedArray(T, uint size = VARIANT_SIZE_ARRAY) {
private:
@nogc:
    void[VARIANT_SIZE_ARRAY] data_;

public:
    
}

alias PackedByteArray = TypedArray!(ubyte, VARIANT_SIZE_PACKEDBYTEARRAY);
alias PackedInt32Array = TypedArray!(int, VARIANT_SIZE_PACKEDINT32ARRAY);
alias PackedInt64Array = TypedArray!(long, VARIANT_SIZE_PACKEDINT64ARRAY);
alias PackedFloat32Array = TypedArray!(float, VARIANT_SIZE_PACKEDFLOAT32ARRAY);
alias PackedFloat64Array = TypedArray!(double, VARIANT_SIZE_PACKEDFLOAT64ARRAY);
alias PackedStringArray = TypedArray!(String, VARIANT_SIZE_PACKEDFLOAT64ARRAY);
alias PackedVector2Array = TypedArray!(Vector2, VARIANT_SIZE_PACKEDVECTOR2ARRAY);
alias PackedVector3Array = TypedArray!(Vector3, VARIANT_SIZE_PACKEDVECTOR3ARRAY);
alias PackedVector4Array = TypedArray!(Vector4, VARIANT_SIZE_PACKEDVECTOR4ARRAY);
alias PackedColorArray = TypedArray!(String, VARIANT_SIZE_PACKEDCOLORARRAY);