// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

/++
 NOTE: My terminilogy in this code is somewhat inconsistent with the file format docs.
 
       My Term  | GOLD Docs Term
       ----------------------
	   Data     | Entry  (ex, 'I':Integer)
	   Entry    | Record (ex, 'P':Parameters)
	   Record   | Record (ie, 'M':Multitype)
+/

// Read GOLD Parser Builder's .cgt (Compiled Grammar Table) files.
module goldie.file;

import std.conv;
import std.stdio;
import std.stream;
import std.string;
import std.system;

import semitwist.util.all;

import goldie.base;
import goldie.exception;

ubyte[] toBuf(T)(T data) if(is(T==ushort) || is(T==uint))
{
	// DMD 2.055 changed "LittleEndian" to "littleEndian", etc...
	static if(__traits(compiles, Endian.littleEndian))
		data = toEndian(data, Endian.littleEndian);
	else
		data = toEndian(data, Endian.LittleEndian);
	
	T[] buf = [data];
	return cast(ubyte[])buf;
}

class DataOrEntryType(T)
{
	static assert(is(T==Data) || is(T==Entry), "T must be Data or Entry");
	
	private char _code;
	private string _name;
	
	public this(char code, string name)
	{
		_code = code;
		_name = name;
	}
	
	public char code()
	{
		return _code;
	}

	public string name()
	{
		return _name;
	}
}
alias DataOrEntryType!(Data) DataType;

abstract class EntryType: DataOrEntryType!(Entry)
{
	// Does not include the initial DataType.Byte to denote entry type
	private DataType[] _entryFormat;
	private string entryFormatCode;
	
	public this(char code, string name, string entryFormatCode)
	{
		super(code, name);
		this.entryFormatCode = entryFormatCode;
	}
	
	/// WARNING: Do not call this from within a static constructor.
	///          This relies on the static constructor of DataTypes
	///          having already run.
	public DataType[] entryFormat()
	{
		if(_entryFormat.length == 0)
		{
			foreach(char c; entryFormatCode)
				_entryFormat ~= DataTypes.fromCode(c);
		}
		
		return _entryFormat.dup;
	}
}

template DataOrEntryTypes(T, string nameOfType)
{
	static assert(is(T==DataType) || is(T==EntryType), "T must be DataType or EntryType");

	private static T[] All;
	private static string nameOfT = nameOfType; // It's clumsy to get exactly what I want here at compile-time
	
	public static T fromCode(char code)
	{
		foreach(T t; All)
			if(t.code() == code)
				return t;
		
		throw new IllegalArgumentException(
			"%s for code #%s '%s' doesn't exist".format(nameOfT, cast(ubyte)code, code)
		);
	}

	public static T fromName(string name)
	{
		foreach(T t; All)
			if(t.name() == name)
				return t;

		throw new IllegalArgumentException(
			"%s named '%s' doesn't exist".format(nameOfT, name)
		);
	}
}

enum DataTypeCode : char
{
	Empty   = 'E',
	Byte    = 'b',
	Boolean = 'B',
	Integer = 'I',
	String  = 'S',
}

static class DataTypes
{
	public static DataType Empty;
	public static DataType Byte;
	public static DataType Boolean;
	public static DataType Integer;
	public static DataType String;

	mixin DataOrEntryTypes!(DataType, "DataType");
	
	public static this()
	{
		All ~= Empty   = new DataType('E', "Empty");
		All ~= Byte    = new DataType('b', "Byte");
		All ~= Boolean = new DataType('B', "Boolean");
		All ~= Integer = new DataType('I', "Integer");
		All ~= String  = new DataType('S', "String");
	}
}

static class EntryTypes
{
	public static EntryType Parameters;
	public static EntryType TableCounts;
	public static EntryType CharacterSetTable;
	public static EntryType Symbols;
	public static EntryType Rules;
	public static EntryType InitialStates;
	public static EntryType DFAStates;
	public static EntryType LALRStates;

	mixin DataOrEntryTypes!(EntryType, "EntryType");

