/**
    Global core functions for Godot.
*/
module godot.core.globals;
import godot.core.gdextension;

/**
    Prints a warning to the Godot console.

    Params:
        message =   The message to write.
        notify =    Whether to notify the editor.
*/
void printWarning(string func = __PRETTY_FUNCTION__, string file = __MODULE__, uint line = __LINE__)(string message, bool notify = true) {
    print_warning_with_message(message.ptr, message.ptr, func.ptr, file.ptr, line, notify);
}

/**
    Prints an error to the Godot console.

    Params:
        message =   The message to write.
        notify =    Whether to notify the editor.
*/
void printError(string func = __PRETTY_FUNCTION__, string file = __MODULE__, uint line = __LINE__)(string message, bool notify = true) {
    print_error_with_message(message.ptr, message.ptr, func.ptr, file.ptr, line, notify);
}

/**
    Prints a script error to the Godot console.

    Params:
        message =   The message to write.
        notify =    Whether to notify the editor.
*/
void printScriptError(string func = __PRETTY_FUNCTION__, string file = __MODULE__, uint line = __LINE__)(string message, bool notify = true) {
    print_script_error_with_message(message.ptr, message.ptr, func.ptr, file.ptr, line, notify);
}