// Goldie: GOLD Engine for D
// Grammar Compiler
// Written in the D programming language.

module goldie.grmc.ast;

import std.algorithm;
import std.array;
import std.conv;
import std.path;
import std.stdio;
import std.string;
import std.variant;

import semitwist.util.all;

import goldie.all;
import goldie.grmc.fsm;
import goldie.grmc.gendfa;
import goldie.grmc.genlalr;
import goldie.grmc.process;
import tools.util;

class SemanticException : ParseException
{
	Token token;
	bool isWarning;
	
	this(Parser parser, Token token, string msg, bool isWarning=false)
	{
		this.token = token;
		this.isWarning = isWarning;
		super(parser, msg);
	}
	
	override string toString()
	{
		return "%s(%s%s): %s: %s".format(
			token.file,
			token.line+1,
			(parser && parser.lexer)?
				":%s".format((token.srcIndexStart-parser.lexer.lineIndicies[token.line])+1) :
				"",
			isWarning? "Warning":"Error",
			msg
		);
	}
}

class AST
{
	bool goldCompat=false; // GOLD-Compatibility Mode
	bool verbose=false;
	
	Language lang;
	Parser parser;

	int numErrors;
	int numWarnings;
	SemanticException[] errors; // Includes warnings

	string[Insensitive] params;

	ASTCharSet[Insensitive] charSets; // Indexed by name
	ASTTerminal[Insensitive] terminals; // Indexed by name
	ASTNonTerminal[Insensitive] nonterminals; // Indexed by name
	dstring[] rawCharSetTable;
	int firstNonTerminalId;
	
	bool usingDefaultWhitespace;
	
	int nextRuleId; // For GOLD-Compatibility Mode
	
	bool keepDebugInfo;
	bool useMappingANSI;
	NFA nfa;
	_DFA dfaRaw;
	_DFA dfa;
	
	mixin processFuncs!();
	
	this(Parser parser, bool keepDebugInfo=false)
	{
		this.parser = parser;
		this.keepDebugInfo = keepDebugInfo;
	}

	private static ASTCharSet[Insensitive] _defaultCharSets;
	static @property ASTCharSet[Insensitive] defaultCharSets()
	{
		if(_defaultCharSets is null)
			initDefaultCharSets();
		return _defaultCharSets;
	}
	