	public static this()
	{
		All ~= Parameters        = new EntryParameters();
		All ~= TableCounts       = new EntryTableCounts();
		All ~= CharacterSetTable = new EntryCharacterSetTable();
		All ~= Symbols           = new EntrySymbols();
		All ~= Rules             = new EntryRules();
		All ~= InitialStates     = new EntryInitialStates();
		All ~= DFAStates         = new EntryDFAStates();
		All ~= LALRStates        = new EntryLALRStates();
	}
}

struct Data
{
	private DataType _type;
	private union DataValue
	{
		ubyte  Byte;
		bool   Boolean;
		short  Integer;
		string String;
	}
	private DataValue value;
	
	public static Data opCall(DataType _type)
	{
		//mixin(initMember!(_type));
		Data d;
		d._type = _type;
		return d;
	}
	
	public static Data opCall()
	{
		Data d;
		d._type = DataTypes.Empty;
		return d;
	}
	
	public static Data opCall(ubyte value)
	{
		Data d;
		d._type = DataTypes.Byte;
		d.value.Byte = value;
		return d;
	}
	
	public static Data opCall(char value)
	{
		return Data(cast(ubyte)value);
	}
	
	public static Data opCall(long value)
	{
		return Data(cast(short)value);
	}
	
	public static Data opCall(bool value)
	{
		Data d;
		d._type = DataTypes.Boolean;
		d.value.Boolean = value;
		return d;
	}
	
	public static Data opCall(short value)
	{
		Data d;
		d._type = DataTypes.Integer;
		d.value.Integer = value;
		return d;
	}
	
	public static Data opCall(string value)
	{
		Data d;
		d._type = DataTypes.String;
		d.value.String = value;
		return d;
	}
	
	public void read(std.stream.File reader)
	{
		char typeCode;
		reader.read(typeCode);
		_type = DataTypes.fromCode(typeCode);
		
		if(_type == DataTypes.Empty)
		{
			// Do nothing
		}
		else if(_type == DataTypes.Byte)
		{
			reader.read(value.Byte);
		}
		else if(_type == DataTypes.Boolean)
		{
			ubyte inBool;
			reader.read(inBool);
			if(inBool == 0 || inBool == 1)
				value.Boolean = (inBool == 1);
			else
				throw new LanguageLoadException(
					"Expected a DataTypes.Boolean (0 or 1) but got %s".format(inBool)
				);
		}
		else if(_type == DataTypes.Integer)
		{
			reader.read(value.Integer);
		}
		else if(_type == DataTypes.String)
		{
			value.String = to!string( readStringz!wstring(reader) );
		}
		else
		{
			throw new LanguageLoadException(
				"Unknown DataType #%s '%s'".format(cast(ubyte)typeCode, typeCode)
			);
		}
	}

	public void read(std.stream.File reader, DataType expectedType)
	{
		read(reader);

		if(_type != expectedType)
		{
			throw new LanguageLoadException(
				"Expected #%s '%s' ('[]') type, but got #%s '%s'".format(
					cast(ubyte)expectedType.code(), expectedType.code(),
					expectedType.name(),
					cast(ubyte)_type.code(), type.code())
				);
		}
	}

	public DataType type()
	{
		return _type;
	}
	
	public ubyte valueByte()
	{
		if(_type != DataTypes.Byte)
			throw new LanguageLoadException("Type is %s, not Byte".format(_type.name()));
			
		return value.Byte;
	}
	
	public bool valueBoolean()
	{
		if(_type != DataTypes.Boolean)
			throw new LanguageLoadException("Type is %s, not Boolean".format(_type.name()));
			
		return value.Boolean;
	}
	
	public short valueInteger()
	{
		if(_type != DataTypes.Integer)
			throw new LanguageLoadException("Type is %s, not Integer".format(_type.name()));
			
		return value.Integer;
	}
	
	public string valueString()
	{
		if(_type != DataTypes.String)
			throw new LanguageLoadException("Type is %s, not String".format(_type.name()));
			
		return value.String;
	}
	
	public ubyte[] toBuf()
	{
		ubyte[] buf = [_type._code];
		
		if(_type == DataTypes.Byte)
		{
			buf ~= value.Byte;
		}
		else if(_type == DataTypes.Boolean)
		{
			buf ~= value.Boolean? 1 : 0;
		}
		else if(_type == DataTypes.Integer)
		{
			buf ~= .toBuf(cast(ushort)value.Integer);
		}
		else if(_type == DataTypes.String)
		{
			//TODO: Fix endianness here
			buf ~= cast(ubyte[])to!wstring(value.String~"\0");
		}
		else if(_type == DataTypes.Empty)
		{
			// Do nothing
		}
		else
			throw new Exception("Unexpected type '%s'".format(_type.name()));
		
		return buf;
	}
}

