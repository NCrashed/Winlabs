// Goldie: GOLD Engine for D
// Tools: Alter CGT
// Written in the D programming language.

// Alter CGT's commands

module tools.altercgt.commands;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.string;
import std.typetuple;

import semitwist.util.all;
import goldie.all;
import tools.util;

import tools.altercgt.cmd;
import goldie.grmc.genlalr : sortFinalTable;

mixin(setVerboseSectionCond!"options.verbose");

class CmdParseException : Exception
{
	this(string msg) { super(msg); }
}

class CmdException : Exception
{
	this(string msg) { super(msg); }
}

void commandNotFoundError(string cmdStr)
{
	throw new CmdParseException("Unrecognized command '%s'".format(cmdStr));
}

enum CmdTarget
{
	none,
	symbols,
	charsets,
	rules,
	dfa,
	lalr,
	lalrActions,
}

alias TypeTuple!(CmdRemap, CmdShift, CmdMatch, CmdClean) CommandTypes;

struct ParsedCmd
{
	TypeInfo_Class command;
	CmdTarget target = CmdTarget.none;
	int lalrState = -1; // For CmdTarget.lalrActions
	string data;

	string commandStr; // Includes target, but not lalrState or data
}

class Cmd
{
	ParsedCmd parsedCmd;
	CmdTarget target;
	int lalrState = -1; // Only used for CmdTarget.lalrActions

	this(ParsedCmd parsedCmd)
	{
		this.parsedCmd = parsedCmd;
		this.target    = parsedCmd.target;
		this.lalrState = parsedCmd.lalrState;

		foreach(Type; CommandTypes)
		if(typeid(Type) == typeid(this))
		{
			if(Type.takesData && parsedCmd.data == "")
				throw new CmdParseException("Missing data for command '%s'".format(parsedCmd.commandStr));

			if(!Type.takesData && parsedCmd.data != "")
				throw new CmdParseException("Command '%s' doesn't take data".format(parsedCmd.commandStr));
			
			if(parsedCmd.lalrState == -1 && parsedCmd.target == CmdTarget.lalrActions && !is(Type==CmdClean))
				throw new CmdParseException("Missing LALR State ID # for command '%s'".format(parsedCmd.commandStr));
			
			if(parsedCmd.lalrState != -1 && (parsedCmd.target != CmdTarget.lalrActions || is(Type==CmdClean)))
				throw new CmdParseException("Command '%s' doesn't take an LALR State ID #".format(parsedCmd.commandStr));
			
			if(parsedCmd.target == CmdTarget.lalrActions && !is(Type==CmdClean))
				Cmd.ensureInRange(options.lang, CmdTarget.lalr, -1, parsedCmd.lalrState);

			return;
		}

		commandNotFoundError(parsedCmd.commandStr);
	}

	abstract void run();
	
	static string getHelp(ParsedCmd parsedCmd)
	{
		foreach(Type; CommandTypes)
		if(typeid(Type) == parsedCmd.command)
		{
			static if(__traits(compiles, (){ string x = Type._getHelp(target); } ))
				return Type._getHelp(parsedCmd.target);
			else
				return Type.helpMsg;
		}
		
		commandNotFoundError(parsedCmd.commandStr);
		assert(0);
	}

	static CmdTarget parseLongTarget(string str)
	{
		switch(str)
		{
		case "symbols":      return CmdTarget.symbols;
		case "charsets":     return CmdTarget.charsets;
		case "rules":        return CmdTarget.rules;
		case "lalr":         return CmdTarget.lalr;
		case "dfa":          return CmdTarget.dfa;
		case "lalr-actions": return CmdTarget.lalrActions;
		default:             return CmdTarget.none;
		}
	}

	static CmdTarget parseShortTarget(string str)
	{
		switch(str)
		{
		case "S" : return CmdTarget.symbols;
		case "C" : return CmdTarget.charsets;
		case "R" : return CmdTarget.rules;
		case "L" : return CmdTarget.lalr;
		case "D" : return CmdTarget.dfa;
		case "LA": return CmdTarget.lalrActions;
		default:   return CmdTarget.none;
		}
	}
	