	static void initDefaultCharSets()
	{
		_defaultCharSets[Insensitive("HT")]        = ASTCharSet().combine( "\t"      );
		_defaultCharSets[Insensitive("LF")]        = ASTCharSet().combine( "\n"      );
		_defaultCharSets[Insensitive("VT")]        = ASTCharSet().combine( "\v"      );
		_defaultCharSets[Insensitive("FF")]        = ASTCharSet().combine( "\f"      );
		_defaultCharSets[Insensitive("CR")]        = ASTCharSet().combine( "\r"      );
		_defaultCharSets[Insensitive("Space")]     = ASTCharSet().combine( " "       );
		_defaultCharSets[Insensitive("NBSP")]      = ASTCharSet().combine( "\&nbsp;" );
		_defaultCharSets[Insensitive("Euro Sign")] = ASTCharSet().combine( "\u20AC"  );

		_defaultCharSets[Insensitive("Number")] =
			ASTCharSet().combine( ASTCharSetItem('0','9') );
			
		_defaultCharSets[Insensitive("Digit")] =
			ASTCharSet().combine( _defaultCharSets[Insensitive("Number")] );

		_defaultCharSets[Insensitive("Letter")] =
			ASTCharSet()
			.combine( ASTCharSetItem('a','z') )
			.combine( ASTCharSetItem('A','Z') );

		_defaultCharSets[Insensitive("AlphaNumeric")] =
			ASTCharSet()
			.combine( _defaultCharSets[Insensitive("Number")] )
		    .combine( _defaultCharSets[Insensitive("Letter")] );
		
		_defaultCharSets[Insensitive("Printable")] =
			ASTCharSet()
			.combine( ASTCharSetItem('\x20','\x7F') )
		    .combine( "\&nbsp;" );
		
		_defaultCharSets[Insensitive("Whitespace")] =
			ASTCharSet().combine( " \t\n\v\f\r\&nbsp;" );
			
		_defaultCharSets[Insensitive("All Whitespace")] =
			ASTCharSet()
			.combine( _defaultCharSets[Insensitive("Whitespace")] )
			.combine( "\u0085\u1680\u180E\u2028\u2029\u202F\u205F\u3000" )
			.combine( ASTCharSetItem('\u2000','\u200A') );
			
		_defaultCharSets[Insensitive("ANSI Mapped")] =
			ASTCharSet().combine( ASTCharSetItem('\x80','\x9F') );
		
		_defaultCharSets[Insensitive("Control Codes")] =
			ASTCharSet()
			.combine( ASTCharSetItem('\x01','\x1F') )
		    .combine( _defaultCharSets[Insensitive("ANSI Mapped")] );
														   
		_defaultCharSets[Insensitive("Printable Extended")] =
			ASTCharSet().combine( ASTCharSetItem('\x81','\xFF') );

		_defaultCharSets[Insensitive("ANSI Printable")] =
			ASTCharSet()
			.combine( _defaultCharSets[Insensitive("Printable")] )
		    .combine( _defaultCharSets[Insensitive("ANSI Mapped")] )
		    .combine( _defaultCharSets[Insensitive("Printable Extended")] );
		
		_defaultCharSets[Insensitive("Letter Extended")] =
			ASTCharSet()
			.combine( ASTCharSetItem('\xC0','\xFF') )
		    .combine( ASTCharSetItem(cast(dchar)0xD7, cast(dchar)0xD7), ASTCharSetMode.Minus )
		    .combine( ASTCharSetItem(cast(dchar)0xF7, cast(dchar)0xF7), ASTCharSetMode.Minus );

		/+
		//TODO: Add "All Valid" (currently way too slow, wait for char set optimization)
		_defaultCharSets[Insensitive("All Valid")] =
			ASTCharSet()
			.combine( ASTCharSetItem('\u0001','\uD7FF') )
		    .combine( ASTCharSetItem(cast(dchar)0xDC00,'\uFFEF') );
		+/
		// Awkward way to do it, but it's way too slow otherwise.
		auto allValidPart1 = ASTCharSet().combine( ASTCharSetItem('\u0001','\uD7FF') );
		auto allValidPart2 = ASTCharSet().combine( ASTCharSetItem(cast(dchar)0xDC00,'\uFFEF') );
		_defaultCharSets[Insensitive("All Valid")] = ASTCharSet();
		_defaultCharSets[Insensitive("All Valid")].str = allValidPart1.data ~ allValidPart2.data;
		assert(_defaultCharSets[Insensitive("All Valid")].data.length > 5);


		_defaultCharSets[Insensitive("Latin Extended")] = ASTCharSet().combine( ASTCharSetItem('\u0100','\u02AF') );
		_defaultCharSets[Insensitive("Greek")]          = ASTCharSet().combine( ASTCharSetItem('\u0370','\u03FF') );
		_defaultCharSets[Insensitive("Cyrillic")]       = ASTCharSet().combine( ASTCharSetItem('\u0400','\u04FF') );
		_defaultCharSets[Insensitive("Cyrillic Supplementary")] = ASTCharSet().combine( ASTCharSetItem('\u0500','\u052F') );
		_defaultCharSets[Insensitive("Armenian")]       = ASTCharSet().combine( ASTCharSetItem('\u0530','\u058F') );
		_defaultCharSets[Insensitive("Hebrew")]         = ASTCharSet().combine( ASTCharSetItem('\u0590','\u05FF') );
		_defaultCharSets[Insensitive("Arabic")]         = ASTCharSet().combine( ASTCharSetItem('\u0600','\u06FF') );
		_defaultCharSets[Insensitive("Syriac")]         = ASTCharSet().combine( ASTCharSetItem('\u0700','\u074F') );
		_defaultCharSets[Insensitive("Thaana")]         = ASTCharSet().combine( ASTCharSetItem('\u0780','\u07BF') );
		_defaultCharSets[Insensitive("Devanagari")]     = ASTCharSet().combine( ASTCharSetItem('\u0900','\u097F') );
		_defaultCharSets[Insensitive("Bengali")]        = ASTCharSet().combine( ASTCharSetItem('\u0980','\u09FF') );
		_defaultCharSets[Insensitive("Gurmukhi")]       = ASTCharSet().combine( ASTCharSetItem('\u0A00','\u0A7F') );
		_defaultCharSets[Insensitive("Gujarati")]       = ASTCharSet().combine( ASTCharSetItem('\u0A80','\u0AFF') );
		_defaultCharSets[Insensitive("Oriya")]          = ASTCharSet().combine( ASTCharSetItem('\u0B00','\u0B7F') );
		_defaultCharSets[Insensitive("Tamil")]          = ASTCharSet().combine( ASTCharSetItem('\u0B80','\u0BFF') );
		_defaultCharSets[Insensitive("Telugu")]         = ASTCharSet().combine( ASTCharSetItem('\u0C00','\u0C7F') );
		_defaultCharSets[Insensitive("Kannada")]        = ASTCharSet().combine( ASTCharSetItem('\u0C80','\u0CFF') );
		_defaultCharSets[Insensitive("Malayalam")]      = ASTCharSet().combine( ASTCharSetItem('\u0D00','\u0D7F') );
		_defaultCharSets[Insensitive("Sinhala")]        = ASTCharSet().combine( ASTCharSetItem('\u0D80','\u0DFF') );
		_defaultCharSets[Insensitive("Thai")]           = ASTCharSet().combine( ASTCharSetItem('\u0E00','\u0E7F') );
		_defaultCharSets[Insensitive("Lao")]            = ASTCharSet().combine( ASTCharSetItem('\u0E80','\u0EFF') );
		_defaultCharSets[Insensitive("Tibetan")]        = ASTCharSet().combine( ASTCharSetItem('\u0F00','\u0FFF') );
		_defaultCharSets[Insensitive("Myanmar")]        = ASTCharSet().combine( ASTCharSetItem('\u1000','\u109F') );
		_defaultCharSets[Insensitive("Georgian")]       = ASTCharSet().combine( ASTCharSetItem('\u10A0','\u10FF') );
		_defaultCharSets[Insensitive("Hangul Jamo")]    = ASTCharSet().combine( ASTCharSetItem('\u1100','\u11FF') );
		_defaultCharSets[Insensitive("Ethiopic")]       = ASTCharSet().combine( ASTCharSetItem('\u1200','\u137F') );
		_defaultCharSets[Insensitive("Cherokee")]       = ASTCharSet().combine( ASTCharSetItem('\u13A0','\u13FF') );
		_defaultCharSets[Insensitive("Ogham")]          = ASTCharSet().combine( ASTCharSetItem('\u1680','\u169F') );
		_defaultCharSets[Insensitive("Runic")]          = ASTCharSet().combine( ASTCharSetItem('\u16A0','\u16FF') );
		_defaultCharSets[Insensitive("Tagalog")]        = ASTCharSet().combine( ASTCharSetItem('\u1700','\u171F') );
		_defaultCharSets[Insensitive("Hanunoo")]        = ASTCharSet().combine( ASTCharSetItem('\u1720','\u173F') );
		_defaultCharSets[Insensitive("Buhid")]          = ASTCharSet().combine( ASTCharSetItem('\u1740','\u175F') );
		_defaultCharSets[Insensitive("Tagbanwa")]       = ASTCharSet().combine( ASTCharSetItem('\u1760','\u177F') );
		_defaultCharSets[Insensitive("Khmer")]          = ASTCharSet().combine( ASTCharSetItem('\u1780','\u17FF') );
		_defaultCharSets[Insensitive("Mongolian")]      = ASTCharSet().combine( ASTCharSetItem('\u1800','\u18AF') );
		_defaultCharSets[Insensitive("Latin Extended Additional")] = ASTCharSet().combine( ASTCharSetItem('\u1E00','\u1EFF') );
		_defaultCharSets[Insensitive("Greek Extended")] = ASTCharSet().combine( ASTCharSetItem('\u1F00','\u1FFF') );
		_defaultCharSets[Insensitive("Hiragana")]       = ASTCharSet().combine( ASTCharSetItem('\u3040','\u309F') );
		_defaultCharSets[Insensitive("Katakana")]       = ASTCharSet().combine( ASTCharSetItem('\u30A0','\u30FF') );
		_defaultCharSets[Insensitive("Bopomofo")]       = ASTCharSet().combine( ASTCharSetItem('\u3100','\u312F') );
		_defaultCharSets[Insensitive("Kanbun")]         = ASTCharSet().combine( ASTCharSetItem('\u3190','\u319F') );
		_defaultCharSets[Insensitive("Bopomofo Extended")] = ASTCharSet().combine( ASTCharSetItem('\u31A0','\u31BF') );
	}

