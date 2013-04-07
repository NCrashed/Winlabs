// Goldie: GOLD Engine for D
// Tools: GRMC: Grammar Compiler
// Written in the D programming language.

module tools.grmc.cmd;

import std.array;
import getopt = std.getopt;
import std.path;
import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.all;
import tools.util;

struct Options
{
	bool   help;
	string grmFile;
	string cgtFile = "";
	bool   verbose;
	bool   goldCompat;
	bool   dot;

	// Returns errorlevel program should exit immediately with.
	// If returns -1, everything is OK and program should continue without exiting.
	int process(string[] args)
	{
		auto infoHeader = helpInfoHeader("GRMC: Grammar Compiler", "2010-2012 Nick Sabalausky");
		auto helpScreen =
			infoHeader ~ "\n\n" ~ `
				Compiles a GOLD .grm grammar definition file to .cgt

				Usage:   goldie-grmc [options] [grammar file] [options]
				Example: goldie-grmc grammar.grm
				         goldie-grmc grammar.grm -o=output.cgt
				
				Options:
				  --help, /?            Displays this help screen
				  -o, --out <filename>  Output filename
				  -v, --verbose         Verbose, displays progress and timings for each step
				  --gold                Imitate GOLD's output as closely as possible
				  --dot                 Output lexer's NFA and DFA to Graphviz DOT format
			`.normalize()~"\n";

		if(args.length == 1)
		{
			write(helpScreen);
			return 0;
		}

		getopt.endOfOptions = "";
		try getopt.getopt(
			args,
			getopt.config.caseSensitive,
			"help",       &help,
			"o|out",      &cgtFile,
			"v|verbose",  &verbose,
			"gold",       &goldCompat,
			"dot",        &dot
		);
		catch(Exception e)
		{
			stderr.writeln(e.msg);
			stderr.writeln(suggestHelpMsg);
			return 1;
		}
		
		if(help || args.contains("/?"))
		{
			write(helpScreen);
			return 0;
		}

		if(args.length < 2)
		{
			stderr.writeln("Must specify a grammar file.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		if(args.length > 2)
		{
			stderr.writeln("Must specify only one grammar file.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		grmFile = args[1];

		if(cgtFile == "")
			cgtFile = grmFile.baseName().stripExtension()~".cgt";
		
		return -1; // All ok
	}
}
