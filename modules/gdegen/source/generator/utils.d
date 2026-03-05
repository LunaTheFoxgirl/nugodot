module generator.utils;
import generator.types;
import std.outbuffer;
import std.format;

/**
    Gets a parameter list from a slice of GDEFuncParam
    parameters.

    Params:
        params =    The parameter list.
        useNames =  Whether names should be added to the list.
    
    Returns:
        An array of parameters formatted as D parameters.
*/
string[] toParamList(GDEFuncParam[] params, bool useNames) {
    string[] result;
    foreach(param; params) {
        if (useNames && param.d_full_name)
            result ~= "%s %s".format(param.type.d_full_name, param.name);
        else
            result ~= param.type.d_full_name;
    }
    return result;
}

/**
    Gets a list of the names of the parameters of a function.

    Params:
        params =    The parameter list.
    
    Returns:
        An array of parameter names.
*/
string[] toParamNames(GDEFuncParam[] params) {
    string[] result;
    foreach(param; params) {
        result ~= param.name;
    }
    return result;
}

/**
    Finds all the types in the given slice that are
    implicitly castable to $(D T).

    Params:
        slice = The slice to search in.
*/
T[] findTypes(T, U)(U[] slice) {
    T[] result;
    foreach(item; slice)
        if (cast(T)item)
            result ~= cast(T)item;
    return result;
}

/**
    Converts the given text from PascalCase to snake_case.

    Params:
        text = The text to convert.
    
    Returns:
        The text as snake case.
*/
string toSnakeCase(string text) {
    import std.string : toLower;
    import std.ascii : isUpper, isLower, isDigit;

    string result;
    foreach(i, c; text) {
        bool isPrevNumeric = i-1 < text.length && isDigit(text[i-1]);
        bool isNextLower = i+1 < text.length && isLower(text[i+1]);

        if (isUpper(c)) {
            if (i != 0 && isNextLower && !isPrevNumeric)
                result ~= "_";
            
            result ~= toLower(c);
            continue;
        }

        result ~= c;
    }
    return result;
}

/**
    Converts snake_case to camelCase.

    Params:
        text = The text to convert.
    
    Returns:
        The text as camel case.
*/
string toCamelCase(string text) {
    import std.string : toUpper;
    string result;
    
    bool upper;
    foreach(i, c; text) {
        if (c == '_') {        
            if (i != 0)
                upper = true;
            
            continue;
        }

        result ~= upper ? toUpper(c) : c;
        upper = false;
    }

    return result;
}

/**
    Filters the text for reserved D symbols.

    Params:
        text = The text to filter.
    
    Returns:
        The text with D keywords turned into valid 
        symbols.
*/
string filterReserved(string text) {
    switch(text) {
        case "abstract":
        case "alias":
        case "align":
        case "asm":
        case "assert":
        case "auto":
        case "body":
        case "bool":
        case "break":
        case "byte":
        case "case":
        case "cast":
        case "catch":
        case "cdouble":
        case "cent":
        case "cfloat":
        case "char":
        case "class":
        case "const":
        case "continue":
        case "creal":
        case "dchar":
        case "debug":
        case "default":
        case "delegate":
        case "delete":
        case "deprecated":
        case "do":
        case "double":
        case "else":
        case "enum":
        case "export":
        case "extern":
        case "false":
        case "final":
        case "finally":
        case "float":
        case "for":
        case "foreach":
        case "foreach_reverse":
        case "function":
        case "goto":
        case "idouble":
        case "if":
        case "ifloat":
        case "immutable":
        case "import":
        case "in":
        case "inout":
        case "int":
        case "interface":
        case "invariant":
        case "ireal":
        case "is":
        case "lazy":
        case "long":
        case "macro":
        case "mixin":
        case "module":
        case "new":
        case "nothrow":
        case "null":
        case "out":
        case "override":
        case "package":
        case "pragma":
        case "private":
        case "protected":
        case "public":
        case "pure":
        case "real":
        case "ref":
        case "return":
        case "scope":
        case "shared":
        case "short":
        case "static":
        case "struct":
        case "super":
        case "switch":
        case "synchronized":
        case "template":
        case "this":
        case "throw":
        case "true":
        case "try":
        case "typeid":
        case "typeof":
        case "ubyte":
        case "ucent":
        case "uint":
        case "ulong":
        case "union":
        case "unittest":
        case "ushort":
        case "version":
        case "void":
        case "wchar":
        case "while":
        case "with":
            return text~"_";
        
        case "Object":
            return "GDObject";

        case "Error":
            return "GDError";

        case "String":
            return "string";

        default:
            import std.ascii : isAlphaNum;
            string result;
            foreach(c; text) {
                if (!isAlphaNum(c))
                    continue;

                result ~= c;
            }
            return result;
    }
}

/**
    Peeks the given amount of characters from the given buffer.

    Params:
        buffer =    The string buffer to peek into.
        count =     The amount of characters to peek.
    
    Returns:
        A slice with as many characters as is requested if possible,
        otherwise as many as can be fetched are fetched.
*/
string peek(string buffer, size_t count) {
    import std.algorithm : min;
    return buffer[0..min(count, buffer.length)];
}

/**
    Pops the given characters off the string if found.
    
    Params:
        buffer =    The string buffer to pop from.
        wanted =    The wanted string.
    
    Returns:
        The wanted string if it was found,
        otherwise an empty string.
*/
string pop(ref string buffer, string wanted) {
    if (buffer.peek(wanted.length) == wanted) {
        buffer = buffer[wanted.length..$];
        return wanted;
    }
    return null;
}

/**
    Pops a valid C identifier from the buffer.
    
    Params:
        buffer =    The string buffer to pop from.
    
    Returns:
        The popped identifier.
*/
string popIdentifier(ref string buffer) {
    if (buffer.length == 0)
        return null;

    static bool isIden(char c, size_t i) {
        import std.ascii : isAlpha, isAlphaNum;
        return (i == 0 ? isAlpha(c) : isAlphaNum(c)) || c == '_';
    }

    size_t i = 0;
    while(i < buffer.length && isIden(buffer[i], i)) {
        i++;
    }
    
    string result = buffer[0..i].dup;
    buffer = buffer[i..$];
    return result;
}

/**
    Counts characters until the given character is encountered.

    Params:
        buffer =    The buffer to search
        c =         The character to find.
    
    Returns:
        The offset of the character if found,
        $(D -1) otherwise.
*/
ptrdiff_t countUntil(string buffer, char c) {
    foreach(i, bc; buffer)
        if (bc == c)
            return i;
    
    return -1;
}

/**
    Pops all the next whitespace characters from the buffer.
    
    Params:
        buffer =    The string buffer to pop from.
    
    Returns:
        The buffer.
*/
ref string popWhite(ref return string buffer) {
    import std.ascii : isWhite;
    size_t i = 0;
    while(i < buffer.length && isWhite(buffer[i])) { i++; }
    buffer = buffer[i..$];

    return buffer;
}

/**
    Skips ahead in the buffer.

    Params:
        buffer = the buffer.
        amount = The amount to skip.
*/
void skip(ref string buffer, ptrdiff_t amount = 1) {
    if (buffer.length > 0)
        buffer = buffer[amount..$];
}

/**
    Converts the given array to strings, then joins them with
    the given joiner.

    Params:
        args =      The arguments to join.
        joiner =    The string to join them with.
    
    Returns:
        The joined string.
*/
string strJoin(T)(T[] args, string joiner) {
    import std.array : join;
    string[] rargs;
    foreach(arg; args) {
        rargs ~= arg.toString();
    }
    return rargs.join(joiner);
}