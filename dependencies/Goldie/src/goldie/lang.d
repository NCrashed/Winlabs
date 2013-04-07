// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

module /+S:PACKAGE+/goldie/+E:PACKAGE+/.lang;

/+P:INIT_STATIC_LANG+/
version(Goldie_StaticStyle) {} else
	version = Goldie_DynamicStyle;

version(DigitalMars)
{
	import std.compiler;
	static if(version_major == 2 && version_minor == 57)
	{
		version(Goldie_StaticStyle)
			static assert(false, "Goldie's static-style and grammar compiling don't work on DMD 2.057 due to DMD Issue #7375");
		else
			version = Goldie_OmitGrmcLib;
	}
}

static if(true) // Workaround for DMD Issue #7386
{
	// To help with StaticLang. See note in stbuild.conf
	version(Goldie_OmitGrmcLib) {} else
		version = Goldie_IncludeGrmcLib;
}

version(Goldie_StaticStyle)
{
	// Ensure Goldie versions match
	import goldie.ver;
	static if(goldieVerStr != "/+P:VERSION+/")
	{
		pragma(msg,
			"You're using Goldie v"~goldieVerStr~", but this static-style language "~
			"was generated with Goldie v/+P:VERSION+/. You must regenerate the langauge "~
			"with 'goldie-staticlang'."
		);
		static assert(false, "Mismatched Goldie versions");
	}
}

import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.base;
version(Goldie_DynamicStyle) import goldie.file;
import goldie.exception;
import goldie.lexer;
import goldie.parser;
import goldie.token;

import goldie.grmc.ast;
import tools.util;

static if(true) // Workaround for DMD Issue #7386
{
	version(Goldie_IncludeGrmcLib) import goldie.langs.grm.all;
}

//TODO: Create a function to fix symbolLookup after changing the language details.
//      Maybe cause the accessors to set a "dirty" flag which will re-gen symbolLookup
//      next time symbolLookup is accessed.
//TODO: In SemiTwistLib, create an "accessor"/"property" mixin similar to "getter"

version(Goldie_DynamicStyle)
string toLangIdent(string ident, string shortPackageName)
{
	return ident~"_"~shortPackageName;
}

version(Goldie_DynamicStyle)
public class Language
{
	string name;
	string ver;
	string author;
	string about;
	bool   caseSensitive;
	string filename;
	
	protected Symbol[][string] symbolLookup;
	
	Symbol[]    symbolTable;
	CharSet[]   charSetTable;
	Rule[]      ruleTable;
	DFAState[]  dfaTable;
	LALRState[] lalrTable;
	
	int startSymbolIndex;
	int initialDFAState;
	int initialLALRState;
	
	int eofSymbolIndex;
	int errorSymbolIndex;
	
	/// The NFA and DFA in Graphviz DOT format.
	///
	/// These are always empty unless the Langauge was created
	/// via Goldie.compileGrammarDebug or Goldie.compileGrammarFileDebug.
	///
	/// Languages loaded from a CGT or via staticlang will never have these filled in.
	string nfaDot;
	//string dfaRawDot;
	string dfaDot;

	int nfaNumStates;
	//int dfaRawNumStates;
	//int dfaNumStates;

	/// Only use this if you're going to manually create a language
	/// without using Goldie's CGT-loading or staticlang.
	public this()
	{
	}
	
	package this(string cgtFilename)
	{
		auto goldFile = new CGTFile(cgtFilename);
		filename = cgtFilename;
		
		this.symbolLookup     = goldFile.symbolLookup;
		this.name             = goldFile.name;
		this.ver              = goldFile.ver;
		this.author           = goldFile.author;
		this.about            = goldFile.about;
		this.caseSensitive    = goldFile.caseSensitive;
		this.startSymbolIndex = goldFile.startSymbolIndex;
		this.initialDFAState  = goldFile.initialDFAState;
		this.initialLALRState = goldFile.initialLALRState;
		this.eofSymbolIndex   = goldFile.eofSymbolIndex;
		this.errorSymbolIndex = goldFile.errorSymbolIndex;
		this.symbolTable      = goldFile.symbolTable;
		this.charSetTable     = goldFile.charSetTable;
		this.ruleTable        = goldFile.ruleTable;
		this.dfaTable         = goldFile.dfaTable;
		this.lalrTable        = goldFile.lalrTable;
	}
	