	void error(Token tok, string msg)
	{
		error(tok, msg, false);
	}

	void warning(Token tok, string msg)
	{
		error(tok, msg, true);
	}

	private void error(Token tok, string msg, bool isWarning)
	{
		if(isWarning)
			numWarnings++;
		else
			numErrors++;
			
		errors ~= new SemanticException(parser, tok, msg, isWarning);
	}
	
	string getErrorString()
	{
		auto msg = appender!string();
		foreach(i, err; errors)
		{
			if(i > 0)
				msg.put("\n");
			msg.put(err.toString());
		}

		msg.put(
			"%s Error(s), %s Warning(s)"
			.format(numErrors, numWarnings)
		);
		
		return msg.data;
	}

	void writeErrorMsg()
	{
		if(errors.length > 0)
			writeln(getErrorString());
	}
	
	void reset()
	{
		mixin(verboseSection!"Initializing grammar compiler");
		
		usingDefaultWhitespace = true;
		useMappingANSI = true;
		numErrors=0;
		numWarnings=0;
		nextRuleId=0;
		firstNonTerminalId=0;
		
		lang = new Language();
		errors.length = 0;

		params = null;
		charSets = null;
		nonterminals = null;

		foreach(key, value; defaultCharSets)
			charSets[key] = value;

		terminals = [
			Insensitive("EOF"):        ASTTerminal(true, SymbolType.EOF       ),
			Insensitive("Error"):      ASTTerminal(true, SymbolType.Error     ),
			Insensitive("Whitespace"): ASTTerminal(true, SymbolType.Whitespace),
		];
	}
	
