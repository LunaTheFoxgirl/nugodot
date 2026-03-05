module godot.variant.rid;
import godot.core.gdextension.iface;
import godot.variant;

/**
    Godot Rendering ID.
*/
struct RID {
    ulong value;
    alias value this;

    /**
        Constructs a new RID.

        Params:
            value = The value of the RID.
    */
    this(ulong value) {
        this.value = value;
    }

    /**
        Constructs an RID from a variant.

        Params:
            variant = The variant.
    */
    this()(auto ref Variant variant) {
        rid_from_variant(&this, &variant);
    }
}