	void save(string cgtFilename)
	{
		auto goldFile = new CGTFile();
		
		goldFile.symbolLookup = this.symbolLookup;

		goldFile.name             = this.name;
		goldFile.ver              = this.ver;
		goldFile.author           = this.author;
		goldFile.about            = this.about;
		goldFile.caseSensitive    = this.caseSensitive;
		goldFile.startSymbolIndex = this.startSymbolIndex;
		goldFile.initialDFAState  = this.initialDFAState;
		goldFile.initialLALRState = this.initialLALRState;
		goldFile.eofSymbolIndex   = this.eofSymbolIndex;
		goldFile.errorSymbolIndex = this.errorSymbolIndex;
		goldFile.symbolTable      = this.symbolTable;
		goldFile.charSetTable     = this.charSetTable;
		goldFile.ruleTable        = this.ruleTable;
		goldFile.dfaTable         = this.dfaTable;
		goldFile.lalrTable        = this.lalrTable;

		goldFile.save(cgtFilename);
	}
	
	protected Lexer lexCodeX(Lexer lexer, string source, string filename)
	{
		lexer.process(source, this, filename);
		return lexer;
	}
	
	protected Parser parseTokensX(Parser parser, Token[] tokens, string filename, Lexer lexerUsed)
	{
		parser.process(tokens, this, filename, lexerUsed);
		return parser;
	}

	Lexer lexCodeX(string source, string filename="")
	{
		return lexCodeX(new Lexer(), source, filename);
	}
	
	Parser parseTokensX(Token[] tokens, string filename="", Lexer lexerUsed=null)
	{
		return parseTokensX(new Parser(), tokens, filename, lexerUsed);
	}

	Lexer lexFileX(string filename)
	{
		return lexCodeX(readUTFFile!string(filename), filename);
	}

	Parser parseFileX(string filename)
	{
		auto lexer = lexFileX(filename);
		return parseTokensX(lexer.tokens, filename, lexer);
	}

	Parser parseCodeX(string source, string filename="")
	{
		auto lexer = lexCodeX(source, filename);
		return parseTokensX(lexer.tokens, filename, lexer);
	}

	protected Symbol[] lookupSymbol(string symName)
	{
		if(symName in symbolLookup)
			return symbolLookup[symName];
		else
			return [];
	}

	Symbol[] symbolsByName(string name)
	{
		return lookupSymbol(name).dup;
	}
	
	SymbolType[] symbolTypesByName(string name)
	{
		return
			lookupSymbol(name).map(
				(Symbol sym) { return sym.type; }
			);
	}
	
	string symbolTypesStrByName(string name)
	{
		return symbolTypesByName(name).symbolTypesToString();
	}
	
	//TODO: This is just a quick-n-dirty implementation atm, probably runs slow
	int ruleIdOf(string parentSymbol, string[] subSymbols...)
	{
		void throwNoSuchRule()
		{
			throw new Exception("Rule does not exist: %s ::= %s".format(parentSymbol, subSymbols));
		}
		
		foreach(string symName; subSymbols)
		{
			if(isSymbolNameAmbiguous(symName))
				throw new Exception(
					"Symbol '%s' is ambiguous, it could be any of the following types: %s\nGoldie does not yet support disambiguation of symbol names at runtime."
						.format(symName, symbolTypesStrByName(symName))
				);
			
			if(!isSymbolNameValid(symName) && symName !is null)
				throwNoSuchRule();
		}
		
		foreach(int ruleId, Rule rule; ruleTable)
		{
			// Wrong parentSymbol?
			if(rule.symbolIndex != lookupSymbol(parentSymbol)[0].id)
				continue;
			
			// Is this token an empty rule?
			if(rule.subSymbolIndicies.length == 0)
			{
				// Can't require an explicit null for consistency with static-mode,
				// without requiring it be '[null]', because it'll get mistaken
				// for a string[] instead of a string.
				if((subSymbols.length == 1 && subSymbols[0] is null) || subSymbols.length == 0)
					return ruleId;
				else
					continue;
			}

			// Wrong subSymbols length?
			if(subSymbols.length != rule.subSymbolIndicies.length)
				continue;
			
			// Looking for empty rule?
			if(subSymbols.length == 1 && subSymbols[0] is null)
			{
				// Already checked if this token was empty, so no match:
				continue;
			}
			
			bool foundMatch = true;
			foreach(int i, int subSymbolIndex; rule.subSymbolIndicies)
			if(subSymbolIndex != lookupSymbol(subSymbols[i])[0].id)
			{
				foundMatch = false;
				break;
			}

			if(foundMatch)
				return ruleId;
		}

		throwNoSuchRule();
		assert(0);
	}
	