Data readData(std.stream.File reader)
{
	auto data = Data();
	data.read(reader);
	
	return data;
}

Data readData(std.stream.File reader, DataType expectedType)
{
	auto data = Data();
	data.read(reader, expectedType);
	
	return data;
}

Entry readEntry(std.stream.File reader)
{
	auto entry = new Entry();
	entry.read(reader);
	
	return entry;
}

class Entry
{
	// content does not include 'M' (for Multitype), number of data, or entry type code
	private Data[] content;
	private EntryType _type;

	public this()
	{
	}
	
	public this(EntryType _type)
	{
		this._type = _type;
	}

	public void read(std.stream.File reader)
	{
		char recordTypeCode;
		reader.read(recordTypeCode);
		
		if(recordTypeCode != 'M')
			throw new LanguageLoadException(
				"Expected record type 'M' (Multitype) but found #%s '%s'".format(
					cast(ubyte)recordTypeCode, recordTypeCode
				)
			);
		
		short numData;
		reader.read(numData);
		numData--; // Don't count the entry type code

		auto entryType = readData(reader, DataTypes.Byte);

		_type = EntryTypes.fromCode(entryType.valueByte());
		foreach(DataType dataType; _type.entryFormat())
			content ~= readData(reader, dataType);

		// Load the rest
		//TODO: type checking on loaded data
		while(content.length < numData)
			content ~= readData(reader);

		//TODO? Create appropriate data view struct thing?
	}
	
	public EntryType type()
	{
		return _type;
	}
	
	public size_t length()
	{
		return content.length;
	}
	
	public Data opIndex(size_t index)
	{
		return content[index];
	}
	
	public ubyte[] toBuf()
	{
		ubyte[] buf;
		
		// +1 for the entry type code
		ushort numData = cast(ushort)(content.length+1);
		
		buf = ['M'];
		buf ~= .toBuf(numData);
		buf ~= Data(_type._code).toBuf();
		
		foreach(data; content)
			buf ~= data.toBuf();
		
		return buf;
	}
}

class EntryParameters : EntryType
{
	this()
	{
		super('P', "Parameters",
		[
			DataTypeCode.String,  // Name
			DataTypeCode.String,  // Version
			DataTypeCode.String,  // Author
			DataTypeCode.String,  // About
			DataTypeCode.Boolean, // Case Sensitive?
			DataTypeCode.Integer  // Start Symbol
		]);
	}
}

class EntryTableCounts : EntryType
{
	this()
	{
		super('T', "TableCounts",
		[
			DataTypeCode.Integer, // Number of Symbol Tables
			DataTypeCode.Integer, // Number of Character Set Tables
			DataTypeCode.Integer, // Number of Rule Tables
			DataTypeCode.Integer, // Number of DFA Tables
			DataTypeCode.Integer  // Number of LALR Tables
		]);
	}
}

class EntryCharacterSetTable : EntryType
{
	this()
	{
		super('C', "CharacterSetTable",
		[
			DataTypeCode.Integer, // Index
			DataTypeCode.String   // Characters
		]);
	}
}

class EntrySymbols : EntryType
{
	this()
	{
		super('S', "Symbols",
		[
			DataTypeCode.Integer, // Index
			DataTypeCode.String,  // Name
			DataTypeCode.Integer  // Kind
		]);
	}
}

class EntryRules : EntryType
{
	this()
	{
		super('R', "Rules",
		[
			DataTypeCode.Integer, // Index
			DataTypeCode.Integer, // Non-Terminal
			DataTypeCode.Empty    // (Reserved)
			//TODO: ...more...
		]);
	}
}

class EntryInitialStates : EntryType
{
	this()
	{
		super('I', "InitialStates",
		[
			DataTypeCode.Integer, // DFA State
			DataTypeCode.Integer  // LALR State
		]);
	}
}

