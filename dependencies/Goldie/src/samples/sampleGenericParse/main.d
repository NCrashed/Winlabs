// Goldie: GOLD Engine for D
// Samples: Sample Generic Parse
// Written in the D programming language.

/++
Parses any source file according to any GOLD language and displays
basic information about both the language and the parsed source.

Try using the included "lang/calc.cgt" language on the "*.calc" files.
Or use your own GOLD language and source.
+/

module samples.sampleGenericParse.main;

import std.stdio;
import semitwist.util.all : getExecPath;

import goldie.all;

int main(string[] args)
{
	if(args.length != 3)
	{
		writeln("Usage: goldie-sampleGenericParse source_file gold_cgt_file");
		writeln();
		writeln("Sample: goldie-sampleGenericParse lang/valid_sample2.calc lang/calc.cgt");
		return 1;
	}
	
	string srcFile  = args[1];
	string langFile = args[2];
	
	// Load language
	Language lang = Language.load(langFile);
	writeln("Grammar Info:");
	writeln("File:    ", lang.filename);
	writeln("Name:    ", lang.name);
	writeln("Version: ", lang.ver);
	writeln("Author:  ", lang.author);
	writeln("About:   ", lang.about);
	writeln();
	
	// Load and parse source
	Parser parser;
	try
		parser = lang.parseFileX(srcFile);
	catch(ParseException e)
	{
		// The source file had an error:
		writeln(e.msg);
		return 1;
	}
	
	Token root = parser.parseTreeX;
	writeln("Root of parse tree:");
	writeln("  type: ", root.typeName);
	writeln("  name: ", root.name);
	writeln();

	Token firstTerminal = root.firstLeaf;
	writeln("First terminal in parse tree:");
	writeln("  type: ", firstTerminal.typeName);
	writeln("  name: ", firstTerminal.name);
	writeln("  content: '", firstTerminal, "'");
	writeln("  line: ", firstTerminal.line);
	writeln();

	Token lastTerminal = root.lastLeaf;
	writeln("Last terminal in parse tree:");
	writeln("  type: ", lastTerminal.typeName);
	writeln("  name: ", lastTerminal.name);
	writeln("  content: '", lastTerminal, "'");
	writeln("  line: ", lastTerminal.line);
	writeln();

	writefln("Root of parse tree has %s child node(s):", root.length);
	foreach(size_t i, Token tok; root)
	{
		if(tok.type == SymbolType.NonTerminal)
		{
			writefln("  Node index %s is a NonTerminal '%s' with %s child node(s)",
			                i, tok.name, tok.length);
			writefln("    and content '%s'", tok);
			writefln("    and raw content:");
			writeln(parser.lexer.source[tok.srcIndexStart..tok.srcIndexEnd]);
		}
		else
		{
			writefln("  Node index %s is a %s '%s'", i, tok.typeName, tok.name);
		}
	}

	return 0;
}