	string ruleToString(int ruleId)
	{
		auto rule = ruleTable[ruleId];
		string str = symbolTable[rule.symbolIndex].name;
		str ~= " ::=";
		foreach(subSymId; rule.subSymbolIndicies)
		{
			str ~= " ";
			str ~= symbolTable[subSymId].name;
		}
		return str;
	}

	string[] uniqueSymbolNames()
	{
		return symbolLookup.keys;
	}

	bool isSymbolNameValid(string name)
	{
		return lookupSymbol(name).length >= 1;
	}
	
	bool isSymbolNameAmbiguous(string name)
	{
		return lookupSymbol(name).length > 1;
	}

	@property Symbol eofSymbol()
	{
		return symbolTable[eofSymbolIndex];
	}

	@property Symbol errorSymbol()
	{
		return symbolTable[errorSymbolIndex];
	}

	static Language load(string cgtFilename)
	{
		return new Language(cgtFilename);
	}

	/// Use Language.load() instead
	deprecated static Language loadCGT(string filename)
	{
		return load(filename);
	}

	static if(true) // Workaround for DMD Issue #7386
	version(Goldie_IncludeGrmcLib)
	{
		static bool compileGrammarGoldCompatibility = false;

		static Language compileGrammarFile(string filename)
		{
			return compileGrammarFileImpl(filename, false, false);
		}

		static Language compileGrammar(string grammarDefinition, string filename="")
		{
			return compileGrammarImpl(grammarDefinition, false, filename);
		}

		static Language compileGrammarFileDebug(string filename, bool verbose=false)
		{
			return compileGrammarFileImpl(filename, true, verbose);
		}

		static Language compileGrammarDebug(string grammarDefinition, string filename="", bool verbose=false)
		{
			return compileGrammarImpl(grammarDefinition, true, filename, verbose);
		}

		private static Language compileGrammarFileImpl(string filename, bool keepDebugInfo, bool verbose)
		{
			return compileGrammarImpl(readUTFFile!string(filename), keepDebugInfo, filename, verbose);
		}

		private static Language compileGrammarImpl(string grammarDefinition, bool keepDebugInfo, string filename, bool verbose=false)
		{
			Parser parser;
			AST ast;
			try
			{
				{
					mixin(verboseSection!"Parsing grammar description");
					parser = language_grm.parseCodeX(grammarDefinition, filename);
				}

				scope(failure)
					if(ast) ast.writeErrorMsg();
					
				ast = new AST(parser, keepDebugInfo);
				ast.goldCompat = compileGrammarGoldCompatibility;
				ast.verbose = verbose;
				ast.genLanguage(parser.parseTreeX);
			}
			catch(ParseException e)
			{
				writeln(e.msg);
				return null;
			}

			ast.writeErrorMsg();
			
			if(ast.numErrors > 0)
				return null;
			
			//mixin(traceVal!("ast.lang.author"));
			//foreach(sym; ast.lang.symbolTable)
			//	mixin(traceVal!("sym"));

			return ast.lang;
		}
	}
}

version(Goldie_StaticStyle)
{
	import goldie.lang;
	
	package alias /+P:LANG_CLASSNAME+/DUMMY ThisStaticLanguage;

	private enum _langInstanceName = "language_" ~ _shortPackageName;
	private enum _langClassName    = toLangIdent(Language.stringof, _shortPackageName);
	private enum _lexerClassName   = toLangIdent(Lexer   .stringof, _shortPackageName);
	private enum _parserClassName  = toLangIdent(Parser  .stringof, _shortPackageName);
	private enum _tokenClassName   = toLangIdent(Token   .stringof, _shortPackageName);

	mixin(`
		import `~_packageName~`.lexer;
		import `~_packageName~`.parser;
		import `~_packageName~`.langHelper;
		import `~_packageName~`.token;

		package alias `~_lexerClassName ~` ThisStaticLexer;
		package alias `~_parserClassName~` ThisStaticParser;
		package alias `~_tokenClassName ~` ThisStaticToken;

		`~_langClassName~` `~_langInstanceName~`;

		// This is a workaround for the cyclic dependency probelms in static constructors
		private extern(C) void `~_langInstanceName~`_staticCtor()
		{
			`~_langInstanceName~` = new `~_langClassName~`();
		}
	`);
}

