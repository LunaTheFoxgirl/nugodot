module godot.variant.plane;
import godot.variant.vector;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;

struct Plane {
    Vector3 normal;
    gd_float d;
}