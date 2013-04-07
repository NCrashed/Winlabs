// Goldie: GOLD Engine for D
// Tools: GRMC: Grammar Compiler
// Written in the D programming language.

/++
Compiles a GOLD .grm file to .cgt

$(WEB http://www.semitwist.com/goldie/, Goldie Homepage)

Author:
$(WEB www.semitwist.com, Nick Sabalausky)

To re-generate the static language used by this app, run
the following command from the main Goldie directory:
    makeBuiltinStaticLangs
+/

//TODO: GOLD allows Terminals named "EOF" or "Error", support this.
//TODO? Disallow set names like {He.llo} (and figure out the rule for what's allowed)
//TODO: Handle "Virtual Terminals"
//TODO: Goldie.compileGrammar* should throw, not send errors to stdout.
//TODO: Warning on unused terminals/nonterminals
//TODO: Maintain toks so later-processing-stage errors can report correct line/col
//TODO: "Rule ... does not produce any terminals"

module tools.grmc.main;

// Actually checking for DMD 2.057 before issuing this message won't work
// in this case because of a weird order-of-evaluation issue.
pragma(msg, "Notice: If you're using DMD 2.057, GRMC won't compile due to DMD Issue #7375");

import std.conv;
import std.datetime;
import std.path;
import std.stdio;
import std.string;

import semitwist.util.all;
import goldie.all;
import tools.util;

import tools.grmc.cmd;

int main(string[] args)
{
	Options cmdArgs;
	int errLevel = cmdArgs.process(args);
	if(errLevel != -1)
		return errLevel;
	
	bool verbose = cmdArgs.verbose;
	
	writeln("Some grammars can take several minutes to compile. Please wait...");
	
	StopWatch sw;
	sw.start();
	scope(exit) if(verbose)
	{
		writeln("Total time: ", sw.peek.msecs, "ms");
		stdout.flush();
	}

	Language lang;
	Language.compileGrammarGoldCompatibility = cmdArgs.goldCompat;
	if(cmdArgs.dot || cmdArgs.verbose)
		lang = Language.compileGrammarFileDebug(cmdArgs.grmFile, cmdArgs.verbose);
	else
		lang = Language.compileGrammarFile(cmdArgs.grmFile);
		
	if(!lang)
		return 1;
	
	if(cmdArgs.verbose)
	{
		writeln("Number of NFA States:  ", lang.nfaNumStates);
		//writeln("Number of raw DFA States: ", lang.dfaRawNumStates);
		writeln("Number of DFA States:  ", lang.dfaTable.length);
		writeln("Number of LALR States: ", lang.lalrTable.length);
	}

	if(cmdArgs.dot)
	{
		string dotFilename;
		string msg;

		{
			dotFilename = cmdArgs.cgtFile~".nfa.dot";
			msg = "Saving NFA to '"~dotFilename~"'";
			mixin(verboseSection!msg);
			std.file.write(dotFilename, lang.nfaDot);
		}

		/+{
			dotFilename = cmdArgs.cgtFile~".dfaRaw.dot";
			msg = "Saving raw unoptimized DFA to '"~dotFilename~"'";
			mixin(verboseSection!msg);
			std.file.write(dotFilename, lang.dfaDot);
		}+/

		{
			dotFilename = cmdArgs.cgtFile~".dfa.dot";
			msg = "Saving DFA to '"~dotFilename~"'";
			mixin(verboseSection!msg);
			std.file.write(dotFilename, lang.dfaDot);
		}
	}

	string msg = "Saving CGT to '"~cmdArgs.cgtFile~"'";
	mixin(verboseSection!msg);
	lang.save(cmdArgs.cgtFile);
	return 0;
}