	void genLanguage(Token tok)
	{
		reset();
		
		// Process the parse tree into AST (this)
		{
			mixin(verboseSection!"Converting grammar description to AST");
			process(tok);
		}
		
		// Put all the AST data into a Language
		genSymbols();
		genRules();
		genDFA();
		genLALR();
		lang.charSetTable = toCharSetTable(rawCharSetTable);

		//debug displayRegexes();
	}

	Insensitive symNameFromId(int id)
	{
		return Insensitive(lang.symbolTable[id].name);
	}
	
	ASTTerminal terminalFromId(int id)
	{
		return terminals[symNameFromId(id)];
	}
	
	ASTNonTerminal nonTerminalFromId(int id)
	{
		return nonterminals[symNameFromId(id)];
	}
	
	void displayRegexes()
	{
		foreach(name, sym; terminals)
		{
			write(name, ": ");
			
			if(sym.regex is null)
			{
				writeln("null");
				continue;
			}
			
			writeln(sym.regex);
		}
	}

	static Algebraic!(bool,dchar) parseCharCodePart(string str)
	{
		Algebraic!(bool,dchar) ret;
		
		str = str.strip();
		
		int radix;
		if(str.startsWith('#'))
			radix = 10;
		else if(str.startsWith('&'))
			radix = 16;
		else
		{
			ret = false;
			return ret;
		}

		str = str[1..$].strip();
		foreach(ch; str)
		{
			bool isDecDigit = (ch >= '0' && ch <= '9');
			bool isHexDigit =
				isDecDigit ||
				(ch >= 'A' && ch <= 'F') ||
				(ch >= 'a' && ch <= 'f');
			
			if((radix == 10 && !isDecDigit) || (radix == 16 && !isHexDigit))
			{
				ret = false;
				return ret;
			}
		}
			
		int value;
		try
			value = parse!int(str, radix);
		catch(Exception e)
		{
			ret = false;
			return ret;
		}
		
		if(value < 0 || value > 0xFFFF)
		{
			ret = false;
			return ret;
		}
		
		ret = cast(dchar)value;
		return ret;
	}

