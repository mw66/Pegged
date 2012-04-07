/**
 * This module contains the code complementing the Pegged grammar
 * to create an complete pegged.grammar module
 * 
 */
module pegged.development.bootstrap;

import std.array;
import std.algorithm;
import std.stdio;

import pegged.peg;
import pegged.grammar;


void asModule(string moduleName, string grammarString)
{
    asModule(moduleName, moduleName~".d", grammarString);
}

void asModule(string moduleName, string fileName, string grammarString)
{
    import std.stdio;
    auto f = File(fileName,"w");
    
    f.write("/**\nThis module was automatically generated from the following grammar:\n");
    f.write(grammarString);
    f.write("*/\n");
    
    f.write("module " ~ moduleName ~ ";\n\n");
    //f.write("import pegged.peg;\nimport std.array;\nimport std.conv;\n\n");
    f.write(grammar(grammarString));
}

string grammar(string g)
{    
    auto grammarAsOutput = PEGGED.parse(g);
    if (grammarAsOutput.children.length == 0) return `static assert(false, "Bad grammar: ` ~ to!string(grammarAsOutput.capture) ~ `");`;
    
    string[] names;
    foreach(definition; grammarAsOutput.children[0].children)
        if (definition.name == "Definition") 
            names ~= definition.capture[0];
    string ruleNames = "    enum ruleNames = [";
    foreach(name; names)
        ruleNames ~= "\"" ~ name ~ "\":true,";
    ruleNames = ruleNames[0..$-1] ~ "];\n";
    
    string PEGtoCode(ParseTree p)
    {
        string result;
        auto ch = p.children;
        
        switch (p.name)
        {
            case "PEGGED":
                return PEGtoCode(ch[0]);
            case "Grammar":
                bool named = ch[0].name == "GrammarName";
                string grammarName = named ? ch[0].capture[0] 
                                           : names.front;
                
                result = "import std.algorithm, std.array, std.conv;\n"
                       ~ "class " ~ grammarName ~ " : Parser\n{\n" 
                       ~ "    enum name = `"~ grammarName ~ "`;\n"
                       ~ ruleNames ~ "\n"
                       ~
"    static Output parse(Input input)
    {
        mixin(okfailMixin());
        "
~ (named ? "auto p = "~names.front~".parse(input);
        return p.success ? Output(p.text, p.pos, p.namedCaptures,
                                  ParseTree(name, p.success, p.capture, input.pos, p.pos, [p.parseTree]))
                         : fail(p.parseTree.end, p.capture);"
                   
        : "return "~names.front~".parse(input);")
~ "
    }
    
    mixin(stringToInputMixin());

    static ParseTree[] filterChildren(ParseTree p)
    {
        ParseTree[] filteredChildren;
        foreach(child; p.children)
        {
            if (child.name in ruleNames)
                filteredChildren ~= child;
            else
            {
                if (child.children.length > 0)
                    filteredChildren ~= filterChildren(child);
            }
        }
        return filteredChildren;
    }
    
";
                foreach(child; named ? ch[1..$] : ch)
                    result ~= PEGtoCode(child);
                return result ~ "}\n";
            case "Definition":
                string code = "    enum name = `" ~ch[0].capture[0]~ "`;

    static Output parse(Input input)
    {
        mixin(okfailMixin);
        
        auto p = typeof(super).parse(input);
        return p.success ? Output(p.text, p.pos, p.namedCaptures,
                                  ParseTree(`"~ch[0].capture[0]~"`, p.success, p.capture, input.pos, p.pos, 
                                            (p.name in ruleNames) ? [p.parseTree] : filterChildren(p.parseTree)))
                         : fail(p.parseTree.end,
                                (name ~ ` failure at pos ` ~ to!string(p.parseTree.end)) ~ (p.capture.length > 0 ? p.capture[1..$] : p.capture));
    }
    
    mixin(stringToInputMixin());
    ";

                string inheritance;
                switch(ch[1].children[0].name)
                {
                    case "LEFTARROW":
                        inheritance = PEGtoCode(ch[2]);
                        break;
                    case "FUSEARROW":
                        inheritance = "Fuse!(" ~ PEGtoCode(ch[2]) ~ ")";
                        break;
                    case "DROPARROW":
                        inheritance = "Drop!(" ~ PEGtoCode(ch[2]) ~ ")";
                        break;
                    case "ACTIONARROW":
                        inheritance = "Action!(" ~ PEGtoCode(ch[2]) ~ ", " ~ ch[1].capture[1] ~ ")";
                        break;
                    case "SPACEARROW":
                        string temp = PEGtoCode(ch[2]);
                        // changing all Seq in the inheritance list into SpaceSeq. Hacky, but it works.
                        foreach(i, c; temp)
                        {
                            if (temp[i..$].startsWith("Seq!(")) inheritance ~= "Space";
                            inheritance ~= c;
                        }   
                        break;
                    default:
                        inheritance ="ERROR: Bad arrow: " ~ ch[1].name;
                        break;
                }

                return "class " 
                    ~ ch[0].capture[0] // name 
                    ~ (ch[0].capture.length == 2 ? ch[0].capture[1] : "") // parameter list
                    ~ " : " ~ inheritance // inheritance code
                    ~ "\n{\n" 
                    ~ code // inner code
                    ~ "\n}\n\n";
            case "Expression":
                if (ch.length > 1) // OR present
                {
                    result = "Or!(";
                    foreach(i,child; ch)
                        if (i%2 == 0) result ~= PEGtoCode(child) ~ ",";
                    result = result[0..$-1] ~ ")";
                }
                else // one-element Or -> dropping the Or!( )
                    result = PEGtoCode(ch[0]);
                return result;
            case "Sequence":
                if (ch.length > 1)
                {
                    result = "Seq!(";
                    foreach(child; ch) 
                    {
                        auto temp = PEGtoCode(child);
                        if (temp.startsWith("Seq!("))
                            temp = temp[5..$-1];
                        result ~= temp ~ ",";
                    }
                    result = result[0..$-1] ~ ")";
                }
                else
                    result = PEGtoCode(ch[0]);
                return result;
            case "Prefix":
                if (ch.length > 1)
                    switch (ch[0].name)
                    {
                        case "NOT":
                            result = "NegLookAhead!(" ~ PEGtoCode(ch[1]) ~ ")";
                            break;
                        case "LOOKAHEAD":
                            result = "PosLookAhead!(" ~ PEGtoCode(ch[1]) ~ ")";
                            break;
                        case "DROP":
                            result = "Drop!(" ~ PEGtoCode(ch[1]) ~ ")";
                            break;
                        case "FUSE":
                            result = "Fuse!(" ~ PEGtoCode(ch[1]) ~ ")";
                            break;
                        default:
                            break;
                    }
                else
                    result = PEGtoCode(ch[0]);
                return result;
            case "Suffix":
                if (ch.length > 1)
                    switch (ch[1].name)
                    {
                        case "OPTION":
                            result = "Option!(" ~ PEGtoCode(ch[0]) ~ ")";
                            break;
                        case "ZEROORMORE":
                            result = "ZeroOrMore!(" ~ PEGtoCode(ch[0]) ~ ")";
                            break;
                        case "ONEORMORE":
                            result = "OneOrMore!(" ~ PEGtoCode(ch[0]) ~ ")";
                            break;
                        case "NamedExpr":
                            if (ch[1].capture.length == 2)
                                result = "Named!(" ~ PEGtoCode(ch[0]) ~ ", \"" ~ ch[1].capture[1] ~ "\")";
                            else
                                result = "PushName!(" ~ PEGtoCode(ch[0]) ~ ")";
                            break;
                        case "WithAction":
                            result = "Action!(" ~ PEGtoCode(ch[0]) ~ ", " ~ ch[1].capture[0] ~ ")";
                            break;
                        default:
                            break;
                    }
                else
                    result = PEGtoCode(ch[0]);
                return result;
            case "Primary":
                foreach(child; ch) result ~= PEGtoCode(child);
                return result;
            case "Name":
                result = p.capture[0];
                if (ch.length == 1) result ~= PEGtoCode(ch[0]);
                return result;
            case "ArgList":
                result = "!(";
                foreach(child; ch)
                    result ~= PEGtoCode(child) ~ ","; // Wow! Allow  A <- List('A'*,',') 
                result = result[0..$-1] ~ ")";
                return result;
            case "GroupExpr":
                if (ch.length == 0) return "ERROR: Empty group ()";
                auto temp = PEGtoCode(ch[0]);
                if (ch.length == 1 || temp.startsWith("Seq!(")) return temp;
                result = "Seq!(" ~ temp ~ ")";
                return result;
            case "Ident":
                return p.capture[0];
            case "Literal":
                if (p.capture[0].length == 0)
                    return "ERROR: empty literal";
                return "Lit!(\"" ~ p.capture[0] ~ "\")";
            case "Class":
                if (ch.length == 0)
                    return "ERROR: Empty Class of chars []";
                else 
                {
                    if (ch.length > 1)
                    {
                        result = "Or!(";
                        foreach(child; ch)
                        {
                            auto temp = PEGtoCode(child);
                            if (temp.startsWith("Or!("))
                                temp = temp[4..$-1];
                            result ~= temp ~ ",";
                        }
                        result = result[0..$-1] ~ ")";
                    }
                    else
                        result = PEGtoCode(ch[0]);
                }
                return result;
            case "CharRange":
                if (ch.length == 2)
                    return "Range!('" ~ PEGtoCode(ch[0]) ~ "','" ~ PEGtoCode(ch[1]) ~ "')";
                else
                    return "Lit!(\"" ~ PEGtoCode(ch[0]) ~ "\")"; 
            case "Char":
                if (p.capture.length == 2) // escape sequence \-, \[, \] 
                    return p.capture[1];
                else
                    return p.capture[0];
            case "OR":
                foreach(child; ch) result ~= PEGtoCode(child);
                return result;
            case "ANY":
                return "Any";
            default:
                return "";
        }
    }

    return PEGtoCode(grammarAsOutput.parseTree);
}