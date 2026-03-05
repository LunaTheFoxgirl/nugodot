module godot.native;
import godot.core.gdextension.iface;
import godot.variant;
import godot.text_server;
import godot.object;
public import core.stdc.stdint;

struct AudioFrame {
    gd_float left;
    gd_float right;
}

struct CaretInfo {
    Rect2 leading_caret;
    Rect2 trailing_caret;
    TextServer.Direction leading_direction;
    TextServer.Direction trailing_direction;
}

struct Glyph {
    int start = -1;
    int end = -1;
    uint8_t count = 0;
    uint8_t repeat = 1;
    uint16_t flags = 0;
    float x_off = 0.0f;
    float y_off = 0.0f;
    float advance = 0.0f;
    RID font_rid;
    int font_size = 0;
    int32_t index = 0;
}

struct ObjectID {
    uint64_t id = 0;
    alias id this;
}

struct PhysicsServer2DExtensionMotionResult {
    Vector2 travel;
    Vector2 remainder;
    Vector2 collision_point;
    Vector2 collision_normal;
    Vector2 collider_velocity;
    gd_float collision_depth;
    gd_float collision_safe_fraction;
    gd_float collision_unsafe_fraction;
    int collision_local_shape;
    ObjectID collider_id;
    RID collider;
    int collider_shape;
}

struct PhysicsServer2DExtensionRayResult {
    Vector2 position;
    Vector2 normal;
    RID rid;
    ObjectID collider_id;
    Object collider;
    int shape;
}

struct PhysicsServer2DExtensionShapeRestInfo {
    Vector2 point;
    Vector2 normal;
    RID rid;
    ObjectID collider_id;
    int shape;
    Vector2 linear_velocity;
}

struct PhysicsServer2DExtensionShapeResult {
    RID rid;
    ObjectID collider_id;
    Object collider;
    int shape;
}

struct PhysicsServer3DExtensionMotionCollision {
    Vector3 position;
    Vector3 normal;
    Vector3 collider_velocity;
    Vector3 collider_angular_velocity;
    gd_float depth;
    int local_shape;
    ObjectID collider_id;
    RID collider;
    int collider_shape;
}

struct PhysicsServer3DExtensionMotionResult {
    Vector3 travel;
    Vector3 remainder;
    gd_float collision_depth;
    gd_float collision_safe_fraction;
    gd_float collision_unsafe_fraction;
    PhysicsServer3DExtensionMotionCollision[32] collisions;
    int collision_count;
}

struct PhysicsServer3DExtensionRayResult {
    Vector3 position;
    Vector3 normal;
    RID rid;
    ObjectID collider_id;
    Object collider;
    int shape;
    int face_index;
}

struct PhysicsServer3DExtensionShapeRestInfo {
    Vector3 point;
    Vector3 normal;
    RID rid;
    ObjectID collider_id;
    int shape;
    Vector3 linear_velocity;
}

struct PhysicsServer3DExtensionShapeResult {
    RID rid;
    ObjectID collider_id;
    Object collider;
    int shape;
}

struct ScriptLanguageExtensionProfilingInfo {
    StringName signature;
    uint64_t call_count;
    uint64_t total_time;
    uint64_t self_time;
}
