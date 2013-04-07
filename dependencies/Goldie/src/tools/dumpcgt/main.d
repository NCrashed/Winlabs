// Goldie: GOLD Engine for D
// Tools: Dump CGT
// Written in the D programming language.
//
// Dumps a CGT file to human-readable text.

//TODO? Output BOM
//TODO*: Use same character-escaping algorithm that grmc's DOT-output uses.

module tools.dumpcgt.main;

import getopt = std.getopt;
import std.path;
import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.all;
import tools.util;

immutable helpInfoMsg =
`Dumps a CGT file to a human-readable text file.

Usage: goldie-dumpcgt [options] <inputfile> [options]

Examples:
  goldie-dumpcgt language.cgt
  goldie-dumpcgt language.cgt --out=language.cgt.txt

Options:
  --help, /?            Displays this help screen
  -o, --out <filename>  Output filename (default is '<inputfile w/o path>.txt')
  -n, --no-filename     Don't include the CGT's filename in the dump
`;

int main(string[] args)
{
	auto helpInfoScreen = 
		helpInfoHeader("Dump CGT", "2009-2012 Nick Sabalausky") ~ "\n\n" ~ helpInfoMsg;
	
	if(args.length == 1)
	{
		write(helpInfoScreen);
		return 0;
	}

	bool help;
	bool noFilename;
	string outFilename;
	getopt.endOfOptions = "";
	try getopt.getopt(
		args,
		getopt.config.caseSensitive,
		"help",           &help,
		"o|out",          &outFilename,
		"n|no-filename",  &noFilename,
	);
	catch(Exception e)
	{
		stderr.writeln(e.msg);
		stderr.writeln(suggestHelpMsg);
		return 1;
	}
	
	if(help || args.contains("/?"))
	{
		writeln(helpInfoScreen);
		return 0;
	}
	
	if(args.length < 2)
	{
		stderr.writeln("Must specify an input CGT file.");
		stderr.writeln(suggestHelpMsg);
		return 1;
	}
	
	if(args.length > 2)
	{
		stderr.writeln("Can only specify one input CGT file.");
		stderr.writeln(suggestHelpMsg);
		return 1;
	}
	
	string cgtFile = args[1];
	if(outFilename == "")
		outFilename = baseName(cgtFile) ~ ".txt";

	// Open files
	auto lang = Language.load(cgtFile);
	auto output = File(outFilename, "w");

	void rawWritefln(T...)(string formatStr, T args)
	{
		output.rawWrite(formatStr.format(args));
		output.writeln();
	}

	if(!noFilename)
		rawWritefln("File    : %s", lang.filename);
	rawWritefln("Name    : %s", lang.name);
	rawWritefln("Version : %s", lang.ver);
	rawWritefln("Author  : %s", lang.author);
	rawWritefln("About   : %s", lang.about);
	rawWritefln("Case Sensitive : %s", lang.caseSensitive);
	rawWritefln("");
	
	rawWritefln("Start Symbol Index  : %s", lang.startSymbolIndex);
	rawWritefln("EOF Symbol Index    : %s", lang.eofSymbolIndex);
	rawWritefln("Error Symbol Index  : %s", lang.errorSymbolIndex);

	rawWritefln("Symbol Table (Length %s) ->", lang.symbolTable.length);
	foreach(int i, Symbol sym; lang.symbolTable)
	{
		rawWritefln(
			"  [%-4s] : %-12s: %s",
			i, symbolTypeToString(sym.type), sym.name
		);
	}
	rawWritefln("");
	
	rawWritefln("Character Set Table (Length %s) ->", lang.charSetTable.length);
	foreach(int i, CharSet charSet; lang.charSetTable)
	{
		dstring charSetStr = charSet.toRawChars();
		rawWritefln("  [%-4s] : %s", i, charSetStr);
	}
	rawWritefln("");
	
	rawWritefln("Initial DFA State : %s", lang.initialDFAState);
	rawWritefln("DFA Table (Length %s) ->", lang.dfaTable.length);
	foreach(int i, DFAState state; lang.dfaTable)
	{
		rawWritefln(
			"  [%-4s] : Accept Symbol #%s: %s, %s Edge%s",
			i, state.acceptSymbolIndex, state.accept, state.edges.length,
			state.edges.length==0? "s" : state.edges.length==1? " ->" : "s ->"
		);
		if(state.edges.length > 0)
		{
			foreach(int iEdge, DFAStateEdge edge; state.edges)
			{
				rawWritefln(
					"           [%-4s] : Char Set #%-4s : Target DFA State #%-4s",
					iEdge, edge.charSetIndex, edge.targetDFAStateIndex
				);
			}
		}
	}
	rawWritefln("");
	
	rawWritefln("Rule Table (Length %s) ->", lang.ruleTable.length);
	foreach(int i, Rule rule; lang.ruleTable)
	{
		string ruleStr = lang.symbolTable[rule.symbolIndex].name ~ " ::=";
		ruleStr =
			reduceTo(rule.subSymbolIndicies, ruleStr,
				(string str, int i)
				{
					return str ~ " " ~ lang.symbolTable[i].name;
				}
			);
		
		rawWritefln("  [%-4s] : %s", i, ruleStr);
	}
	rawWritefln("");
	
	rawWritefln("Initial LALR State : %s", lang.initialLALRState);
	rawWritefln("LALR State Table (Length %s) ->", lang.lalrTable.length);
	foreach(int i, LALRState state; lang.lalrTable)
	{
		rawWritefln(
			"  [%-4s] : %s Action%s", i, state.actions.length,
			state.actions.length==0? "s" : state.actions.length==1? " ->" : "s ->"
		);

		foreach(int iAct, LALRAction action; state.actions)
		{
			string targetStr;
			switch(action.type)
			{
			case LALRAction.Type.Shift:
				targetStr = " to LALR State #%s".format(action.target);
				break;
			case LALRAction.Type.Goto:
				targetStr = " LALR State #%s".format(action.target);
				break;
			case LALRAction.Type.Reduce:
				targetStr =
					" to %s (Rule #%s)".format(
						lang.symbolTable[lang.ruleTable[action.target].symbolIndex].name,
						action.target
					);
				break;
			case LALRAction.Type.Accept:
				targetStr = " (Unused Index #%s)".format(action.target);
				break;
			default:
				throw new Exception("Internal Error: Unexpected action type #%s".format(action.type));
			}

			rawWritefln(
				"           [%-4s] : If '%s' (#%s), %s%s",
				iAct, lang.symbolTable[action.symbolId].name, action.symbolId,
				LALRAction.typeToString(action.type), targetStr
			);
		}
	}
	rawWritefln("");
	
	return 0;
}
