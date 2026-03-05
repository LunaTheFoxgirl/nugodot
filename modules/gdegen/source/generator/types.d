module generator.types;
import generator.writer;
import generator.utils;
import generator.ddoc;
import std.string;
import std.json;

enum INTERFACE_SCHEMA = 0;
enum API_SCHEMA = 1;

static immutable BASIC_TYPE_NAMES = [
    "size_t",
    "ptrdiff_t",
    "uint8_t",
    "int8_t",
    "uint16_t",
    "int16_t",
    "uint32_t",
    "int32_t",
    "uint64_t",
    "int64_t",
    "float",
    "double",
    "char",
    "dchar",
    "wchar",
    "void"
];

/**
    A registry of GDEType types.
*/
final
class GDETypeRegistry {
private:
    GDETypeRegistry superRegistry;

    GDEType[] types_;
    ptrdiff_t findIndexOf(string name, ptrdiff_t start = 0) {
        if (start >= types_.length)
            return -1;

        // TODO:    parse the shenanigans that godot does for types
        //          in the API schema.
        foreach(i, type; types_[start..$]) {
            if (type.name == name)
                return i;
        }
        return -1;
    }

public:

    /**
        Constructs a new type registry.
    */
    this() {
        static foreach(basicType; BASIC_TYPE_NAMES) {
            this.basicType(basicType);
        }
    }

    /**
        Constructs this type registry as a sub-registry
        of another.

        Params:
            superRegistry = The super registry.
    */
    this(GDETypeRegistry superRegistry) {
        this();
        this.superRegistry = superRegistry;
    }

    /**
        List of all registered types in the registry.
    */
    @property GDEType[] types() => types_;

    /**
        Finds a type with the given name.

        Params:
            name = The name to look for.
    */
    GDEType find(string name) {
        ptrdiff_t idx = this.findIndexOf(name);
        if (superRegistry)
            return idx >= 0 ? types_[idx] : superRegistry.find(name);

        return idx >= 0 ? types_[idx] : null;
    }

    /**
        Finds a type with the given name.

        Params:
            name = The name to look for.
    */
    GDEType findOrAssumeBasic(string name) {
        ptrdiff_t idx = this.findIndexOf(name);
        if (superRegistry)
            return idx >= 0 ? types_[idx] : superRegistry.findOrAssumeBasic(name);

        return idx >= 0 ? types_[idx] : this.basicType(name);
    }

    /**
        Gets a given basic type.

        Params:
            name =  The name of the basic type to get or create.
    */
    GDEType basicType(string name) {
        ptrdiff_t idx = this.findIndexOf(name);
        if (idx >= 0)
            return types_[idx];

        if (superRegistry)
            return superRegistry.basicType(name);
        
        return this.add(new GDEBasicType(name));
    }

    /**
        Gets a given basic type.
    */
    GDEType basicType(T)() {
        return this.basicType(T.stringof);
    }

    /**
        Adds a type to the registry.

        Param:
            type =  The type added.
    */
    GDEType add(GDEType type) {
        synchronized {
            types_ ~= type;
        }
        return type;
    }

    /**
        Finds or adds a new type of the given name.

        Params:
            name =  Name of the type to find or add.
            args =  Arguments to pass to the constructor of
                    the type if it couldn't be found.
    */
    T findOrAdd(T, Args...)(string name, Args args)
    if (is(T : GDEType)) {
        ptrdiff_t idx = this.findIndexOf(name);
        do {
            if (cast(T)types_[idx])
                break;

            idx = this.findIndexOf(name, idx);
        } while(idx >= -1);

        if (idx >= 0)
            return cast(T)types_[idx];
        
        return this.add(new T(args));
    }

    /**
        Finalizes the registry, making all the types
        within it realized.
    */
    void finalize() {
        foreach(type; types_) {
            type.finalize(this);
        }
    }
}

/**
    Base-class of GDExtension type info.
*/
abstract
class GDEType {
private:
    string name_;
    DDOC ddoc_;

protected:

