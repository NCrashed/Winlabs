// Goldie: GOLD Engine for D
// Tools: Alter CGT
// Written in the D programming language.

// Handle command line args

module tools.altercgt.cmd;

import std.algorithm;
import getopt = std.getopt;
import std.path;
import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.all;
import tools.util;

import tools.altercgt.commands;

mixin(setVerboseSectionCond!"options.verbose");

// These messages should be space-indented
immutable helpMsg =
`Manipulates the internal structure of a CGT file, producing a
functionally-equivalent CGT file.

Usage:    goldie-altercgt [options] input.cgt [options] commands [options]

Examples: goldie-altercgt myLang.cgt remap-symbols=1:5,3:7 clean-lalr-actions
          goldie-altercgt myLang.cgt -o=output.cgt RS=1:5,3:7 CLA

A backup of the input cgt file (named '<input filename>.bak') will be created
unless either '-o,--out' or '--no-backup' is specified.

Commands will be applied in the order given. Giving multiple commands is like
running 'goldie-altercgt' separately for each command, but without all the
extra disk I/O.

Options:
  --help, /?            Displays this help summary and exits
  --help <command>      Displays detailed help for a specific command.
                        Use exactly '--help' and '<command>'. It won't work
                        with '/?' or with '=' like the other options do.
  -o, --out <filename>  Output filename (implies --no-backup)
  -v, --verbose         Verbose, displays progress and timings for each step
  --no-backup           Don't create a backup of the input file (see above)

Commands:
(The '=' signs are required)
(See 'goldie-altercgt --help <command>' for details)
  RS,  remap-symbols=<remap-list>   Remap the symbol table
  RC,  remap-charsets=<remap-list>  Remap the character set table
  RR,  remap-rules=<remap-list>     Remap the rule table
  RD,  remap-dfa=<remap-list>       Remap the DFA table
  RL,  remap-lalr=<remap-list>      Remap the LALR table
  RLA, remap-lalr-actions#<lalr-state-id>=<remap-list>
                               Remap the actions in LALR state <lalr-state-id>

  SS,  shift-symbols=<shift-list>   Shift symbols in the symbol table
  SC,  shift-charsets=<shift-list>  Shift elements in the character set table
  SR,  shift-rules=<shift-list>     Shift rules in the rule table
  SD,  shift-dfa=<shift-list>       Shift states in the DFA table
  SL,  shift-lalr=<shift-list>      Shift states in the LALR table
  SLA, shift-lalr-actions#<lalr-state-id>=<remap-list>
                               Shift the actions in LALR state <lalr-state-id>

  MS,  match-symbols=<cgt-file>     Rearrange symbol table to match <cgt-file>

  CLA, clean-lalr-actions           Clean up the actions in each LALR state`;