// Static-style Language
version(Goldie_StaticStyle)
/+S:LANG_INHERIT+/public class Language/+E:LANG_INHERIT+/
{
	/+P:LANG_STATICDATA+/
	
	static enum packageName      = _packageName;
	static enum shortPackageName = _shortPackageName;
	static enum langInstanceName = _langInstanceName;
	static enum langClassName    = _langClassName;
	static enum lexerClassName   = _lexerClassName;
	static enum parserClassName  = _parserClassName;
	static enum tokenClassName   = _tokenClassName;

/+static private Language_calc _inst;
static @property Language_calc inst()
{
	if(!_inst)
		_inst = new Language_calc();
	return _inst;
}+/

	public this()
	{
		super();
		
		name   = staticName;
		ver    = staticVer;
		author = staticAuthor;
		about  = staticAbout;
		caseSensitive = staticCaseSensitive;

		startSymbolIndex = staticStartSymbolIndex;
		initialDFAState  = staticInitialDFAState;
		initialLALRState = staticInitialLALRState;
		eofSymbolIndex   = staticEofSymbolIndex;
		errorSymbolIndex = staticErrorSymbolIndex;

		symbolTable  = staticSymbolTable.dup;

		charSetTable = staticCharSetTable.goldieBaseDup();
		ruleTable    = staticRuleTable   .goldieBaseDup();
		dfaTable     = staticDFATable    .goldieBaseDup();
		lalrTable    = staticLALRTable   .goldieBaseDup();

		/+P:INIT_SYMBOL_LOOKUP+/
	}

	public ThisStaticLexer lexCode(string source, string filename="")
	{
		return cast(ThisStaticLexer)lexCodeX(source, filename);
	}
	
	public ThisStaticParser parseTokens(Token[] tokens, string filename="", Lexer lexerUsed=null)
	{
		return cast(ThisStaticParser)parseTokensX(tokens, filename, lexerUsed);
	}

	public ThisStaticLexer lexFile(string filename)
	{
		return cast(ThisStaticLexer)lexFileX(filename);
	}

	public ThisStaticParser parseFile(string filename)
	{
		return cast(ThisStaticParser)parseFileX(filename);
	}

	public ThisStaticParser parseCode(string source, string filename="")
	{
		return cast(ThisStaticParser)parseCodeX(source, filename);
	}

	override Lexer lexCodeX(string source, string filename="")
	{
		return super.lexCodeX(new ThisStaticLexer(), source, filename);
	}
	
	override Parser parseTokensX(Token[] tokens, string filename="", Lexer lexerUsed=null)
	{
		return super.parseTokensX(new ThisStaticParser(), tokens, filename, lexerUsed);
	}

	static bool staticIsSymbolNameValid(string name)
	{
		return staticLookupSymbol(name).length >= 1;
	}
	
	static bool staticIsSymbolNameAmbiguous(string name)
	{
		return staticLookupSymbol(name).length > 1;
	}

	static Symbol staticEofSymbol()
	{
		return staticSymbolTable[staticEofSymbolIndex];
	}

	static Symbol staticErrorSymbol()
	{
		return staticSymbolTable[staticErrorSymbolIndex];
	}
	
	override bool isSymbolNameValid(string name)
	{
		return typeof(this).staticIsSymbolNameValid(name);
	}
	
	override bool isSymbolNameAmbiguous(string name)
	{
		return typeof(this).staticIsSymbolNameAmbiguous(name);
	}
	
	override Symbol eofSymbol()
	{
		return typeof(this).staticEofSymbol();
	}
	
	override Symbol errorSymbol()
	{
		return typeof(this).staticErrorSymbol();
	}

	protected static Symbol[] staticLookupSymbol(string symName)
	{
		switch(symName)
		{
		/+P:LOOKUP_SYMBOL+/
		}
	}

	protected override Symbol[] lookupSymbol(string symName)
	{
		return typeof(this).staticLookupSymbol(symName);
	}
}