	bool isCharCode(string str)
	{
		auto firstChar = str.stripLeft()[0];
		if(firstChar == '#' || firstChar == '&')
			return true;
		
		return false;
	}
	
	dstring parseCharCode(string str)
	{
		auto dotDot = std.algorithm.find(str, "..");
		if(dotDot.length > 2)
		{
			auto val1 = parseCharCodePart(str[0..$-dotDot.length]);
			auto val2 = parseCharCodePart(dotDot[2..$]);
			if(val1.type == typeid(dchar) && val2.type == typeid(dchar))
			{
				auto ch1 = val1.get!dchar();
				auto ch2 = val2.get!dchar();
				
				if(cast(int)ch1 > cast(int)ch2)
				{
					auto tmp = ch1;
					ch1 = ch2;
					ch2 = tmp;
				}
				
				dstring ret;
				foreach( i; cast(int)ch1 .. (cast(int)ch2)+1 )
					ret ~= cast(dchar)i;
					
				return ret;
			}
			else
			{
				error(parser.parseTreeX, "Invalid character range: '%s'".format(str));
				return null;
			}
		}
		else
		{
			auto value = parseCharCodePart(str);
			if(value.type == typeid(dchar))
			{
				auto ch = value.get!dchar();
				return [ch];
			}
		}

		error(parser.parseTreeX, "Invalid character constant: '%s'".format(str));
		return null;
	}
	
	dstring charSetNameToData(Insensitive name)
	{
		auto nameStr = name.toString();
		
		if(isCharCode(nameStr))
			return parseCharCode(nameStr);

		if(name in charSets)
			return charSets[name].data;

		error(parser.parseTreeX, "Character set is not defined: '%s'".format(name));
		return [];
	}
	