immutable remapMsg =
`Remap Command:
  remap-symbols=<remap-list>      RS=<remap-list>
  remap-charsets=<remap-list>     RC=<remap-list>
  remap-rules=<remap-list>        RR=<remap-list>
  remap-dfa=<remap-list>          RD=<remap-list>
  remap-lalr=<remap-list>         RL=<remap-list>

  remap-lalr-actions#<lalr-state-id>=<remap-list>
  RLA#<lalr-state-id>=<remap-list>

Examples: goldie-altercgt myLang.cgt remap-symbols=1:5,3:7
          goldie-altercgt myLang.cgt RS=1:5,3:7

          goldie-altercgt myLang.cgt remap-lalr=1:5,3:7
          goldie-altercgt myLang.cgt RL=1:5,3:7

          goldie-altercgt myLang.cgt remap-lalr-actions#5=0:2,4:1
          goldie-altercgt myLang.cgt RLA#5=0:2,4:1

Remap the elements in a table or a specific LALR state by providing a 1:1
mapping of old ID numbers to new ID numbers. Not all elements need to be
provided.

<lalr-state-id>
  If remapping LALR actions, then this is a non-negative integer that specifies
  which LALR state's actions to remap.

<remap-list>
  A comma-separated list of 'before:after' non-negative integer pairs.
  Whitespace is allowed before and after each integer, but make sure you
  properly escape any whitespace within your shell.

  In each pair, the first integer is the current ID number of an element.
  The second integer is the ID number that same element will be moved to in
  the new CGT.
  
  Unlike the shift commands, the elements in between 'before' and 'after'
  will NOT move.
  
  Example (to swap IDs #0 and #51):
    0:51,51:0

  The pairs in each list behave as if they were executed at the same time.
  This means that:

  - The order of the pairs within the comma-separated list makes no
    difference. For example, '1:2,3:4' is exactly the same as '3:4,1:2'.

  - The list '2:4,2:7' is an error since you can't move an element to two
    different new IDs. Likewise, '4:2,7:2' is an error because you can't
    move two elements to the same ID. Redundant entries like '2:4,2:4'
    and no-op entires like '2,2' are also errors.

  After all elements are moved according to your list, any displaced symbols
  are moved into the empty spots in sorted order. For example,
  '1:9, 2:8, 3:7' displaces #9, #8 and #7 while leaving #1, #2 and #3
  empty. So after the three specified moves are performed, #7 is implicitly
  moved to #1, #8 is moved to #2, and #9 is moved to #3. If you don't want
  them implicitly moved this way, then specify them explicitly.

  If you use --verbose, the implicit moves will be shown.

Note on separate commands:
  Separate commands are executed in order. So the following two examples do
  *NOT* have the same effect:

    A: goldie-altercgt myLang.cgt RS=1:2,2:3
    B: goldie-altercgt myLang.cgt RS=1:2 RS=2:3

  (The same applies to all remap commands.)

  Suppose #1 contains the data 'A', #2 contains 'B', and #3 contains 'C'.

  In A, '1:2' and '2:3' behave as if they were executed at the same time:
      The old #1 ('A') moves to #2, and the *old* #2 ('B') moves to #3.
      Since the old #3 ('C') is left, it's implicitly moved to the gap left
      at position #1.

          Result: #1 is 'C', #2 is 'A', #3 is 'B'.

  In B, '1:2' and '2:3' are executed in order:
      With 'RS=1:2', the old #1 ('A') moves to #2, and the old #2 ('B') is
      implicitly moved to the gap left at position #1.

          Temporary result: #1 is 'B', #2 is 'A', #3 is 'C'.

      *Then*, with 'RS=2:3' the *new* #2 ('A') moves to #3, and #3 ('C') is
      implicitly moved to the gap left at position #2.

          Result: #1 is 'B', #2 is 'C', #3 is 'A'.`;

immutable shiftMsg =
`Shift Command:
  shift-symbols=<shift-pair>      SS=<shift-pair>
  shift-charsets=<shift-pair>     SC=<shift-pair>
  shift-rules=<shift-pair>        SR=<shift-pair>
  shift-dfa=<shift-pair>          SD=<shift-pair>
  shift-lalr=<shift-pair>         SL=<shift-pair>

  shift-lalr-actions#<lalr-state-id>=<shift-pair>
  SLA#<lalr-state-id>=<shift-pair>

Examples: goldie-altercgt myLang.cgt shift-symbols=2-5
          goldie-altercgt myLang.cgt SS=2-5

          goldie-altercgt myLang.cgt shift-lalr=17-0
          goldie-altercgt myLang.cgt SL=17-0

Shift the elements in a table or a specific LALR state by providing a list of
ID numbers and the ID numbers they should be moved to. All elements in between
will shift positions.

<lalr-state-id>
  If shifting LALR actions, then this is a non-negative integer that specifies
  which LALR state's actions to shift.

<shift-pair>
  A pair of non-negative integers separated by '-', such as '4-7' or '8-2'.
  Whitespace is allowed before and after each integer, but make sure you
  properly escape any whitespace within your shell.

  Unlike the remap commands, the elements in between 'before' and 'after'
  WILL shift positions.

  No-op pairs like '2-2' are not allowed.
  
  Example: 2-5
    Element #2 will move forward to position #5. The existing elements #3
    through #5 will be shifted backward to positions #2 through #4.

    If the elements started out as: 'A' 'B' 'C' 'D' 'E' 'F' 'G'
    The result will be:             'A' 'B' 'D' 'E' 'F' 'C' 'G'

  Example: 14-8
    Element #14 will move backward to position #8. The existing elements #8
    through #13 will be shifted forward to positions #9 through #14.`;

