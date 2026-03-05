module godot.variant.transform;
import godot.variant.vector;
import godot.variant.basis;
import godot.core.gdextension.iface;
import godot.core.gdextension.variant_size;

struct Transform2D {
    Vector2 x;
    Vector2 y;
    Vector2 origin;
}

struct Transform3D {
    Basis basis;
    Vector3 origin;
}