	void genSymbols()
	{
		mixin(verboseSection!"Generating symbols");

		// Built-in Terminals
		lang.eofSymbolIndex   = 0;
		lang.errorSymbolIndex = 1;
		if(Insensitive("EOF")   in terminals) terminals.remove(Insensitive("EOF"));
		if(Insensitive("Error") in terminals) terminals.remove(Insensitive("Error"));
		lang.symbolTable ~= Symbol("EOF",        SymbolType.EOF,        0);
		lang.symbolTable ~= Symbol("Error",      SymbolType.Error,      1);
		lang.symbolTable ~= Symbol("Whitespace", SymbolType.Whitespace, 2);

		auto defaultWhitespaceRegex = new ASTRegex();
		defaultWhitespaceRegex.seqs[0].items[0].charSetName =
			useMappingANSI? Insensitive("Whitespace") : Insensitive("All Whitespace");
		defaultWhitespaceRegex.seqs[0].items[0].kleene = Kleene.OneOrMore;
		
		auto defaultWhitespaceTerminal = ASTTerminal(true, SymbolType.Whitespace, defaultWhitespaceRegex, 2);

		assert(lang.symbolTable.length == 3);
		
		// Terminals
		void addTerm(Insensitive name, ref ASTTerminal sym)
		{
			auto cmp = Insensitive("Whitespace");
			if(name == cmp)
				sym.id = defaultWhitespaceTerminal.id;
			else
			{
				sym.id = cast(int)lang.symbolTable.length;
				lang.symbolTable ~= Symbol(name.toString(), sym.type, sym.id);
			}
		}
		void addTerms(bool doAllTerms, bool doExplicitTerms)
		{
			foreach(name; terminals.keys.sort)
			if(doExplicitTerms == terminals[name].explicit || doAllTerms)
			{
				addTerm(name, terminals[name]);
			}
		}
		
		if(goldCompat)
		{
			addTerms(false, false);
			addTerms(false, true);
		}
		else
			addTerms(true, true);
		
		if(terminals[Insensitive("Whitespace")].regex is null)
			terminals[Insensitive("Whitespace")] = defaultWhitespaceTerminal;
		
		firstNonTerminalId = cast(int)lang.symbolTable.length;
		
		// Non-Terminals
		void addNonTerm(Insensitive name, ref ASTNonTerminal sym)
		{
			sym.id = cast(int)lang.symbolTable.length;
			lang.symbolTable ~= Symbol("<"~name.toString()~">", SymbolType.NonTerminal, sym.id);
		}
		
		if(goldCompat)
		{
			foreach(name; nonterminals.keys.sort)
				addNonTerm(name, nonterminals[name]);
		}
		else
		{
			foreach(name, ref sym; nonterminals)
				addNonTerm(name, sym);
		}

		// Start Symbol
		if(Insensitive("Start Symbol") in params)
		{
			auto startSymName = Insensitive(params[Insensitive("Start Symbol")]);
			
			if(startSymName in nonterminals)
				lang.startSymbolIndex = nonterminals[startSymName].id;
			else
				error(parser.parseTreeX, "Invalid start symbol: '%s'".format(startSymName));
		}
		else
			error(parser.parseTreeX, "No start symbol specified");
	}
	
	void genRules()
	{
		mixin(verboseSection!"Generating rules");

		void addRule(ASTNonTerminal sym, ASTRuleRHS currRule)
		{
			Rule newRule;
			newRule.symbolIndex = sym.id;
			
			if(goldCompat)
				assert(currRule.id == lang.ruleTable.length);
			currRule.id = cast(int)lang.ruleTable.length;
			
			foreach(subSym; currRule.symbols)
			{
				if(subSym.type == SymbolType.NonTerminal)
					newRule.subSymbolIndicies ~= nonterminals[subSym.symbolName].id;
				else
				{
					auto cmp = Insensitive(null);
					if(subSym.symbolName != cmp)
						newRule.subSymbolIndicies ~= terminals[subSym.symbolName].id;
				}
			}
			
			lang.ruleTable ~= newRule;
		}
		
		if(goldCompat)
		{
			foreach(id; 0..nextRuleId)
			foreach(sym; nonterminals)
			foreach(rule; sym.rules)
			if(rule.id == id)
				addRule(sym, rule);
		}
		else
		{
			foreach(sym; nonterminals)
			foreach(currRule; sym.rules)
				addRule(sym, currRule);
		}
	}

	void genDFA()
	{
		//foreach(name, term; charSets)
		//	writeln("CHARSET: ", name);
		
		NFA  nfa;
		_DFA dfaRaw;
		_DFA dfa;
		
		NFAState[]  nfaStates;
		_DFAState[] dfaRawStates;
		_DFAState[] dfaStates;
		
		lang.dfaTable = genDFATable(
			this, nfa, dfaRaw, dfa,
			nfaStates, dfaRawStates, dfaStates,
			lang.initialDFAState, rawCharSetTable, goldCompat
		);
		if(keepDebugInfo)
		{
			this.nfa    = nfa;
			this.dfaRaw = dfaRaw;
			this.dfa    = dfa;
			lang.nfaDot    = toDOT!(FSMType.NFA)(nfaStates,    this);
			//lang.dfaRawDot = toDOT!(FSMType.DFA)(dfaRawStates, this);
			lang.dfaDot    = toDOT!(FSMType.DFA)(dfaStates,    this);
		}
	}

