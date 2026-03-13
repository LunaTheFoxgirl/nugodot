/**
    Attributes that affect the godot binding process.
*/
module godot.core.attribs;

/**
    Specifies the name a class should be bound as.
*/
struct class_name { string name; }

/**
    Specifies the icon to use for the type.
*/
struct class_icon { string path; }

/**
    Annotates the name of the symbol that the attribute
    is attached to.
*/
struct gd_name { string name; }

/**
    Annotates that the given class member should be hidden from
    Godot.
*/
struct gd_hide;