	static TypeInfo_Class parseLongCommand(string str)
	{
		foreach(Type; CommandTypes)
		if(Type.longName == str)
			return typeid(Type);
		
		return null;
	}

	static TypeInfo_Class parseShortCommand(string str)
	{
		foreach(Type; CommandTypes)
		if(Type.shortName == str)
			return typeid(Type);
		
		return null;
	}

	// This only parses the command string and enforces 'targets' by
	// by setting 'result.command' to null if 'targets' is violated.
	// This doesn't enforce any other validity.
	static ParsedCmd parse(string cmd)
	{
		ParsedCmd result;
		
		auto splitEquals = cmd.findSplit("=");
		auto splitEqualsBefore = splitEquals[0];
		auto splitEqualsMatch  = splitEquals[1];
		result.data            = splitEquals[2];
		
		auto splitHash = splitEqualsBefore.findSplit("#");
		auto splitHashBefore = splitHash[0];
		auto splitHashMatch  = splitHash[1];
		auto splitHashAfter  = splitHash[2];
		
		if(splitHashAfter != "")
		{
			bool failed = false;
			try
				result.lalrState = to!int(splitHashAfter);
			catch(ConvException e)
				failed = true;
			
			if(failed || result.lalrState < 0)
				throw new CmdParseException("ID # is not a non-negative integer: "~splitEqualsBefore);
		}

		// This is the place to check if splitEqualsBefore matches any
		// no-target commands. But there are no such commands at the moment.
		
		auto splitDash = splitHashBefore.findSplit("-");
		auto splitDashBefore = splitDash[0];
		auto splitDashMatch  = splitDash[1];
		auto splitDashAfter  = splitDash[2];
		
		// Short-style command?
		if(splitDashMatch == "")
		{
			if(splitDashBefore == "")
			{
				result.commandStr = "";
				result.command    = parseShortCommand("");
				result.target     = parseShortTarget ("");
			}
			else
			{
				result.commandStr = splitDashBefore;
				result.command    = parseShortCommand( splitDashBefore[0..1] );
				result.target     = parseShortTarget ( splitDashBefore[1..$] );
			}
		}
		else
		{
			result.commandStr = splitEqualsBefore;
			result.command    = parseLongCommand( splitDashBefore );
			result.target     = parseLongTarget ( splitDashAfter  );
		}
		
		// Set command to null if 'targets' is violated
		foreach(Type; CommandTypes)
		if(typeid(Type) == result.command)
		//TODO: Remove 'dup' when DMD 2.056 and below are no longer supported
		if(!Type.targets.dup.contains(result.target))
		{
			result.command = null;
			break;
		}

		return result;
	}

	static Cmd create(ParsedCmd parsedCmd)
	{
		foreach(Type; CommandTypes)
		if(typeid(Type) == parsedCmd.command)
			return new Type(parsedCmd);
		
		commandNotFoundError(parsedCmd.commandStr);
		assert(0);
	}
	
	/// 'lalrState' is only for CmdTarget.lalrActions
	static void ensureInRange(Language lang, CmdTarget target, int lalrState, int id)
	{
		if(id < 0)
			throw new CmdParseException("ID #%s is less than zero, must be non-negative".format(id));
		
		bool tooHigh = false;
		int length;
		
		final switch(target)
		{
		case CmdTarget.none: return;

		case CmdTarget.lalrActions:
			ensureInRange(lang, CmdTarget.lalr, -1, lalrState);
			
			length = cast(int)lang.lalrTable[lalrState].actions.length;
			if(id >= length)
				throw new CmdParseException(
					"ID #%s is greater than maximum (#%s) for LALR state #%s"
					.format(id, length-1, lalrState)
				);

			return;

		case CmdTarget.symbols:  length = cast(int)lang.  symbolTable.length; break;
		case CmdTarget.charsets: length = cast(int)lang. charSetTable.length; break;
		case CmdTarget.rules:    length = cast(int)lang.    ruleTable.length; break;
		case CmdTarget.lalr:     length = cast(int)lang.    lalrTable.length; break;
		case CmdTarget.dfa:      length = cast(int)lang.     dfaTable.length; break;
		}
		
		if(id >= length)
			throw new CmdParseException(
				"ID #%s is greater than maximum (#%s) for '%s' table"
				.format(id, length-1, to!string(target))
			);
	}
}

