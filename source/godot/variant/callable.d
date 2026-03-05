module godot.variant.callable;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;

struct Callable {
private:
@nogc:
    void[VARIANT_SIZE_CALLABLE] data_;
    
}