// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

module goldie.base;

import std.algorithm;
import std.array;
import std.conv;
import std.string;

import semitwist.util.all;

enum SymbolType
{
	NonTerminal  = 0,
	Terminal     = 1,
	Whitespace   = 2,
	EOF          = 3,
	CommentStart = 4,
	CommentEnd   = 5,
	CommentLine  = 6,
	Error        = 7,
}

string symbolTypeToString(SymbolType type)
{
	switch(type)
	{
	case SymbolType.NonTerminal:
		return "NonTerminal";
	case SymbolType.Terminal:
		return "Terminal";
	case SymbolType.Whitespace:
		return "Whitespace";
	case SymbolType.EOF:
		return "EOF";
	case SymbolType.CommentStart:
		return "CommentStart";
	case SymbolType.CommentEnd:
		return "CommentEnd";
	case SymbolType.CommentLine:
		return "CommentLine";
	case SymbolType.Error:
		return "Error";
	default:
		throw new Exception("Unexpected SymbolType #"~to!string(cast(int)type));
	}
}

unittest
{
	// 'symbolTypeToString' and 'typeToString' expect this to work at compile-time:
	enum test_ctfe_int_to_string = to!string(42);
}

string fullSymbolTypeToString(SymbolType type)
{
	return typeof(type).stringof ~ "." ~ symbolTypeToString(type);
}

string[] symbolTypesToStrings(SymbolType[] types)
{
	return semitwist.util.functional.map!(string)(types,
		(SymbolType type) { return symbolTypeToString(type); }
	);
}

string symbolTypesToString(SymbolType[] types)
{
	return types.symbolTypesToStrings().join(", ");
}

T[] goldieBaseDup(T)(const(T[]) arr)
{
	T[] ret;
	foreach(elem; arr)
		ret ~= elem.dup();
	return ret;
}

struct CharPair
{
	dchar start;
	dchar end;

	const bool opEquals(ref const CharPair s)
	{
		return start == s.start && end == s.end;
	}

	string toString()
	{
		return r"%s('\U%08X','\U%08X')".format(typeof(this).stringof, cast(uint)start, cast(uint)end);
	}
}

struct CharSet
{
	CharPair[] pairs;

	const bool opEquals(ref const CharSet s)
	{
		return pairs == s.pairs;
	}

	string toString()
	{
		string pairsStr =
			reduceTo(pairs,
				(string a, CharPair b)
				{
					return a ~ (a==""?"":",") ~ to!string(b);
				}
			);
		return "%s([%s])".format(typeof(this).stringof, pairsStr);
	}
	
	this(CharPair[] pairs)
	{
		this.pairs = pairs;
	}

	this(dstring str)
	{
		if(str.length > 0)
		{
			if(str.length == 1)
				pairs ~= CharPair(str[0], str[0]);
			else
			{
				dchar[] sortedStr = array(str.dup.sort());
				dchar lastCh  = sortedStr[0];
				dchar startCh = sortedStr[0];
				foreach(ch; sortedStr[1..$])
				{
					if(ch == lastCh)
						continue;
					
					if(cast(uint)ch > cast(uint)lastCh + 1)
					{
						pairs ~= CharPair(startCh, lastCh);
						startCh = ch;
					}
					lastCh = ch;
				}
				pairs ~= CharPair(startCh, sortedStr[$-1]);
			}
		}
	}
	
	CharSet dup() const
	{
		return CharSet(pairs.dup);
	}
	
	dstring toRawChars()
	{
		dstring str = "";
		foreach(pair; pairs)
		foreach(chCode; cast(uint)pair.start .. cast(uint)pair.end+1)
			str ~= cast(dchar)chCode;
		return str;
	}
	
	bool matches(dchar ch)
	{
		foreach(pair; pairs)
		if(cast(uint)ch >= cast(uint)pair.start && cast(uint)ch <= cast(uint)pair.end)
			return true;
			
		return false;
	}
}

CharSet[] toCharSetTable(dstring[] rawTable)
{
	CharSet[] table;
	
	foreach(str; rawTable)
		table ~= CharSet(str);
	
	return table;
}

dstring[] toRawCharSetTable(CharSet[] table)
{
	dstring[] rawTable;
	
	foreach(chSet; table)
		rawTable ~= chSet.toRawChars();
	
	return rawTable;
}


struct Symbol
{
	string name;
	SymbolType type;
	int id;
	
	string toString()
	{
		return
			"%s(%s,%s,%s)".format(
				typeof(this).stringof,
				name.escapeDDQS(),
				fullSymbolTypeToString(type),
				id
			);
	}
}

struct Rule
{
	int symbolIndex;
	int[] subSymbolIndicies;

	Rule dup() const
	{
		return Rule(symbolIndex, subSymbolIndicies.dup);
	}
	
	string toString()
	{
		return "%s( %s, %s )".format(typeof(this).stringof, symbolIndex, subSymbolIndicies);
	}
}

struct DFAState
{
	bool accept;
	int acceptSymbolIndex;
	DFAStateEdge[] edges;

	DFAState dup() const
	{
		return DFAState(accept, acceptSymbolIndex, edges.dup);
	}

	string toString()
	{
		string edgeStr =
			reduceTo(edges,
				(string a, DFAStateEdge b)
				{
					return a ~ (a==""?"":",") ~ to!string(b);
				}
			);
		return "%s( %s, %s, %s )".format(typeof(this).stringof, accept, acceptSymbolIndex, edges);
	}
}

struct DFAStateEdge
{
	int charSetIndex;
	int targetDFAStateIndex;

	string toString()
	{
		return "%s(%s,%s)".format(typeof(this).stringof, charSetIndex, targetDFAStateIndex);
	}
}

struct LALRState
{
	LALRAction[] actions;

	LALRState dup() const
	{
		return LALRState(actions.dup);
	}

	string toString()
	{
		return "%s( %s )".format(typeof(this).stringof, actions);
	}
}

struct LALRAction
{
	enum Type
	{
		Shift  = 1, // target: LALR State Index
		Reduce = 2, // target: Rule Index
		Goto   = 3, // target: LALR State Index
		Accept = 4  // target: unused
	}

	int symbolId;
	Type type;
	int target;

	string toString()
	{
		return
			"%s(%s,%s,%s)".format(
				typeof(this).stringof, symbolId, fullTypeToString(type), target
			);
	}

	static string typeToString(Type type)
	{
		switch(type)
		{
		case LALRAction.Type.Shift:
			return "Shift";
		case LALRAction.Type.Reduce:
			return "Reduce";
		case LALRAction.Type.Goto:
			return "Goto";
		case LALRAction.Type.Accept:
			return "Accept";
		default:
			throw new Exception("Unexpected LALRAction.Type #"~to!string(cast(int)type));
		}
	}

	static string fullTypeToString(Type type)
	{
		return typeof(this).stringof ~ "." ~ typeof(type).stringof ~ "." ~ typeToString(type);
	}
}

alias unittestSection!"Goldie_unittest" unittestGoldie;