class CmdRemap : Cmd
{
	static immutable longName  = "remap";
	static immutable shortName = "R";
	static immutable targets   = [
		CmdTarget.symbols, CmdTarget.charsets, CmdTarget.rules,
		CmdTarget.dfa, CmdTarget.lalr, CmdTarget.lalrActions
	];
	static immutable takesData = true;
	static immutable helpMsg   = remapMsg;
	
	int[int] lookup; // lookup[oldId] == newId
		
	private this(ParsedCmd parsedCmd, int[int] mapping)
	{
		parsedCmd.command = typeid(this);
		parsedCmd.data    = "...";
		super(parsedCmd);

		this.lookup = mapping;
	}
	
	this(ParsedCmd parsedCmd)
	{
		super(parsedCmd);
		
		auto list = parsedCmd.data;
		
		// Alter CGT is intended to be usable for debugging issues with
		// grammar compilers, so this needs to be realiable even without a
		// reliably working grammar compiler. So can't dogfood here.
		
		string errors;
		void error(string msg)
		{
			if(errors)
				errors ~= "\n";
			errors ~= msg;
		}
		
		bool[int] newIDs; // To make sure there's no repeats
		auto pairs = list.split(",");
		foreach(pair; pairs)
		{
			auto parts_ = pair.findSplit(":");

			//TODO: Remove this workaround when DMD 2.058 and below are no longer supported
			string[] parts;
			foreach(part; parts_)
				parts ~= part;
				
			foreach(ref part; parts)
				part = part.strip();
			
			if(parts[0].empty || parts[1] != ":" || parts[2].empty)
			{
				error("Malformed remap-pair: "~pair~"\n  A remap-pair must be like (for example): 4:7");
				continue;
			}
			
			int before, after;
			try
			{
				before = to!int(parts[0]);
				after  = to!int(parts[2]);
			}
			catch(ConvException e)
			{
				error("Not a pair of non-negative integers: "~pair);
				continue;
			}
			
			if(before < 0 || after < 0)
			{
				error("Not a pair of non-negative integers: "~pair);
				continue;
			}

			try
			{
				Cmd.ensureInRange(options.lang, parsedCmd.target, parsedCmd.lalrState, before);
				Cmd.ensureInRange(options.lang, parsedCmd.target, parsedCmd.lalrState, after );
			}
			catch(CmdParseException e)
			{
				error(e.msg);
				continue;
			}

			if(before == after)
			{
				error("No-op pair: "~pair);
				continue;
			}
			
			if(after in newIDs)
			{
				error("Duplicate 'to' ID: %s".format(after));
				continue;
			}
			
			if(before in lookup)
			{
				error("Duplicate 'from' ID: %s".format(before));
				continue;
			}
			
			lookup[before] = after;
			newIDs[after] = true;
		}
		
		if(errors)
			throw new CmdParseException(errors);
	}
	