class EntryDFAStates : EntryType
{
	this()
	{
		super('D', "DFAStates",
		[
			DataTypeCode.Integer, // Index
			DataTypeCode.Boolean, // Accept State?
			DataTypeCode.Integer, // Accept Index
			DataTypeCode.Empty    // (Reserved)
			//TODO: ...more...
		]);
	}
}

class EntryLALRStates : EntryType
{
	this()
	{
		super('L', "LALRStates",
		[
			DataTypeCode.Integer, // Index
			DataTypeCode.Empty    // (Reserved)
			//TODO: ...more...
		]);
	}
}

class CGTFile
{
	// May not really need this
	private Entry[] entries;

	private enum wstring expectedFileType = "GOLD Parser Tables/v1.0"w;
	
	public string name;
	public string ver;
	public string author;
	public string about;
	public bool   caseSensitive;
	public int    startSymbolIndex;

	public Symbol[][string] symbolLookup;
	public Symbol[]     symbolTable;
	public dstring[]    rawCharSetTable;
	public CharSet[]    charSetTable;
	public Rule[]       ruleTable;
	public DFAState[]   dfaTable;
	public LALRState[]  lalrTable;
	
	public int initialDFAState;
	public int initialLALRState;

	public int eofSymbolIndex;
	public int errorSymbolIndex;

	public this()
	{
	}

	public this(string infilename)
	{
		load(infilename);
	}
	
	private void ensureTableCountsLoaded(bool tableCountsLoaded, string entryTypeName)
	{
		if(!tableCountsLoaded)
			throw new LanguageLoadException(
				"TableCounts entry not yet found when trying to read %s entry".format(entryTypeName)
			);
	}
	
	public void save(string filename)
	{
		ubyte[] data;
		Entry entry;

		rawCharSetTable = toRawCharSetTable(charSetTable);
		
		data ~= cast(ubyte[])(expectedFileType~"\0"w);

		entry = new Entry(EntryTypes.Parameters);
		entry.content ~= Data(name   is null? "(Untitled)"      : name  );
		entry.content ~= Data(ver    is null? "(Not Specified)" : ver   );
		entry.content ~= Data(author is null? "(Unknown)"       : author);
		entry.content ~= Data(about);
		entry.content ~= Data(caseSensitive);
		entry.content ~= Data(startSymbolIndex);
		data ~= entry.toBuf();
		
		entry = new Entry(EntryTypes.TableCounts);
		entry.content ~= Data(symbolTable.length);
		entry.content ~= Data(rawCharSetTable.length);
		entry.content ~= Data(ruleTable.length);
		entry.content ~= Data(dfaTable.length);
		entry.content ~= Data(lalrTable.length);
		data ~= entry.toBuf();

		entry = new Entry(EntryTypes.InitialStates);
		entry.content ~= Data(initialDFAState);
		entry.content ~= Data(initialLALRState);
		data ~= entry.toBuf();
		
		foreach(i, charSet; rawCharSetTable)
		{
			entry = new Entry(EntryTypes.CharacterSetTable);
			entry.content ~= Data(i);
			entry.content ~= Data(to!string(charSet));
			data ~= entry.toBuf();
		}
		
		foreach(i, sym; symbolTable)
		{
			entry = new Entry(EntryTypes.Symbols);
			entry.content ~= Data(i);
			
			if(sym.type == SymbolType.NonTerminal)
				entry.content ~= Data(sym.name[1..$-1]);
			else
				entry.content ~= Data(sym.name);
				
			entry.content ~= Data(cast(int)sym.type);
			data ~= entry.toBuf();
		}
		
		foreach(i, rule; ruleTable)
		{
			entry = new Entry(EntryTypes.Rules);
			entry.content ~= Data(i);
			entry.content ~= Data(rule.symbolIndex);
			entry.content ~= Data();
			foreach(symId; rule.subSymbolIndicies)
				entry.content ~= Data(symId);
			data ~= entry.toBuf();
		}
		
		foreach(i, dfaState; dfaTable)
		{
			entry = new Entry(EntryTypes.DFAStates);
			entry.content ~= Data(i);
			entry.content ~= Data(dfaState.accept);
			entry.content ~= Data(dfaState.acceptSymbolIndex);
			entry.content ~= Data();
			foreach(edge; dfaState.edges)
			{
				entry.content ~= Data(edge.charSetIndex);
				entry.content ~= Data(edge.targetDFAStateIndex);
				entry.content ~= Data();
			}
			data ~= entry.toBuf();
		}

		foreach(i, lalrState; lalrTable)
		{
			entry = new Entry(EntryTypes.LALRStates);
			entry.content ~= Data(i);
			entry.content ~= Data();
			foreach(action; lalrState.actions)
			{
				entry.content ~= Data(action.symbolId);
				entry.content ~= Data(cast(int)action.type);
				entry.content ~= Data(action.target);
				entry.content ~= Data();
			}
			data ~= entry.toBuf();
		}
		
		std.file.write(filename, data);
	}
	