    /**
        Name of the type.
    */
    final @property void name(string value) {
        this.name_ = value;
    }

    /**
        DDOC documentation for the type.
    */
    final @property void ddoc(DDOC value) {
        this.ddoc_ = value;
    }

public:

    /**
        Name as a D compatible identifier.
    */
    @property string d_name() => name;

    /**
        Name as a D compatible identifier, with subclassing.
    */
    @property string d_full_name() => d_name;

    /**
        Parses godot types.
    */
    static GDEType fromGodotType(string typeString, GDETypeRegistry registry) {
        if (typeString.pop("enum::")) {
            ptrdiff_t subclassLength = typeString.countUntil('.');
            if (subclassLength > 0) {
                string subclass = typeString[0..subclassLength];
                string enumType = typeString[subclassLength+1..$];

                if (auto klass = cast(GDEClass)registry.find(subclass)) {
                    if (auto subtype = klass.findSubtype(enumType))
                        return subtype;
                }
            }
            if (auto rt = registry.find(typeString))
                return rt;
        }

        if (typeString.pop("bitfield::")) {
            ptrdiff_t subclassLength = typeString.countUntil('.');
            if (subclassLength > 0) {
                string subclass = typeString[0..subclassLength];
                string enumType = typeString[subclassLength+1..$];

                if (auto klass = cast(GDEClass)registry.find(subclass)) {
                    if (auto subtype = klass.findSubtype(enumType))
                        return subtype;
                }
            }
            if (auto rt = registry.find(typeString))
                return rt;
        }

        if (typeString.pop("typedarray::")) {
            ptrdiff_t junk = typeString.countUntil(':');
            if (junk >= 0)
                typeString.skip(junk+1);

            if (typeString.length == 0)
                return registry.findOrAssumeBasic("Array");

            return new GDETypedArray(registry.findOrAssumeBasic(typeString));
        }

        if (typeString.pop("typeddictionary::")) {
            ptrdiff_t keyLength = typeString.countUntil(';');
            string keyType = typeString[0..keyLength];
            string valueType = typeString[keyLength+1..$];
            return new GDETypedDictionary(registry.findOrAssumeBasic(keyType), registry.findOrAssumeBasic(valueType));
        }

        if (auto rt = registry.find(typeString))
            return rt;
        
        return GDEType.fromCTypeString(typeString, registry);
    }

    /**
        Parses a type from a C type string.
    
        Params:
            typeString =    A C string of a given type.
            registry =      The registry to search.
    */
    static GDEType fromCTypeString(string typeString, GDETypeRegistry registry) {
        GDEType type;

        string buffer = typeString;
        while(buffer.length > 0) {
            buffer.popWhite();
            
            // Const qualifier.
            if (buffer.pop("const ")) {
                type = new GDEConstQualifier(type);
                continue;
            }

            if (buffer.pop("*")) {
                type = new GDEPointer(type);
                continue;
            }

            if (string iden = buffer.popIdentifier()) {
                if (auto qual = cast(GDETypeQualifier)type)
                    qual.setBottomType(registry.findOrAssumeBasic(iden));
                else
                    type = registry.findOrAssumeBasic(iden);
                continue;
            }

            buffer.skip();
        }
        return type;
    }

    /**
        Name of the type.
    */
    @property string name() => name_;

    /**
        DDOC documentation for the type.
    */
    final @property DDOC ddoc() => ddoc_;

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    abstract void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry);

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    abstract void finalize(GDETypeRegistry registry);

    /**
        Gets a string representation of the type.
    */
    override
    string toString() { // @suppress(dscanner.suspicious.object_const)
        return name;
    }
}

/**
    A variant type.
*/
class GDEVariantType : GDEType {
private:
    GDEEnumMember key_;

public:

    /**
        The variant type enum key.
    */
    @property GDEEnumMember key() => key_;