	override void run()
	{
		string verboseMsg;

		{
			auto sectionMsg = "Remapping '" ~ to!string(target) ~ "'";
			mixin(verboseSection!sectionMsg);

			auto lang = options.lang;
			
			// Boilerplate for handling multiple targets
			auto scrapLang = new Language();
			
			enum Stage { init, move, finish }
			
			// Via 'lookup' table. To be used in Stage.finish
			void convert(ref int id)
			{
				if(id in lookup)
					id = lookup[id];
			}
			
			// Handles target-specific operations.
			// Params 'oldId' and 'newId' are only valid for Stage.move
			void action(Stage stage, int oldId, int newId)
			{
				switch(target)
				{
				case CmdTarget.symbols:
					final switch(stage)
					{
					case Stage.init:
						scrapLang.symbolTable = lang.symbolTable.dup;
						break;

					case Stage.move:
						scrapLang.symbolTable[newId] = lang.symbolTable[oldId];
						break;

					case Stage.finish:
						lang.symbolTable = scrapLang.symbolTable;
						
						convert(lang.startSymbolIndex);
						convert(lang.eofSymbolIndex);
						convert(lang.errorSymbolIndex);
						
						foreach(ref rule; lang.ruleTable)
						{
							convert(rule.symbolIndex);
							foreach(ref subSymbolID; rule.subSymbolIndicies)
								convert(subSymbolID);
						}
						
						foreach(ref state; lang.dfaTable)
							convert(state.acceptSymbolIndex);
						
						foreach(ref state; lang.lalrTable)
						foreach(ref lalrAction; state.actions)
							convert(lalrAction.symbolId);
						
						break;
					}
					break;

				case CmdTarget.charsets:
					final switch(stage)
					{
					case Stage.init:
						scrapLang.charSetTable = lang.charSetTable.dup;
						break;

					case Stage.move:
						scrapLang.charSetTable[newId] = lang.charSetTable[oldId];
						break;

					case Stage.finish:
						lang.charSetTable = scrapLang.charSetTable;
						
						foreach(ref state; lang.dfaTable)
						foreach(ref edge; state.edges)
							convert(edge.charSetIndex);
						
						break;
					}
					break;

				case CmdTarget.rules:
					final switch(stage)
					{
					case Stage.init:
						scrapLang.ruleTable = lang.ruleTable.dup;
						break;

					case Stage.move:
						scrapLang.ruleTable[newId] = lang.ruleTable[oldId];
						break;

					case Stage.finish:
						lang.ruleTable = scrapLang.ruleTable;
						
						foreach(ref state; lang.lalrTable)
						foreach(ref lalrAction; state.actions)
						if(lalrAction.type == LALRAction.Type.Reduce)
							convert(lalrAction.target);
						
						break;
					}
					break;

				case CmdTarget.dfa:
					final switch(stage)
					{
					case Stage.init:
						scrapLang.dfaTable = lang.dfaTable.dup;
						break;

					case Stage.move:
						scrapLang.dfaTable[newId] = lang.dfaTable[oldId];
						break;

					case Stage.finish:
						lang.dfaTable = scrapLang.dfaTable;
						
						foreach(ref state; lang.dfaTable)
						foreach(ref edge; state.edges)
							convert(edge.targetDFAStateIndex);

						convert(lang.initialDFAState);
						break;
					}
					break;

				case CmdTarget.lalr:
					final switch(stage)
					{
					case Stage.init:
						scrapLang.lalrTable = lang.lalrTable.dup;
						break;

					case Stage.move:
						scrapLang.lalrTable[newId] = lang.lalrTable[oldId].dup;
						break;

					case Stage.finish:
						lang.lalrTable = scrapLang.lalrTable;
						
						foreach(ref state; lang.lalrTable)
						foreach(ref lalrAction; state.actions)
						if(lalrAction.type == LALRAction.Type.Shift || lalrAction.type == LALRAction.Type.Goto)
							convert(lalrAction.target);
						
						convert(lang.initialLALRState);
						break;
					}
					break;

				case CmdTarget.lalrActions:
					final switch(stage)
					{
					case Stage.init:
						if(lalrState >= lang.lalrTable.length)
							throw new CmdException(
								"LALR state #%s doesn't exist. Number of states is only %s."
								.format(lalrState, lang.lalrTable.length)
							);
						
						scrapLang.lalrTable ~= lang.lalrTable[lalrState].dup;
						break;

					case Stage.move:
						scrapLang.lalrTable[0].actions[newId] = lang.lalrTable[lalrState].actions[oldId];
						break;

					case Stage.finish:
						lang.lalrTable[lalrState] = scrapLang.lalrTable[0];
						break;
					}
					break;

				default:
					throw new CmdException("Remap command not yet implemented for target '%s'.".format(target));
				}
			}

			void init()                     { action(Stage.init,      -1,    -1); }
			void move(int oldId, int newId) { action(Stage.move,   oldId, newId); }
			void finish()                   { action(Stage.finish,    -1,    -1); }

			// Start the remapping
			bool[int] displaced; // displaced[ID in lang.symbolTable]
			bool[int] gaps;      // gaps     [ID in lang.symbolTable]
			init();
			
			// Remember, the constructor already probibits any
			// oldId or newId from being used more than once.
			foreach(oldId, newId; lookup)
			{
				assert(lookup[oldId] == newId);
				
				// Set newly displaced/empty IDs, if any
				if(newId !in displaced) displaced[newId] = true;
				if(oldId !in gaps     ) gaps     [oldId] = true;
				
				// Unset IDs that are no longer displaced/empty
				displaced[oldId] = false;
				gaps     [newId] = false;
				
				// Move element
				move(oldId, newId);
			}
			
			// Generate sorted ID list of the elements that are still displaced/empty
			int[] displacedIDs;
			int[] gapIDs;

			foreach(id; displaced.keys.sort)
			if(displaced[id] == true)
				displacedIDs ~= id;

			foreach(id; gaps.keys.sort)
			if(gaps[id] == true)
				gapIDs ~= id;
			
			// Double-check integrity
			if(displacedIDs.length != gapIDs.length)
				throw new InternalException(
					"Unequal numbers of displaced IDs (%s) and gap IDs (%s)"
					.format(displacedIDs.length, gapIDs.length)
				);
			
			// Fill gaps with displaced elements (and add these moves to 'lookup' table)
			foreach(index; 0..displacedIDs.length)
			{
				auto oldId = displacedIDs[index];
				auto newId = gapIDs[index];

				if(options.verbose)
					verboseMsg ~= "Implicitly moved #%s to position #%s".formatln(oldId, newId);
				
				lookup[oldId] = newId;
				move(oldId, newId);
			}

			// Finish up
			finish();
		}

		if(options.verbose && verboseMsg)
			write(verboseMsg);
	}
}