	private void load(string infilename)
	{
		try
		{
			std.stream.File file;
			try
				file = new std.stream.File(infilename);
			catch(Exception e)
				throw new LanguageNotFoundException(infilename, e);
			scope(exit) file.close();
			
			//auto readBuffer = new BufferedInput(file.input);
			//auto reader = new std.stream.File(readBuffer);
			//reader.endian(std.stream.File.Little);
			
			// Load data
			// Read null-term string "GOLD Parser Tables/1.0" (using read func in semitwist.util)
			wstring fileType = readStringz!wstring(file);
			if(fileType != expectedFileType)
				throw new LanguageLoadException(
					"Unexpected filetype field\nExpected: \"%s\"\nFound:    \"%s\"".format(
						expectedFileType, fileType
					)
				);
			
			// Read some records
			bool paramatersLoaded    = false;
			bool tableCountsLoaded   = false;
			bool initialStatesLoaded = false;

			while(!file.eof())
			{
				auto entry = readEntry(file);
				auto entryType = entry.type();
			
				if(entryType == EntryTypes.Parameters)
				{
					//Stdout.formatln("Found: Parameters");
					if(paramatersLoaded)
						throw new LanguageLoadException("Multiple Parameters entries");
						
					name             = entry[0].valueString();
					ver              = entry[1].valueString();
					author           = entry[2].valueString();
					about            = entry[3].valueString();
					caseSensitive    = entry[4].valueBoolean();
					startSymbolIndex = entry[5].valueInteger();
					
					paramatersLoaded = true;
				}
				else if(entryType == EntryTypes.TableCounts)
				{
					//Stdout.formatln("Found: TableCounts");
					if(tableCountsLoaded)
						throw new LanguageLoadException("Multiple TableCounts entries");
						
					symbolTable.length     = entry[0].valueInteger();
					rawCharSetTable.length = entry[1].valueInteger();
					ruleTable.length       = entry[2].valueInteger();
					dfaTable.length        = entry[3].valueInteger();
					lalrTable.length       = entry[4].valueInteger();
					
					tableCountsLoaded = true;
				}
				else if(entryType == EntryTypes.InitialStates)
				{
					//Stdout.formatln("Found: InitialStates");
					if(initialStatesLoaded)
						throw new LanguageLoadException("Multiple InitialStates entries");
						
					initialDFAState  = entry[0].valueInteger();
					initialLALRState = entry[1].valueInteger();
					
					initialStatesLoaded = true;
				}
				else if(entryType == EntryTypes.CharacterSetTable)
				{
					//Stdout.formatln("Found: CharacterSetTable");
					ensureTableCountsLoaded(tableCountsLoaded, "CharacterSetTable");

					int index = entry[0].valueInteger();
					if(index >= rawCharSetTable.length)
						throw new LanguageLoadException(
							"Invalid CharacterSetTable index. Found %s, expected < %s"
								.format(index, rawCharSetTable.length)
						);
									 
					rawCharSetTable[index] = to!(dstring)( entry[1].valueString() );
				}
				else if(entryType == EntryTypes.Symbols)
				{
					//Stdout.formatln("Found: Symbols");
					ensureTableCountsLoaded(tableCountsLoaded, "Symbols");

					int index = entry[0].valueInteger();
					if(index >= symbolTable.length)
						throw new LanguageLoadException(
							"Invalid Symbols index. Found %s, expected < %s"
								.format(index, symbolTable.length)
						);
									 
					symbolTable[index].name = entry[1].valueString();
					symbolTable[index].type = cast(SymbolType)entry[2].valueInteger();
					symbolTable[index].id = index;
					if(symbolTable[index].type == SymbolType.NonTerminal)
						symbolTable[index].name = "<"~symbolTable[index].name~">";
					
					if(symbolTable[index].name in symbolLookup)
						symbolLookup[symbolTable[index].name] ~= symbolTable[index];
					else
						symbolLookup[symbolTable[index].name] = [symbolTable[index]];
					
					if(symbolTable[index].type == SymbolType.EOF)
						eofSymbolIndex = index;
					if(symbolTable[index].type == SymbolType.Error)
						errorSymbolIndex = index;
				}
				else if(entryType == EntryTypes.Rules)
				{
					//Stdout.formatln("Found: Rules");
					ensureTableCountsLoaded(tableCountsLoaded, "Rules");

					int index = entry[0].valueInteger();
					if(index >= ruleTable.length)
						throw new LanguageLoadException(
							"Invalid Rules index. Found %s, expected < %s"
								.format(index, ruleTable.length)
						);
									 
					ruleTable[index].symbolIndex = entry[1].valueInteger();
					int numTerminals = cast(int)entry.length - 3;
					ruleTable[index].subSymbolIndicies.length = numTerminals;
					for(int i=0; i<numTerminals; i++)
					{
						ruleTable[index].subSymbolIndicies[i] = entry[i+3].valueInteger();
					}
				}
				else if(entryType == EntryTypes.DFAStates)
				{
					//Stdout.formatln("Found: DFAStates");
					ensureTableCountsLoaded(tableCountsLoaded, "DFAStates");

					int index = entry[0].valueInteger();
					if(index >= dfaTable.length)
						throw new LanguageLoadException(
							"Invalid DFAStates index. Found %s, expected < %s"
								.format(index, dfaTable.length)
						);
									 
					dfaTable[index].accept = entry[1].valueBoolean();
					dfaTable[index].acceptSymbolIndex = entry[2].valueInteger();
					int numEdges = (cast(int)entry.length - 4) / 3;
					dfaTable[index].edges.length = numEdges;
					for(int i=0; i<numEdges; i++)
					{
						dfaTable[index].edges[i].charSetIndex         = entry[(i*3) + 4].valueInteger();
						dfaTable[index].edges[i].targetDFAStateIndex  = entry[(i*3) + 5].valueInteger();
					}
				}
				else if(entryType == EntryTypes.LALRStates)
				{
					//Stdout.formatln("Found: LALRStates");
					ensureTableCountsLoaded(tableCountsLoaded, "LALRStates");

					int index = entry[0].valueInteger();
					if(index >= lalrTable.length)
						throw new LanguageLoadException(
							"Invalid LALRStates index. Found %s, expected < %s"
								.format(index, lalrTable.length)
						);
									 
					int numActions = (cast(int)entry.length - 2) / 4;
					lalrTable[index].actions.length = numActions;
					for(int i=0; i<numActions; i++)
					{
						lalrTable[index].actions[i].symbolId = entry[(i*4) + 2].valueInteger();
						lalrTable[index].actions[i].type     = cast(LALRAction.Type)entry[(i*4) + 3].valueInteger();
						lalrTable[index].actions[i].target   = entry[(i*4) + 4].valueInteger();
					}
				}
				else
				{
					//Stdout.formatln("Found: Unknown");
					throw new LanguageLoadException(
						"Unknown entry type #%s (%s)"
							.format(cast(ubyte)entryType.code(), entryType.code())
					);
				}
				//Stdout.formatln("Done");

				entries ~= entry;
			}
			
			if(!paramatersLoaded)
				throw new LanguageLoadException("Paramaters entry missing");
			if(!tableCountsLoaded)
				throw new LanguageLoadException("TableCounts entry missing");
			if(!initialStatesLoaded)
				throw new LanguageLoadException("InitialStates entry missing");
			
			//TODO: Create "lenient load" flag
			//TODO: Make sure there are no unloaded table indicies
			
			charSetTable = toCharSetTable(rawCharSetTable);
		}
		catch(Exception e)
		{
			if(cast(LanguageNotFoundException)e)
				throw e;
				
			throw new LanguageLoadException("Problem loading GOLD .cgt file", infilename, e);
		}
	}
}
