module godot.variant.vector;
import godot.core.gdextension.iface;
import numem.core.math;
import std.traits;

/**
    A Godot vector.
*/
struct VectorImpl(T, int dims) {
public:
@nogc:
    union {
        T[dims] coord = 0;

        struct {
            union {
                T x;
                T width;
            }
            union {
                T y;
                T height;
            }
            static if (dims >= 3) {
                union {
                    T z;
                    T depth;
                }
            }
            static if (dims >= 4) {
                T w;
            }
        }
    }

    /**
        Constructs a new vector.
    */
    this(Args...)(Args args) {
        static if (is(typeof(args[0]) == VectorImpl!U, U...)) {
            static foreach(i; 0..nu_min(dims, args[0].dims)) {
                this.coord[i] = cast(T)args[0].coord[i];
            }
        } else static if (allSameType!(Args) && __traits(isScalar, Args[0])) {
            static foreach(i; 0..nu_min(dims, args.length)) {
                this.coord[i] = cast(T)args[i];
            }
        } else {
            static assert(0, "Can't construct Vector with argument types ", Args.stringof);
        }
    }
}

enum Axis {
    AXIS_X = 0,
    AXIS_Y = 1,
    AXIS_Z = 2,
    AXIS_W = 3
}

alias Vector2 = VectorImpl!(gd_float, 2);
alias Vector2i = VectorImpl!(int, 2);
alias Vector3 = VectorImpl!(gd_float, 3);
alias Vector3i = VectorImpl!(int, 3);
alias Vector4 = VectorImpl!(gd_float, 4);
alias Vector4i = VectorImpl!(int, 4);