    /**
        Constructs a new variant type.
    */
    this(string name, GDEEnumMember key) {
        this.name = name;
        this.key_ = key;
    }

    /**
        Constructs a new variant type.
    */
    this(GDEEnumMember key) {
        import std.string : toLower;

        enum prefix_ = "GDEXTENSION_VARIANT_TYPE_";
        this(key.name[prefix_.length..$].toLower(), key);
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) { }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override void finalize(GDETypeRegistry registry) { }
}

/**
    A typed array.
*/
class GDETypedArray : GDEType {
private:
    GDEType type_;

public:

    /**
        Name as a D compatible identifier.
    */
    override @property string d_name() => "TypedArray!("~type_.d_full_name~")";

    /**
        Name of the type of the member.
    */
    @property GDEType type() => type_;
    
    /**
        Constructs a new typed array.
    */
    this(GDEType type) {
        this.type_ = type;
        this.name = "TypedArray[%s]".format(type_.name);
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) { }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override void finalize(GDETypeRegistry registry) { }
}
/**
    A typed dictionary.
*/
class GDETypedDictionary : GDEType {
private:
    GDEType keyType_;
    GDEType valueType_;

public:

    /**
        Name as a D compatible identifier.
    */
    override @property string d_name() => "TypedDictionary!("~keyType_.d_full_name~", "~valueType_.d_full_name~")";

    /**
        Name of the type of the member.
    */
    @property GDEType keyType() => keyType_;

    /**
        Name of the type of the member.
    */
    @property GDEType valueType() => valueType_;
    
    /**
        Constructs a new typed array.
    */
    this(GDEType key, GDEType value) {
        this.keyType_ = key;
        this.valueType_ = value;
        this.name = "TypedDictionary[%s;%s]".format(key.name, value.name);
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) { }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override void finalize(GDETypeRegistry registry) { }
}

/**
    A named member of a type.
*/
abstract
class GDEMember : GDEType {
public:

    /**
        Name of the type of the member.
    */
    abstract @property GDEType type();
}

/**
    Base class of type qualifiers.
*/
abstract
class GDETypeQualifier : GDEType {
private:
    GDEType subtype_;

public:

    /**
        The subtype of the qualifier.
    */
    final @property GDEType subtype() => subtype_;
    final @property void subtype(GDEType value) {
        this.subtype_ = value;
    }

    /**
        Creates a new qualifier, qualifying the given type.

        Params:
            subtype =   The subtype being pointed to.
    */
    this(GDEType subtype) {
        this.subtype_ = subtype;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) { }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override void finalize(GDETypeRegistry registry) { }

    /**
        Sets the bottom type of the type qualifier hirearchy.

        Params:
            type =  The type to set as the bottom level type.
    */
    void setBottomType(GDEType type) {
        GDETypeQualifier iter = this;
        while(cast(GDETypeQualifier)iter.subtype)
            iter = cast(GDETypeQualifier)iter.subtype;
        iter.subtype = type;
    }
}

/**
    Base class of aggregate types.
*/
abstract
class GDEAggregate : GDEType {
public:

    /**
        The members of the aggregate.
    */
    abstract @property GDEMember[] members();

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        foreach(member; members) {
            member.finalize(registry);
        }
    }
}

/**
    A basic type.
*/
class GDEBasicType : GDEType {
public:
    this(string name) {
        this.name = name;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) { }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override void finalize(GDETypeRegistry registry) { }
}

/**
    A pointer type.
*/
class GDEPointer : GDETypeQualifier {
public:
    
    /**
        Name of the type.
    */
    override @property string name() => subtype.name~"*";

    /**
        Creates a new pointer, pointing to the given type.

        Params:
            subtype =   The subtype being pointed to.
    */
    this(GDEType subtype) {
        super(subtype);
    }
}

/**
    A const type qualifier
*/
class GDEConstQualifier : GDETypeQualifier {
public:
    
    /**
        Name of the type.
    */
    override @property string name() => "const("~subtype.name~")";

