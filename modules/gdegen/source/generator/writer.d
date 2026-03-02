module generator.writer;
import generator.types;
import generator.ddoc;
import generator.utils;

import std.outbuffer;
import std.stdio;
import std.string;
import std.format : format;
import std.array : join;

/**
    Class which abstracts writing a binding file.
*/
class GDEWriter {
private:
    File file;
    OutBuffer buffer;
    Indent indents;
    string currLine;
    string lastLine;
    bool hadText = false;


    bool isOnNewLine;
    void writeNewline() {
        if (isOnNewLine)
            this.writeIndent();

        buffer.write('\n');
        isOnNewLine = true;

        lastLine = currLine;
        currLine = "";
    }

    void markWritten() {
        isOnNewLine = false;
    }

    void writeIndent() {
        if (isOnNewLine) {
            this.writeOne(indents.indent);
        }
    }

    void writeOne(string line) {
        this.markWritten();

        buffer.write(line);
        currLine ~= line;
    }

    string[] formatLines(Args...)(string fmt, Args args) {
        return fmt.format(args).splitLines;
    }

    bool wasGraphical() {
        import std.uni : byCodePoint, isSymbol, isAlpha, isAlphaNum;
        foreach(p; lastLine.byCodePoint()) {
            if (isSymbol(p) || isAlpha(p) || isAlphaNum(p))
                return true;
        }
        return false;
    }

public:

    /**
        Constructs a new GDEFileBuffer.
    
        Params:
            path =      Path to the file to write.
            overwrite = Whether to overwrite the file or append to it.
    */
    this(string path, bool overwrite = true) {
        this(File(path, overwrite ? "w+b" : "a+b"));
    }

    /**
        Constructs a new GDEFileBuffer.
    
        Params:
            file = The file to write to, can be $(D null).
    */
    this(File file = File.init) {
        this.buffer = new OutBuffer();
        this.file = file;
    }

    /**
        Pushes indentation to the indentation stack.

        Params:
            spaces = How many spaces to indent by, can be negative.
    */
    void indent(int spaces) {
        indents.push(spaces);
    }

    /**
        Pops an indentation from the stack.
    */
    void unindent() {
        indents.pop();
    }

    /**
        Writes the given format string with the given arguments.

        Params:
            fmt =   The format string to write.
            args =  The arguments to pass to the formatter.
    */
    void writef(Args...)(string fmt, Args args) {
        if (fmt.length == 0)
            return;
        
        auto lines = this.formatLines(fmt, args);
        foreach(i, line; lines) {
            this.writeIndent();
            this.writeOne(line);

            if (i+1 != lines.length)
                this.writeNewline();
        }
    }

    /**
        Writes a line with the given format string and the given arguments.

        Params:
            fmt =   The format string to write.
            args =  The arguments to pass to the formatter.
    */
    void writefln(Args...)(string fmt, Args args) {
        if (fmt.length == 0)
            return;
        
        auto lines = this.formatLines(fmt, args);
        foreach(line; lines) {
            this.writeIndent();
                this.writeOne(line);
            this.writeNewline();
        }
    }

    /**
        Writes text to the buffer.

        Params:
            text = The text to write.
    */
    void write(string text) {
        if (text.length == 0)
            return;

        auto lines = text.splitLines();
        foreach(i, line; lines) {
            this.writeIndent();
                this.writeOne(line);

            if (i+1 != lines.length)
               this.writeNewline();
        }
    }

    /**
        Writes a line to the buffer.

        Params:
            text = The text to write.
    */
    void writeln(string text) {
        if (text.length == 0)
            return;

        auto lines = text.splitLines();
        foreach(line; lines) {
            this.writeIndent();
                this.writeOne(line);
            this.writeNewline();
        }
    }

    /**
        Writes newlines for the given amount of lines, if the last line
        contained graphical characters.

        Params:
            lines = How much lines of space to create between the previous line.
    */
    void writenls(int lines = 1) {
        if (wasGraphical) {
            foreach(i; 0..lines)
                this.writeNewline();
        }
    }

    /**
        Writes a post-indent on the current line.

        Params:
            by = how many spaces to post-indent by.
    */
    void postindent(size_t by) {
        buffer.fill(by, ' ');

        // HACK: yeah this is ugly, but oh well.
        char[] toAdd = new char[by];
        toAdd[0..by] = ' ';
        lastLine ~= toAdd;
    }

    /**
        Flushes the buffer to file.
    */
    void flush() {
        if (file.isOpen)
            file.write(this.toString());
    }

    /**
        Gets the final string representation of the written file.
    */
    override string toString() const {
        return buffer.toString();
    }
}

/**
    A writer that writes DLang bindings.
*/
class GDEBindingWriter : GDEWriter {
private:
    uint commentDepth = 0;

public:

    /**
        Constructs a new GDEFileBuffer.
    
        Params:
            path =      Path to the file to write.
            overwrite = Whether to overwrite the file or append to it.
    */
    this(string path, bool overwrite = true) {
        super(path, overwrite);
    }

    /**
        Constructs a new GDEFileBuffer.
    
        Params:
            file = The file to write to, can be $(D null).
    */
    this(File file = File.init) {
        super(file);
    }

    /**
        Begins a new block.
    */
    void beginBlock() {
        this.writeln("{");
        this.indent(4);
    }

    /**
        Ends the most recently begun block.
    */
    void endBlock(bool newline=true) {
        this.unindent();
        this.writeOne("}");

        if (newline)
            this.writeNewline();
    }

