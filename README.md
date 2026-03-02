# NuGodot

NuGodot is numem based bindings to GDExtension, allowing writing Godot extensions in DLang using nogc D constructs.

## Requirements

LDC 1.40 or newer is required to compile the project. `nugodot` uses `@section` from LDC to automate loading
bound classes.

## Building the bindings

The build the bindings an installation of Godot must either be in your `PATH`, or must be specified by setting
the `GODOT_PATH` environment varianble. The bindings will then automatically generate when you build your project.

If you ever need to rebuild the bindings, build nugodot with the `rebuild` configuration.