    /**
        Creates a new pointer, pointing to the given type.

        Params:
            subtype =   The subtype being pointed to.
    */
    this(GDEType subtype) {
        super(subtype);
    }
}

/**
    Represents an enumeration
*/
class GDEEnum : GDEAggregate {
private:
    GDEType type_;
    GDEClass parent_;
    GDEMember[] members_;
    bool isBitfield_;

public:

    @property GDEType type() => type_;

    /**
        Name of the property as a valid D identifier.
    */
    override @property string d_name() => this.name.filterReserved;

    /**
        Name of the property as a valid D identifier.
    */
    override @property string d_full_name() => parent ? "%s.%s".format(parent.d_name, this.d_name) : this.d_name;

    /**
        Members of the enum.
    */
    override @property GDEMember[] members() => members_;

    /**
        Whether the enum is a bitfield.
    */
    @property bool isBitfield() => isBitfield_;

    /**
        Parent class of the method.
    */
    @property GDEClass parent() => parent_;

    /// base constructor
    this() { }

    /// class constructor
    this(GDEClass parent) {
        this.parent_ = parent;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        switch(schema) {
            case INTERFACE_SCHEMA:
            case API_SCHEMA:
                this.name = json["name"].str;
                foreach(mjson; json["values"].array) {
                    auto member = new GDEEnumMember(this);
                    member.parse(mjson, schema, registry);
                    this.members_ ~= member;
                }

                if ("is_bitfield" in json)
                    this.isBitfield_ = json["is_bitfield"].boolean;
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override void finalize(GDETypeRegistry registry) {
        import std.math : abs;
        
        long maxValue = 0;
        foreach(member; cast(GDEEnumMember[])members) {
            if (abs(member.value) > maxValue)
                maxValue = abs(member.value);
        }

        if (maxValue >= int.max)
            this.type_ = registry.basicType("int64_t");
        else if (maxValue >= short.max)
            this.type_ = registry.basicType("int32_t");
        else if (maxValue >= byte.max)
            this.type_ = registry.basicType("int16_t");
        else 
            this.type_ = registry.basicType("int8_t");
    }

    /**
        Gets a string representation of the type.
    */
    override
    string toString() { // @suppress(dscanner.suspicious.object_const)
        import std.format;
        return "(enum %s (%s))".format(name, members.strJoin(", "));
    }
}

/**
    An enum member.
*/
class GDEEnumMember : GDEMember {
private:
    GDEEnum parent_;
    GDEType type_;
    long value_;

public:

    /**
        Type of the member.
    */
    override @property GDEType type() => type_;

    /**
        Value of the type.
    */
    @property long value() => value_;

    /**
        The parent enum that this member belongs to.
    */
    @property GDEEnum parent() => parent_;

    /**
        Constructs a new enum member.

        Params:
            parent = The enum this member belongs to.
    */
    this(GDEEnum parent) {
        this.parent_ = parent;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case INTERFACE_SCHEMA:
            case API_SCHEMA:
                this.name = json["name"].str;
                if ("value" in json)
                    this.value_ = json["value"].integer;
                
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        this.type_ = registry.basicType!uint;
    }

    /**
        Gets a string representation of the type.
    */
    override
    string toString() { // @suppress(dscanner.suspicious.object_const)
        import std.format;
        return "%s = %s".format(name, value);
    }
}

/**
    A manifest constant.
*/
class GDEManifestConstant : GDEType {
private:
    GDEClass parent_;
    string name_;
    long value_;

public:

    /// base constructor
    this() { }

    /// class constructor
    this(GDEClass parent) {
        this.parent_ = parent;
    }

    /**
        Parent class of the method.
    */
    @property GDEClass parent() => parent_;

    /**
        Value of the manifest constant.
    */
    @property long value() => value_;

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);
        switch(schema) {
            case API_SCHEMA:
                this.name = json["name"].str;
                this.value_ = json["value"].integer;
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) { }
}

/**
    A type alias/typedef.
*/
class GDEAlias : GDEType {
private:
    string pTypeName_;
    GDEType pType_;

public:

    /**
        Parent type of the alias.
    */
    @property GDEType type() => pType_;

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case INTERFACE_SCHEMA:
                this.name = json["name"].str;
                this.pTypeName_ = json["type"].str;
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        this.pType_ = GDEType.fromCTypeString(pTypeName_, registry);
    }

    /**
        Gets a string representation of the type.
    */
    override
    string toString() { // @suppress(dscanner.suspicious.object_const)
        import std.format;
        return "(alias %s = %s)".format(name, type.toString());
    }
}

/**
    A native handle.
*/
class GDEHandle : GDEType {
private:
    bool isConst_;
    GDEType type_;

public:

    /**
        Whether the handle is const.
    */
    @property bool isConst() => isConst_;

    /**
        The type of the handle.
    */
    @property GDEType type() => type_;

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case INTERFACE_SCHEMA:
                this.name = json["name"].str;
                this.isConst_ = "is_const" in json && json["is_const"].boolean;
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        GDEType type = registry.basicType("void");
        if (isConst)
            type = new GDEConstQualifier(type);
        
        this.type_ = new GDEPointer(type);
    }

    /**
        Gets a string representation of the type.
    */
    override
    string toString() { // @suppress(dscanner.suspicious.object_const)
        import std.format;
        return "(handle %s = %s)".format(name, type.toString());
    }
}

/**
    A data structure.
*/
class GDEStruct : GDEAggregate {
private:
    GDEMember[] members_;

public:

    /**
        Members of the struct.
    */
    override @property GDEMember[] members() => members_;

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case INTERFACE_SCHEMA:
                this.name = json["name"].str;
                foreach(mjson; json["members"].array) {
                    auto member = new GDEStructMember();
                    member.parse(mjson, schema, registry);
                    this.members_ ~= member;
                }
                return;

            default:
                return;
        }
    }

    /**
        Gets a string representation of the type.
    */
    override
    string toString() { // @suppress(dscanner.suspicious.object_const)
        import std.format;
        return "(struct %s (%s))".format(name, members_.strJoin(", "));
    }
}

/**
    A struct member.
*/
class GDEStructMember : GDEMember {
private:
    string typeName_;
    GDEType type_;
    string value_;

public:

    /**
        Type of the member.
    */
    override @property GDEType type() => type_;

    /**
        Value of the type.
    */
    @property string value() => value_;

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case INTERFACE_SCHEMA:
                this.name = json["name"].str;
                this.typeName_ = json["type"].str;

                if ("value" in json)
                    this.value_ = json["value"].toString();
                
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        this.type_ = GDEType.fromCTypeString(typeName_, registry);
    }
}

/**
    A function protoype.
*/
class GDEFuncPrototype : GDEType {
private:
    string rTypeName_;
    GDEType return_;
    GDEFuncParam[] params_;

public:

    /**
        The type of the return value.
    */
    @property GDEType returnType() => return_;

    /**
        The parameters of the function.
    */
    @property GDEFuncParam[] params() => params_;

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case INTERFACE_SCHEMA:
                this.name = json["name"].str;

                if ("arguments" in json) {
                    foreach(mjson; json["arguments"].array) {
                        auto param = new GDEFuncParam();
                        param.parse(mjson, schema, registry);
                        this.params_ ~= param;
                    }
                }

                this.rTypeName_ = "return_value" in json ? json["return_value"]["type"].str : null;
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        foreach(param; params_)
            param.finalize(registry);
        
        return_ = rTypeName_ ? GDEType.fromCTypeString(rTypeName_, registry) : registry.basicType("void");
    }

    /**
        Gets a string representation of the type.
    */
    override
    string toString() { // @suppress(dscanner.suspicious.object_const)

        import std.format;
        return "(func %s (%s) %s)".format(name, params_.strJoin(", "), return_.toString());
    }
}