	void genLALR()
	{
		lang.lalrTable = genLALRTable(
			this, lang.symbolTable, lang.ruleTable,
			lang.startSymbolIndex, lang.eofSymbolIndex,
			lang.initialLALRState, goldCompat
		);
		
		checkLALRConflicts();
	}

	/// This only checks for reduce-reduce conflicts.
	/// The shift-reduce conflicts were already detected
	/// and handled while generating the LALR lookaheads.
	void checkLALRConflicts()
	{
		mixin(verboseSection!"Checking for LALR reduce-reduce conflicts");
		
		foreach(stateId, ref state; lang.lalrTable)
		{
			int[] reduceReduceSymIDs;
			int[] reduceReduceRuleIDs;

			foreach(int symId, sym; lang.symbolTable)
			{
				int[] reduceActions;
				foreach(int actionIndex, action; state.actions)
				if(action.symbolId == symId && action.type == LALRAction.Type.Reduce)
					reduceActions ~= actionIndex;
				
				if(reduceActions.length > 1)
				{
					reduceReduceSymIDs ~= symId;
					foreach(actionIndex; reduceActions)
					{
						auto reduceRuleId = state.actions[actionIndex].target;
						if(!contains(reduceReduceRuleIDs, reduceRuleId))
							reduceReduceRuleIDs ~= reduceRuleId;
					}
				}
			}
			
			if(reduceReduceSymIDs.length > 0)
			{
				string lookaheadStr;
				foreach(symId; reduceReduceSymIDs)
				{
					lookaheadStr ~= " ";
					lookaheadStr ~= lang.symbolTable[symId].name;
				}
				
				string ruleStr;
				foreach(ruleId; reduceReduceRuleIDs)
				{
					ruleStr ~= "\n    ";
					ruleStr ~= lang.ruleToString(ruleId);
				}
				
				warning(
					parser.parseTreeX,
					("Reduce-Reduce conflict:\n"~
					"  In LALR State #%s\n"~
					"  When next token is one of:%s\n"~
					"  Don't know which rule to reduce:%s\n")
						.format(stateId, lookaheadStr, ruleStr)
				);
			}
		}
	}
}

struct ASTCharSet
{
	//ASTCharSetItem[] items;
	private dstring str;
	
	@property dstring data()
	{
		return str;
	}
	
	string toString()
	{
		return to!string(str);
		/+dstring str="";
		
		foreach(item; items)
		{
			if(item.first == item.last)
				str ~= item.first;
			else
			{
				foreach(uint ch; cast(uint)item.first .. cast(uint)item.last+1)
					str ~= cast(dchar)ch;
			}
		}
		
		return to!string(str);+/
	}
	
	ref ASTCharSet combine(dchar ch, ASTCharSetMode mode = ASTCharSetMode.Plus)
	{
		final switch(mode)
		{
		case ASTCharSetMode.Plus:
			str ~= ch;
			break;

		case ASTCharSetMode.Minus:
			auto i = locate(str, ch);

			if(i == str.length-1)
				str = str[0..i];
				
			else if(i < str.length)
				str = str[0..i] ~ str[i+1..$];

			break;
		}
		
		return this;
	}

	ref ASTCharSet combine(dstring newStr, ASTCharSetMode mode = ASTCharSetMode.Plus)
	{
		final switch(mode)
		{
		case ASTCharSetMode.Plus:
			if(str == "")
				str = newStr;
			else
			{
				foreach(ch; newStr)
				if(!contains(str, ch))
					str ~= ch;
			}
			break;

		case ASTCharSetMode.Minus:
			foreach(ch; newStr)
			{
				auto i = locate(str, ch);

				if(i == str.length-1)
					str = str[0..i];
					
				else if(i < str.length)
					str = str[0..i] ~ str[i+1..$];
			}
			break;
		}
		
		return this;
	}

	ref ASTCharSet combine(ASTCharSetItem item, ASTCharSetMode mode = ASTCharSetMode.Plus)
	{
		dstring newStr;

		if(item.first == item.last)
			newStr = [item.first];
		else
		{
			foreach(uint ch; cast(uint)item.first .. cast(uint)item.last+1)
				newStr ~= cast(dchar)ch;
		}

		return combine(newStr, mode);
	}

