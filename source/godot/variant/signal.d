module godot.variant.signal;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;

struct Signal {
private:
@nogc:
    void[VARIANT_SIZE_SIGNAL] data_;
}