/**
    A function.
*/
class GDEFunc : GDEType {
private:
    string rTypeName_;
    GDEType return_;
    GDEFuncParam[] params_;

public:

    /**
        The type of the return value.
    */
    @property GDEType returnType() => return_;

    /**
        The parameters of the function.
    */
    @property GDEFuncParam[] params() => params_;

    /**
        Constructor.
    */
    this() { }

    /**
        Constructor.
    */
    this(string name, GDEType returnType, GDEFuncParam[] params) {
        this.name = name;
        this.return_ = returnType;
        this.params_ = params;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case INTERFACE_SCHEMA:
            case API_SCHEMA:
                this.name = json["name"].str;

                if ("arguments" in json) {
                    foreach(mjson; json["arguments"].array) {
                        auto param = new GDEFuncParam();
                        param.parse(mjson, schema, registry);
                        this.params_ ~= param;
                    }
                }

                this.rTypeName_ = "return_value" in json ? json["return_value"]["type"].str : null;
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        foreach(param; params_) {
            param.finalize(registry);
        }
        
        return_ = rTypeName_ ? GDEType.fromGodotType(rTypeName_, registry) : registry.basicType("void");
    }

    /**
        Gets a string representation of the type.
    */
    override
    string toString() { // @suppress(dscanner.suspicious.object_const)

        import std.format;
        return "(func %s (%s) %s)".format(name, params_.strJoin(", "), return_.toString());
    }
}

/**
    A function parameter.
*/
class GDEFuncParam : GDEMember {
private:
    string typeName_;
    GDEType type_;
    string value_;
    string meta_;

public:

    /**
        Type of the parameter.
    */
    override @property GDEType type() => type_;

    /**
        Default value of the parameter, can be empty.
    */
    @property string value() => value_;

    /**
        Meta-type of parameter.
    */
    @property string meta() => meta_;

    /**
        Constructor.
    */
    this() { }

    /**
        Constructor.
    */
    this(string name, GDEType type) {
        this.name = name;
        this.type_ = type;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        switch(schema) {
            case INTERFACE_SCHEMA:
            case API_SCHEMA:
                if ("name" in json)
                    this.name = json["name"].str.filterReserved();
                
                if ("type" in json)
                    this.typeName_ = json["type"].str;
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        
        // If a param has no type name (wasn't parsed)
        // then it's probably void.
        if (!typeName_) {
            this.type_ = registry.basicType("void");
            return;
        }

        this.type_ = GDEType.fromGodotType(typeName_, registry);
    }
}

/**
    A class method.
*/
class GDEMethod : GDEFunc {
private:
    GDEClass parent_;
    bool isProtected_;
    bool isConst_;
    bool isStatic_;
    bool isRequired_;
    bool isVararg_;
    bool isVirtual_;
    long hash_;

public:

    /**
        Name of the property as a valid D identifier.
    */
    override @property string d_name() => isProtected_ ?
        this.name.toCamelCase.filterReserved ~ "Impl" :
        this.name.toCamelCase.filterReserved;

    /**
        Whether the method is const.
    */
    @property bool isConst() => isConst_;

    /**
        Whether the method is static.
    */
    @property bool isStatic() => isStatic_;

    /**
        Whether the method is required.
    */
    @property bool isRequired() => isRequired_;

    /**
        Whether the method is vararg.
    */
    @property bool isVararg() => isVararg_;

    /**
        Whether the method is virtual.
    */
    @property bool isVirtual() => isVirtual_;

    /**
        Whether the method is protected.
    */
    @property bool isProtected() => isProtected_;

    /**
        Whether this method is an override.
    */
    @property bool isOverride() => parent_.inherits ? parent_.inherits.hasMethod(d_name) : false;

    /**
        The hash of the method.
    */
    @property long hash() => hash_;

    /**
        Parent class of the method.
    */
    @property GDEClass parent() => parent_;