    /**
        Begins a new comment section.

        Params:
            docComment = Whether the comment is a documentation comment.
    */
    void beginComment(bool docComment = false) {
        this.writenls();

        if (docComment)
            this.writeln(commentDepth % 2 == 0 ? "/**" : "/++");
        else
            this.writeln(commentDepth % 2 == 0 ? "/*" : "/+");
        this.indent(4);
        commentDepth++;
    }

    /**
        Ends the most recently begun comment section.
    */
    void endComment() {
        if (commentDepth > 0) {
            commentDepth--;
            this.unindent();
            this.writeln(commentDepth % 2 == 0 ? "*/" : "+/");
        }
    }

    /**
        Writes a DDOC comment.

        Params:
            ddoc =  The DDOC comment string to write.
    */
    void writeDDOC(string ddoc) {
        this.beginComment();

            this.writeln(ddoc);

        this.endComment();
    }

    /**
        Writes a DDOC comment.

        Params:
            ddoc =  The DDOC comment to write.
    */
    void writeDDOC(DDOC ddoc) {
        if (ddoc.hasDoc) {
            this.beginComment(true);

                ddoc.writeTo(this);

            this.endComment();
        }
    }

    /**
        Writes the given type to file.

        Params:
            type =  The type to write.
    */
    void writeType(GDEType type) {
        this.writenls();
        
        // Enumerations
        if (auto enum_t = cast(GDEEnum)type) {
            this.writeDDOC(enum_t.ddoc);
            this.writef("enum %s ", enum_t.name);
            this.beginBlock();
            
                foreach(member_t; enum_t.members) {
                    this.writeDDOC(member_t.ddoc);
                    this.writefln("%s = %s,", member_t.name, member_t.value);
                }

            this.endBlock();
            
            foreach(member_t; enum_t.members) {
                this.writeDDOC(member_t.ddoc);
                this.writefln("enum %s %s = %s.%s;", enum_t.name, member_t.name, enum_t.name, member_t.name);
            }
            return;
        }
        
        // Data structures
        if (auto struct_t = cast(GDEStruct)type) {
            this.writeDDOC(struct_t.ddoc);
            this.writef("struct %s ", struct_t.name);
            this.beginBlock();
            
                foreach(member_t; struct_t.members) {
                    this.writeDDOC(member_t.ddoc);
                    this.writefln("%s %s;", member_t.type.name, member_t.name);
                }

            this.endBlock();
            return;
        }
        
        // Function prototypes
        if (auto fp_t = cast(GDEFuncPrototype)type) {
            this.writeDDOC(fp_t.ddoc);
            this.writefln("alias %s = %s function(%s);", fp_t.name, fp_t.returnType.name, fp_t.params.toParamList(true).join(", "));
            return;
        }
        
        // Function definitions
        if (auto func_t = cast(GDEFunc)type) {
            this.writeDDOC(func_t.ddoc);
            this.writefln("%s function(%s) %s;", func_t.returnType.name, func_t.params.toParamList(true).join(", "), func_t.name);
            return;
        }

        // Aliases
        if (auto alias_t = cast(GDEAlias)type) {
            this.writeDDOC(alias_t.ddoc);
            this.writefln("alias %s = %s;", alias_t.name, alias_t.type.name);
            return;
        }

        // Handles
        if (auto handle_t = cast(GDEHandle)type) {
            this.writeDDOC(handle_t.ddoc);
            this.writefln("alias %s = %s;", handle_t.name, handle_t.type.name);
        }
    }

    /**
        Writes a module header to the file.

        Params:
            info =  The info about the module to write.
            name =  The name/path of the module.
    */
    void writeHeader(DDOC info, string name) {
        this.writeDDOC(info);
        this.writefln("module %s;", name);
    }
    /**
        Writes an import to the file.

        Params:
            module_ =   The module to import.
    */
    void writeImport(string module_) {
        this.writefln("import %s;", module_);
    }

    /**
        Writes an alias declaration to the file.

        Params:
            name =  Name of the alias.
            to =    The type the alias is an alias to.
    */
    void writeAlias(string name, string to) {
        this.writefln("alias %s = %s;", name, to);
    }

    /**
        Begins a version block.

        Params:
            identifier = The identifier for the block.
    */
    void beginVersionBlock(string identifier) {
        this.writef("version(%s) ", identifier);
        this.beginBlock();
    }
}

// Helper struct that handles indentation more efficiently.
struct Indent {
private:
    int[] indents;
    string indentString;
    int indentTotal;

    void update() {
        indentTotal = 0;
        foreach(indent; indents)
            indentTotal += indent;
        
        if (indentTotal > indentString.length) {
            int toAdd = indentTotal-cast(int)indentString.length;
            foreach(i; 0..toAdd)
                indentString ~= ' ';
        }
    }

public:

    /**
        A string representing the indentation stored in the indent.
    */
    @property string indent() => indentString[0..indentTotal];

    /**
        How many characters of indentation are being done.
    */
    @property int count() => indentTotal;

    /**
        How deep the indentation goes.
    */
    @property int depth() => cast(int)indents.length;

    /**
        Pushes indentation to the indentation stack.

        Params:
            spaces = How many spaces to push.
    */
    void push(int spaces) {
        indents ~= spaces;
        this.update();
    }

    /**
        Pops indentation from the indentation stack.
    */
    void pop() {
        if (indents.length > 0) {
            indents.length--;
            this.update();
        }
    }
}