class CmdShift : Cmd
{
	static immutable longName  = "shift";
	static immutable shortName = "S";
	static immutable targets   = [
		CmdTarget.symbols, CmdTarget.charsets, CmdTarget.rules,
		CmdTarget.dfa, CmdTarget.lalr, CmdTarget.lalrActions
	];
	static immutable takesData = true;
	static immutable helpMsg   = shiftMsg;
	
	CmdRemap remap;
	int oldId;
	int newId;
	
	this(ParsedCmd parsedCmd)
	{
		super(parsedCmd);
		
		auto pair = parsedCmd.data;

		auto parts_ = pair.findSplit("-");

		//TODO: Remove this workaround when DMD 2.058 and below are no longer supported
		string[] parts;
		foreach(part; parts_)
			parts ~= part;

		foreach(ref part; parts)
			part = part.strip();
		
		if(parts[0].empty || parts[1] != "-" || parts[2].empty)
		{
			throw new CmdParseException(
				"Malformed shift-pair: "~pair~"\n  A shift-pair must be like (for example): 4-7"
			);
		}
		
		try
		{
			oldId = to!int(parts[0]);
			newId = to!int(parts[2]);
		}
		catch(ConvException e)
			throw new CmdParseException("Not a pair of non-negative integers: "~pair);
		
		if(oldId < 0 || newId < 0)
			throw new CmdParseException("Not a pair of non-negative integers: "~pair);

		Cmd.ensureInRange(options.lang, parsedCmd.target, parsedCmd.lalrState, oldId);
		Cmd.ensureInRange(options.lang, parsedCmd.target, parsedCmd.lalrState, newId);
		
		if(oldId == newId)
			throw new CmdParseException("No-op pair: "~pair);
		
		int[int] mapping;

		mapping[oldId] = newId;
		if(oldId < newId)
		{
			foreach(id; oldId..newId)
				mapping[id+1] = id;
		}
		else
		{
			foreach(id; newId..oldId)
				mapping[id] = id+1;
		}
		
		remap = new CmdRemap(parsedCmd, mapping);
	}
	