    /**
        Instantiates a new method.
    */
    this(GDEClass parent) {
        this.parent_ = parent;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case API_SCHEMA:
            case INTERFACE_SCHEMA:
                super.parse(json, schema, registry);
                this.isConst_ = json["is_const"].boolean;
                this.isStatic_ = json["is_static"].boolean;
                this.isRequired_ = "is_required" in json && json["is_required"].boolean;
                this.isVararg_ = json["is_vararg"].boolean;
                this.isVirtual_ = json["is_virtual"].boolean;
                this.hash_ = json["hash"].integer;
                this.isProtected_ = json["name"].str[0] == '_';
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        super.finalize(registry);

        if (return_)
            this.parent_.use(return_);

        foreach(param; params_)
            this.parent_.use(param.type);
    }
}

/**
    A signal.
*/
class GDESignal : GDEFunc {
private:

public:

}

/**
    A class property
*/
class GDEProperty : GDEMember {
private:
    GDEClass parent_;

    string typeName_;
    GDEType type_;

    string getterName_;
    GDEMethod getter_;

    string setterName_;
    GDEMethod setter_;

    long index_ = -1;

public:

    /**
        Name of the property as a valid D identifier.
    */
    override @property string d_name() => this.name.toCamelCase.filterReserved;

    /**
        Parent class of the method.
    */
    @property GDEClass parent() => parent_;

    /**
        Type of the property.
    */
    override @property GDEType type() => type_;

    /**
        Getter of the property.
    */
    @property GDEMethod getter() => getter_;

    /**
        Setter of the property.
    */
    @property GDEMethod setter() => setter_;

    /**
        Index for getter and setter, or $(D -1).
    */
    @property long index() => index_;

    /**
        Instantiates a new property.
    */
    this(GDEClass parent) {
        this.parent_ = parent;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);

        switch(schema) {
            case API_SCHEMA:
                super.name = json["name"].str;
                this.typeName_ = json["type"].str;

                if ("getter" in json)
                    this.getterName_ = json["getter"].str;

                if ("setter" in json)
                    this.setterName_ = json["setter"].str;

                if ("index" in json)
                    this.index_ = json["index"].integer;

                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        this.type_ = GDEType.fromGodotType(typeName_, registry);
        this.parent_.use(type_);

        this.getter_ = cast(GDEMethod)registry.find(getterName_);
        this.setter_ = cast(GDEMethod)registry.find(setterName_);   
    }
}

/**
    A class.
*/
class GDEClass : GDEAggregate {
private:
    string inheritsName_;
    GDEClass inherits_;

    GDETypeRegistry subregistry;

    string apiType_;
    bool isInstantiable_;
    GDEManifestConstant[] constants_;
    GDEEnum[] enums_;
    GDEMethod[] methods_;
    GDESignal[] signals_;
    GDEProperty[] properties_;
    GDEType[] used_;

public:
    override @property GDEMember[] members() => [];

    /**
        D name of the class
    */
    override @property string d_name() => name.filterReserved();

    /**
        Types used by this class.
    */
    @property GDEType[] used() => used_;

    /**
        The class this class inherits.
    */
    @property GDEClass inherits() => inherits_;
    
    /**
        The constants of the class
    */
    @property ref GDEManifestConstant[] constants() => constants_;
    
    /**
        The enums of the class
    */
    @property ref GDEEnum[] enums() => enums_;
    
    /**
        The methods of the class
    */
    @property ref GDEMethod[] methods() => methods_;
    
    /**
        The signals of the class
    */
    @property ref GDESignal[] signals() => signals_;
    
    /**
        The properties of the class
    */
    @property ref GDEProperty[] properties() => properties_;

    /**
        Whether the class can be instantiated.
    */
    @property ref bool isInstantiable() => isInstantiable_;

    /**
        The API Type.
    */
    @property string apiType() => apiType_;

    /**
        Constructor.
    */
    this() { }

