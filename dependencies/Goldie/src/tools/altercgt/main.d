// Goldie: GOLD Engine for D
// Tools: Alter CGT
// Written in the D programming language.
//
// Manipulates the internl structure of a CGT file, producing a
// functionally-equivalent CGT file.
//
// Useful for adjusting a CGT to be easier to compare with a CGT
// made by another tool.

module tools.altercgt.main;

import std.file;
import std.stdio;

import semitwist.util.all;
import goldie.all;
import tools.util;

import tools.altercgt.cmd;
import tools.altercgt.commands;

mixin(setVerboseSectionCond!"options.verbose");

int main(string[] args)
{
	int errLevel = options.process(args);
	if(errLevel != -1)
		return errLevel;
	
	auto lang = options.lang;
	
	try
	{
		foreach(cmd; options.commands)
			cmd.run();
	}
	catch(CmdException e)
	{
		stderr.writeln(e.msg);
		stderr.writeln("Error occurred, not saving.");
		return 1;
	}
	
	if(options.bakFile)
	{
		mixin(verboseSection!"Backing up CGT");
		copy(options.inFile, options.bakFile);
	}
	
	{
		mixin(verboseSection!"Saving CGT");
		lang.save(options.outFile);
	}

	return 0;
}