	override void run()
	{
		auto sectionMsg = "Shifting '%s' %s-%s".format(to!string(target), oldId, newId);
		mixin(verboseSection!sectionMsg);

		auto lang = options.lang;
		
		// Temporarily mute verbosity
		auto saveVerbose = options.verbose;
		options.verbose = false;
		scope(exit) options.verbose = saveVerbose;
		
		// Perform shift by remapping
		remap.run();
	}
}

class CmdMatch : Cmd
{
	static immutable longName  = "match";
	static immutable shortName = "M";
	static immutable targets   = [CmdTarget.symbols];
	static immutable takesData = true;
	static immutable helpMsg   = matchMsg;
	
	CmdRemap remap;
	string matchFile;
		
	this(ParsedCmd parsedCmd)
	{
		super(parsedCmd);

		this.matchFile = parsedCmd.data;
	}
	
	override void run()
	{
		auto sectionMsg = "Matching '%s' with '%s'".format(to!string(target), matchFile);
		mixin(verboseSection!sectionMsg);

		auto lang = options.lang;

		if(target != CmdTarget.symbols)
			throw new CmdException("Remap command not yet implemented for target '%s'.".format(target));

		int[int] mapping;
		int[int] reverseMapping;
		auto matchLang = Language.load(matchFile);

		foreach(int oldId, oldElem; lang.symbolTable)
		{
			int firstMatchId = -1;
			foreach(int newId, newElem; matchLang.symbolTable)
			{
				if(newElem.name == oldElem.name && newElem.type == oldElem.type)
				{
					if(firstMatchId == -1)
						firstMatchId = newId;
					else
						throw new CmdException(
							"Found duplicate '%s' in '%s': IDs #%s and #%s: %s.%s"
							.format(
								to!string(target), matchFile,
								firstMatchId, newId,
								to!string(newElem.type), newElem.name
							)
						);
				}
			}
			
			if(firstMatchId != -1)
			{
				try
					Cmd.ensureInRange(options.lang, parsedCmd.target, parsedCmd.lalrState, firstMatchId);
				catch(CmdParseException e)
				{
					writeln("Notice: Skipping element with out-of-range 'after' ID: ", e.msg);
					continue;
				}
				
				mapping[oldId] = firstMatchId;
				
				if(firstMatchId in reverseMapping)
					throw new CmdException(
						"Found the same mapping (new ID #%s) for duplicate '%s' in '%s': IDs #%s and #%s: %s.%s"
						.format(
							firstMatchId, to!string(target), lang.filename,
							reverseMapping[oldId], oldId,
							to!string(oldElem.type), oldElem.name
						)
					);

				reverseMapping[firstMatchId] = oldId;
			}
		}
		
		remap = new CmdRemap(parsedCmd, mapping);
		
		// Temporarily mute verbosity
		auto saveVerbose = options.verbose;
		options.verbose = false;
		scope(exit) options.verbose = saveVerbose;
		
		// Perform shift by remapping
		remap.run();
	}
}

class CmdClean : Cmd
{
	static immutable longName  = "clean";
	static immutable shortName = "C";
	static immutable targets   = [CmdTarget.lalrActions];
	static immutable takesData = false;
	static immutable helpMsg   = "";
	
	static string _getHelp(CmdTarget target)
	{
		return sortLALRActionsMsg;
	}

	this(ParsedCmd parsedCmd)
	{
		super(parsedCmd);
	}

	override void run()
	{
		auto sectionMsg = "Cleaning '%s'".format(to!string(target));
		mixin(verboseSection!sectionMsg);

		auto lang = options.lang;
		
		sortFinalTable(lang.lalrTable);
	}
}
