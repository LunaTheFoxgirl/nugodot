module generator.parser;
import generator.types;
import generator.utils;
import std.file : remove, exists, readText;
import std.process : execute;

public import std.exception;
public import core.stdc.errno;
public import std.json;

enum GDE_INTERFACE = 0;
enum GDE_API = 1;


/**
    Parses the godot extension JSON.

    Returns:
        The JSON trees for the interface and extension APIs.
*/
JSONValue[2] parseGDEJson(string exec) {
    auto gd = execute([exec, "--headless", "--dump-gdextension-interface-json", "--dump-extension-api-with-docs", "--quit"]);
    enforce(gd.status == 0, new ErrnoException(gd.output, gd.status));
    enforce(
        exists("gdextension_interface.json") && exists("extension_api.json"), 
        new ErrnoException("Expected files did not get generated!", ENOENT)
    );
    JSONValue[2] result = [
        parseJSON(readText("gdextension_interface.json")),
        parseJSON(readText("extension_api.json"))
    ];

    remove("gdextension_interface.json");
    remove("extension_api.json");
    return result;
}

/**
    Parses types from the given JSON.

    Params:
        json =      The JSON to parse.
        schema =    The schema of the JSON.

    Returns:
        The types found in the json object.
*/
GDETypeRegistry parseTypes(JSONValue json, int schema) {
    GDETypeRegistry registry = new GDETypeRegistry();
    final switch(schema) {
        case GDE_INTERFACE:

            foreach(type_t; json["types"].array) {
                
                // Skip deprecated types.
                if ("deprecated" in type_t)
                    continue;

                switch(type_t["kind"].str) {
                    case "enum":
                        auto enum_t = new GDEEnum();
                        enum_t.parse(type_t, GDE_INTERFACE, registry);
                        registry.add(enum_t);
                        break;

                    case "handle":
                        auto handle_t = new GDEHandle();
                        handle_t.parse(type_t, GDE_INTERFACE, registry);
                        registry.add(handle_t);
                        break;

                    case "alias":
                        auto alias_t = new GDEAlias();
                        alias_t.parse(type_t, GDE_INTERFACE, registry);
                        registry.add(alias_t);
                        break;

                    case "struct":
                        auto struct_t = new GDEStruct();
                        struct_t.parse(type_t, GDE_INTERFACE, registry);
                        registry.add(struct_t);
                        break;

                    case "function":
                        auto fp_t = new GDEFuncPrototype();
                        fp_t.parse(type_t, GDE_INTERFACE, registry);
                        registry.add(fp_t);
                        break;

                    default:
                        break;
                }
            }

            // Parse interface.
            foreach(func_t; json["interface"].array) {
                
                // Skip deprecated functions.
                if ("deprecated" in func_t)
                    continue;
                
                auto fp_t = new GDEFunc();
                fp_t.parse(func_t, GDE_INTERFACE, registry);
                registry.add(fp_t);
            }
            break;
        
        case GDE_API:
            break;
    }

    registry.finalize();
    return registry;
}

/**
    Parses the variant types available.

    Params:
        json =      The JSON to parse.
        schema =    The schema of the JSON.

    Returns:
        The variants found in the json object.
*/
GDEVariantType[] parseVariantTypes(JSONValue json, int schema) {
    GDETypeRegistry registry = new GDETypeRegistry();
    final switch(schema) {
        case GDE_INTERFACE:
            foreach(type_t; json["types"].array) {
                if (type_t["kind"].str == "enum" && type_t["name"].str == "GDExtensionVariantType") {

                    auto enum_t = new GDEEnum();
                    enum_t.parse(type_t, GDE_INTERFACE, registry);
                    foreach(key; enum_t.members[1..$-1]) {
                        registry.add(new GDEVariantType(cast(GDEEnumMember)key));
                    }
                    break;
                }
            }
            break;
        
        case GDE_API:
            break;
    }

    registry.finalize();
    return cast(GDEVariantType[])registry.types().findTypes!GDEVariantType;
}