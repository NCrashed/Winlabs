// Goldie: GOLD Engine for D
// Tools: Parse
// Written in the D programming language.

/++
Parses a source file according to a cgt file, and saves the result
to a JSON file.

XML output is also supported, but the JSON support is much better.
+/

//TODO: Why does "Saving Tokens" appear before the lex errors?
//TODO: See about getting rid of recursion in pt->json so lexSpeedTest.d/dlex.grm
//      doesn't overflow the callstack on windows.

module tools.parse.main;

import std.stdio;
import std.file;

import semitwist.treeout;
import semitwist.util.all;

import goldie.all;

import tools.parse.cmd;
import tools.util;

int main(string[] args)
{
	flushAsserts(); // For unittests
	
	Options cmd;
	int errLevel = cmd.process(args);
	if(errLevel != -1)
		return errLevel;

	if(cmd.debugOut)
	{
		writefln("Input File: %s", cmd.inputFilename);
		writefln("Language: %s", cmd.lang);
		writefln("Language File: %s", cmd.langFile);
		writefln("Language Source: %s", cmd.langSrc);
	}

	auto goldLang = Language.load(cmd.langFile);
	auto parseTree =
		process(
			cmd.inputFilename, goldLang,
			cmd.parseTreeOut, cmd.tokensOut,
			cmd.formatter
		);
	
	if(parseTree is null)
		return 1;
/+
	// Stuff for a future source-processing tool
	writefln("------- Getting Ready to Generate AST:");
	write("Loading Gold Plus...");
	stdout.flush();
	auto lang = Goldie.loadLanguage("grmp");
	writeln("Done!");
	writef("Loading '%s' Language Source...", cmd.lang);
	auto grmParseTree =
		process(
			cmd.langSrc, lang,
			"", "",
			null, null
		);
	writeln("Done!");
	
	//TODO: Associate 'grmParseTree' with 'lang' and apply to parseTree to obtain AST
+/
	return 0;
}

string genTreeStr(Token rootTok, TreeFormatter formatter, string inputFilename, string source)
{
	auto parseTreeRoot = rootTok.toTreeNode();
	parseTreeRoot.addAttribute("file", inputFilename);
	parseTreeRoot.addAttribute("parseTreeMode", "true");
	parseTreeRoot.addAttribute("source", source);
	return parseTreeRoot
	       .format(formatter);
}

string genTokenTreeStr(Token[] tokens, Language lang, TreeFormatter formatter, string inputFilename, string source)
{
	return genTreeStr(
		new Token(
			Symbol("Tokens", SymbolType.NonTerminal, -1),
			tokens, lang, -1
		),
		formatter, inputFilename, source
	);
}

// T must be either Token or Token[]
void saveTree(T)(T tokens, Language lang, TreeFormatter formatter, string label,
                 string outFilename, string inputFilename, string source)
{
	if(formatter)
	{
		writef("Saving %s (%s)...", label, outFilename);
		stdout.flush();
		
		string treeStr;
		static if(is(T:Token))
			treeStr = genTreeStr(tokens, formatter, inputFilename, source);
		else static if(is(T:Token[]))
			treeStr = tokens.genTokenTreeStr(lang, formatter, inputFilename, source);
		else
			static assert(false, "'T tokens' is type '"~T.stringof~"', but must be either type 'Token' or 'Token[]'");
			
		saveFile(outFilename, cast(ubyte[])treeStr);
		writeln("Done!");
	}
}

// Returns: Root 'Token' of parse tree, or null if failed to parse.
Token process(string inputFilename, Language lang,
              string parseTreeOut, string tokensOut, 
              TreeFormatter formatter)
{
	Lexer lexer;
	bool lexOk = true;
	try
		lexer = lang.lexFileX(inputFilename);
	catch(ParseException e)
	{
		write(e.msg);
		stdout.flush();
		lexer = e.lexer;
		lexOk = false;
	}
	auto tokens = lexer.tokens;
	if(tokensOut != "")
		saveTree(tokens, lang, formatter, "Tokens", tokensOut, inputFilename, lexer.source);
	if(!lexOk)
		return null;

	Parser parser;
	try
		parser = lang.parseTokensX(tokens, inputFilename, lexer);
	catch(ParseException e)
	{
		writeln(e.msg);
		return null;
	}
	auto parseTree = parser.parseTreeX;
	if(parseTreeOut != "")
		saveTree(parseTree, lang, formatter, "Parse Tree", parseTreeOut, inputFilename, lexer.source);

	return parseTree;
}

void saveFile(string filename, ubyte[] data)
{
	std.file.write(filename, data);
	//auto outFile = new File(filename, File.WriteCreate);
	//auto bytesWritten = outFile.output.write(data);
	//outFile.close();
	
	/+if(bytesWritten != data.length)
		throw new Exception(
			"Failed to write entire file: %s: Wrote %s out of %s bytes."
				.format(filename, bytesWritten, data.length));+/
}
