module godot.variant.dict;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;

/**
    A dictionary.
*/
struct Dictionary {
private:
@nogc:
    void[VARIANT_SIZE_DICTIONARY] data_;

public:

}

/**
    A typed dictionary.
*/
struct TypedDictionary(TKey, TValue) {
private:
@nogc:
    void[VARIANT_SIZE_DICTIONARY] data_;

public:

}