    /**
        Constructor.
    */
    this(string name, GDEClass inherits, GDETypeRegistry registry) {
        this.subregistry = new GDETypeRegistry(registry);
        this.name = name;
        this.inherits_ = inherits;
    }

    /**
        Marks a type as used by this type.
    */
    void use(GDEType type) {
        if (type is this)
            return;

        if (auto class_t = cast(GDEClass)type) {
            foreach(u; used_)
                if (u == type)
                    return;
            
            used_ ~= type;
        } else if (auto enum_t = cast(GDEEnum)type) {
            if (enum_t.parent) {
                this.use(enum_t.parent);
            }
        } else if (auto const_t = cast(GDEManifestConstant)type) {
            if (const_t.parent) {
                this.use(const_t.parent);
            }
        } else if (auto typedarray_t = cast(GDETypedArray)type) {
            this.use(typedarray_t.type);
        }
    }

    /**
        Gets whether this class or any super class has a method
        with the given name.

        Params:
            named = The D name of the method.

        Returns:
            $(D true) if the type hirearchy has a method with
            thie given name, $(D false) otherwise. 
    */
    bool hasMethod(string named) {
        foreach(method; methods_) {
            if (method.d_name == named)
                return true;
        }
        return inherits ? inherits.hasMethod(named) : false;
    }

    /**
        Finds a subtype within this class.

        Params:
            named = The name of the type to find.
        
        Returns:
            The type on success,
            $(D null) otherwise.
    */
    GDEType findSubtype(string named) {
        foreach(enum_t; enums) {
            if (enum_t.name == named)
                return enum_t;
        }
        return null;
    }

    /**
        Parses the type.
    
        Params:
            json =      The JSON value to parse.
            schema =    The schema being parsed.
            registry =  The type registry.
    */
    override
    void parse(ref JSONValue json, int schema, ref GDETypeRegistry registry) {
        this.ddoc_ = parseDocs(json);
        this.subregistry = new GDETypeRegistry(registry);
        
        switch(schema) {
            case API_SCHEMA:
                this.name = json["name"].str;

                this.isInstantiable_ = json["is_instantiable"].boolean;
                this.apiType_ = json["api_type"].str;
                
                if ("inherits" in json)
                    this.inheritsName_ = json["inherits"].str;
                
                if ("constants" in json) {
                    foreach(const_t; json["constants"].array) {
                        auto const_ = new GDEManifestConstant(this);
                        const_.parse(const_t, schema, registry);
                        constants_ ~= const_;

                        subregistry.add(const_);
                    }
                }
                
                if ("enums" in json) {
                    foreach(enum_t; json["enums"].array) {
                        auto enum_ = new GDEEnum(this);
                        enum_.parse(enum_t, schema, registry);
                        enums_ ~= enum_;

                        subregistry.add(enum_);
                    }
                }
                
                if ("methods" in json) {
                    foreach(method_t; json["methods"].array) {
                        auto method_ = new GDEMethod(this);
                        method_.parse(method_t, schema, registry);
                        methods_ ~= method_;

                        subregistry.add(method_);
                    }
                }
                
                if ("properties" in json) {
                    foreach(prop_t; json["properties"].array) {
                        auto prop_ = new GDEProperty(this);
                        prop_.parse(prop_t, schema, registry);
                        properties_ ~= prop_;

                        subregistry.add(prop_);
                    }
                }
                
                if ("signals" in json) {
                    foreach(signal_t; json["signals"].array) {
                        auto signal_ = new GDESignal();
                        signal_.parse(signal_t, schema, registry);
                        signals_ ~= signal_;
                    }
                }
                return;

            default:
                return;
        }
    }

    /**
        Finalizes the type.

        Params:
            registry =  The type registry.
    */
    override
    void finalize(GDETypeRegistry registry) {
        this.inherits_ = cast(GDEClass)registry.find(inheritsName_);
        this.use(inherits_);
        subregistry.finalize();
    }
}