immutable matchMsg =
`Match Command:
  match-symbols=<cgt-file>
  MS=<cgt-file>

Examples: goldie-altercgt myLang.cgt match-symbols=2-5
          goldie-altercgt myLang.cgt MS=2-5

Rearrange the elements of the symbol table to match the order in the CGT
file <cgt-file> (for any symbols that both CGTs have in common). Any
symbols the CGTs don't have in common will be placed wherever possible
according to the rules of the 'remap-symbols' command.`;

immutable sortLALRActionsMsg =
`Clean Command:
  CLA
  clean-lalr-actions

Examples: goldie-altercgt myLang.cgt clean-lalr-actions
          goldie-altercgt myLang.cgt CLA

Cleans up the actions within each state of the LALR table.

For each state in the LALR table, this sorts the actions in order of:

  Accept
  Shift
  Goto
  Reduce

Within each of those four groups, the actions are sorted by ID of the
lookahead symbol.

This can be useful after rearranging the symbol table, or for comparing
CGTs generated by Goldie GRMC with ones generated by GOLD Barser Builder.`;

Options options;

struct Options
{
	bool     help;
	string   inFile;
	string   outFile;
	string   bakFile;
	bool     verbose;
	bool     noBackup;
	Cmd[]    commands;
	Language lang;

	// Returns errorlevel program should exit immediately with.
	// If returns -1, everything is OK and program should continue without exiting.
	int process(string[] args)
	{
		auto infoHeader = helpInfoHeader("Alter CGT", "2012 Nick Sabalausky");
		auto fullHelpScreen = infoHeader ~ "\n\n" ~ helpMsg;

		getopt.endOfOptions = "";
		try getopt.getopt(
			args,
			getopt.config.caseSensitive,
			"help",       &help,
			"o|out",      &outFile,
			"v|verbose",  &verbose,
			"no-backup",  &noBackup
		);
		catch(Exception e)
		{
			stderr.writeln(e.msg);
			stderr.writeln(suggestHelpMsg);
			return 1;
		}
		
		if(args.contains("/?") || args.length == 1)
		{
			writeln(fullHelpScreen);
			return 0;
		}

		bool error = false;
		try
		{
			if(help)
			{
				auto parsedCmd = Cmd.parse(args[1]);

				if(parsedCmd.command is null)
					commandNotFoundError(parsedCmd.commandStr);

				writeln(infoHeader);
				writeln();
				writeln(Cmd.getHelp(parsedCmd));
				return 0;
			}
			
			inFile = args[1];

			{
				mixin(verboseSection!"Loading CGT");
				try
					lang = Language.load(inFile);
				catch(LanguageLoadException e)
					throw new CmdParseException("Error: " ~ e.msg);
			}

			{
				mixin(verboseSection!"Parsing Commands");
				foreach(cmdStr; args[2..$])
				{
					auto newCommand = Cmd.create( Cmd.parse(cmdStr) );
					commands ~= newCommand;
				}
			}
		}
		catch(CmdParseException e)
		{
			stderr.writeln(e.msg);
			error = true;
		}

		if(error)
		{
			stderr.writeln(suggestHelpMsg);
			return 1;
		}
		
		if(commands.length == 0)
		{
			stderr.writeln("Must specify one (and only one) CGT file, and then one or more commands.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		if(outFile == "" && !noBackup)
			bakFile = inFile ~ ".bak";

		if(outFile == "")
			outFile = inFile;

		return -1; // All ok
	}
}
