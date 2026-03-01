/**
    Interface for binding.
*/
module godot.core.gdextension.bind;

/**
    Specifies the name a class should be bound as.
*/
struct class_name { string name; } // @suppress(dscanner.style.phobos_naming_convention)

/**
    Exports a given property in the inspector.
*/
struct gd_export; // @suppress(dscanner.style.phobos_naming_convention)module godot.core.gde.object;