	ref ASTCharSet combine(ASTCharSet set, ASTCharSetMode mode = ASTCharSetMode.Plus)
	{
		return combine(set.str, mode);
	}
	
	CharSet toGoldieCharSet()
	{
		return CharSet(str);
	}
}

enum ASTCharSetMode
{
	Plus, Minus,
}

struct ASTCharSetItem
{
	// Both are inclusive
	dchar first;
	dchar last;
}

struct ASTTerminal
{
	bool explicit; // Was this explicitly declared? (As opposed to a literal inside a rule)
	SymbolType type = SymbolType.Terminal;
	ASTRegex regex;
	int id = -7; // Inited with something easily identifiable (less than -1)
	
	private int _priority = -1;
	@property int priority()
	{
		if(_priority == -1)
		{
			// Give priority to symbols with no kleene stars or kleene plusses
			_priority = regex.hasKleeneMany? 0 : 1;
		}
		
		return _priority;
	}
}

struct ASTNonTerminal
{
	ASTRuleRHS[] rules;
	int id = -7; // Inited with something easily identifiable (less than -1)
}

/// Right-hand side of a rule, left-hand side is the enclosing ASTNonTerminal
struct ASTRuleRHS
{
	ASTRuleSubSymbol[] symbols;
	int id = -7; // Inited with something easily identifiable (less than -1)
}

struct ASTRuleSubSymbol
{
	Insensitive symbolName;
	SymbolType type;
}

class ASTRegex
{
	ASTRegexSeq[] seqs;
	
	this()
	{
		seqs = [new ASTRegexSeq()];
	}
	
	override string toString()
	{
		string str;
		foreach(i, seq; seqs)
			str ~= (i==0? "":" | ") ~ seq.toString();
		return "("~str~")";
	}

	private bool _hasKleeneMany;
	private bool _hasKleeneManyCached = false;
	@property bool hasKleeneMany()
	{
		if(!_hasKleeneManyCached)
		{
			foreach(seq; seqs)
			foreach(item; seq.items)
			if(item.hasKleeneMany)
			{
				_hasKleeneMany = true;
				return _hasKleeneMany;
			}
				
			_hasKleeneMany = false;
		}

		return _hasKleeneMany;
	}
}

class ASTRegexSeq
{
	ASTRegexItem[] items;
	
	this()
	{
		items = [new ASTRegexItem()];
	}
	
	override string toString()
	{
		string str;
		foreach(i, item; items)
			str ~= (i==0? "":" ") ~ item.toString();
		return str;
	}
}

enum Kleene
{
	One, OneOrMore, ZeroOrOne, ZeroOrMore,
}

class ASTRegexItem
{
	ASTRegex regex;
	string charSetLiteral;
	Insensitive charSetName;
	string termLiteral;
	Kleene kleene;
	
	override string toString()
	{
		string str;
		auto cmp = Insensitive(null);
		if(regex !is null)                   str = regex.toString();
		if(charSetLiteral !is null)          str = "["~charSetLiteral~"]";
		if(charSetName != cmp) 				 str = "{"~charSetName.toString()~"}";
		if(termLiteral !is null)             str = "'"~termLiteral~"'";
		
		if(regex is null && charSetLiteral is null && charSetName == cmp && termLiteral is null)
			str = "-!NULL!-";
		
		switch(kleene)
		{
		case Kleene.OneOrMore:  str ~= "+"; break;
		case Kleene.ZeroOrOne:  str ~= "?"; break;
		case Kleene.ZeroOrMore: str ~= "*"; break;
		default: break;
		}
		
		return str;
	}
	
	@property bool hasKleeneMany()
	{
		if(kleene == Kleene.OneOrMore || kleene == Kleene.ZeroOrMore)
			return true;
		
		if(regex !is null)
			return regex.hasKleeneMany;
		
		return false;
	}
}
