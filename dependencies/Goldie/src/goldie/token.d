// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

module /+S:PACKAGE+/goldie/+E:PACKAGE+/.token;

/+P:INIT_STATIC_LANG+/
version(Goldie_StaticStyle) {} else
	version = Goldie_DynamicStyle;

version(Goldie_StaticStyle)
version(DigitalMars)
{
	import std.compiler;
	static if(version_major == 2 && version_minor == 57)
		static assert(false, "Goldie's static-style and grammar compiling don't work on DMD 2.057 due to DMD Issue #7375");
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

import std.algorithm;
import std.exception;
import std.functional;
import std.string;
import std.traits;
import std.typecons;

import semitwist.treeout;
import semitwist.util.all;

import goldie.base;
import goldie.exception;
import goldie.lang;

static if(__traits(compiles, std.ascii.digits))
{
	import std.ascii;
	private alias std.ascii.digits digits;
	private alias std.ascii.letters letters;
}

private alias semitwist.util.ctfe.ctfe_strip ctfe_strip;

version(Goldie_StaticStyle)
{
	import goldie.token;
	mixin(`
		import `~_packageName~`.lang;
	`);
}

version(Goldie_DynamicStyle)
{
	enum CommentType
	{
		None,
		Line,
		Block,
	}

	enum TokenToStringMode
	{
		Compact,           // Omit all whitespace, error and comment tokens.
		CompactWithSpaces, // Like Compact, but adds a space between each token.
		
		Smart,             // Default: Like Compact, but adds a space between two
						   //   tokens whenever the last character of the first
						   //   token and the first character of the second token
						   //   are both either alphanumeric or an underscore.

		// Full doesn't currently work after the parse phase because
		// ignored tokens are not currently preserved by the parser.
		//TODO: Fix this
		Full,              // Includes all whitespace, error and comment tokens.
	}
}

version(Goldie_StaticStyle)
{
	template /+P:TOKEN_CLASSNAME+/DUMMY()
	{
		alias Base_/+P:TOKEN_CLASSNAME+/ /+P:TOKEN_CLASSNAME+/DUMMY;
	}

	template /+P:TOKEN_CLASSNAME+/DUMMY(string staticName=null)
	{
		/+P:TOKEN_TEMPLATE_1P+/
	}

	template /+P:TOKEN_CLASSNAME+/DUMMY(SymbolType staticSymbolType, string staticName)
	{
		/+P:TOKEN_TEMPLATE_2P+/
	}

	private template /+P:TOKEN_CLASSNAME+/DUMMY(string staticName, int staticRuleId)
	{
		/+P:TOKEN_TEMPLATE_RULE+/
	}

	template /+P:IS_CORRECT_TOKEN_FUNCNAME+/DUMMY(string token, int type, string name)
	{
		static if(token == name)
			static if(/+P:LANG_CLASSNAME+/DUMMY./+S:TO:STATIC_IDENT+/isSymbolNameAmbiguous/+E:TO:STATIC_IDENT+/(token))
				static assert(false, "Token name '"~staticName~
					"' is ambiguous, please specify SymbolType"~
					" (ex: /+P:TOKEN_CLASSNAME+/!(SymbolType.Terminal, \"+\"))\n"~
					"Possible types: ["~/+P:LANG_CLASSNAME+/DUMMY.symbolTypesByName(name).goldSymbolTypesToString()~"]");
			else
				enum bool /+P:IS_CORRECT_TOKEN_FUNCNAME+/DUMMY = true;
		else
			enum bool /+P:IS_CORRECT_TOKEN_FUNCNAME+/DUMMY = false;
	}
	
	template /+P:IS_CORRECT_TOKEN_FUNCNAME+/DUMMY(token, int type, string name)
	{
		static if(is( token:_/+P:TOKEN_CLASSNAME+/!(cast(SymbolType)type, name) ))
			enum bool /+P:IS_CORRECT_TOKEN_FUNCNAME+/DUMMY = true;
		else
			enum bool /+P:IS_CORRECT_TOKEN_FUNCNAME+/DUMMY = false;
	}
	
	template /+P:TOKEN_CLASSNAME+/DUMMY(string staticName, subTokenTypes...)
		if(
			subTokenTypes.length != 0 &&
			(subTokenTypes.length > 1 || !isIntegral!(typeof(subTokenTypes[0])))
		)
	{
		alias _/+P:TOKEN_CLASSNAME+/!(SymbolType.NonTerminal, staticName, /+P:RULE_ID_OF_FUNCNAME+/DUMMY!(staticName, subTokenTypes)) /+P:TOKEN_CLASSNAME+/DUMMY;
	}
	
	//TODO? Move this to goldie.lang
	template /+P:RULE_ID_OF_FUNCNAME+/DUMMY(string staticName, subTokenTypes...)
	{
		/+P:RULE_ID_OF+/
	}
	
	template /+P:SUBTOKENTYPE_NAME+/DUMMY(int ruleId, int index)
	{
		/+P:SUBTOKENTYPE_TEMPLATE+/
	}
	
	private class _/+P:TOKEN_CLASSNAME+/(SymbolType staticSymbolType, string staticName, int staticRuleId) : _/+P:TOKEN_CLASSNAME+/!(staticSymbolType, staticName)
	{
		// StringOf is a workaround for DMD Bug #1748
		//TODO: expand that "..."
		static enum string StringOf = "/+P:TOKEN_CLASSNAME+/!("~fullSymbolTypeToString(staticSymbolType)~", "~staticName.stringof~", ...)";

		//TODO: This should take Token_{langaugeName}[], not Token[]
		this(Token[] sub, Language lang)
		{
			super(sub, lang, staticRuleId);
		}

		@property /+P:SUBTOKENTYPE_NAME+/DUMMY!(staticRuleId, index) sub(int index)()
		{
			return cast(/+P:SUBTOKENTYPE_NAME+/DUMMY!(staticRuleId, index))subX[index];
		}
	}

	private class Base_/+P:TOKEN_CLASSNAME+/ : Token
	{
		static enum string StringOf = "/+P:TOKEN_CLASSNAME+/";

		this(Symbol symbol, Language lang, string content,
					string file="{unknown}", ptrdiff_t line=0,
					ptrdiff_t srcIndexStart=0, ptrdiff_t srcIndexEnd=0,
					CommentType commentMode=CommentType.None,
					string debugInfo="")
		{
			super(
				symbol, lang, content,
				file, line,
				srcIndexStart, srcIndexEnd,
				commentMode,
				debugInfo
			);
		}
		
		this(Symbol symbol, Token[] sub, Language lang, int ruleId)
		{
			super(symbol, sub, lang, ruleId);
		}
	}
}

version(Goldie_DynamicStyle)
{
	//TODO: Change to @property member of Token when DMD BUG3051 is fixed.
	auto traverse(T : Token)(T _this)
	{
		return traverse!""(_this);
	}

	//TODO: Change to @property member of Token when DMD BUG3051 is fixed.
	auto traverse(alias pred)(Token _this)
		if(
			(is(typeof(pred):string) && pred == "") ||
			is(typeof(unaryFun!pred))
		)
	{
		struct Result
		{
			Token start;
			
			this(Token start)
			{
				this.start = start;
				
				stack = new Stack!StackElem();
				stack ~= StackElem(-1, start);
				
				advance();
			}
			
			private Token _front;

			private struct StackElem
			{
				size_t index;
				Token token;
			}
			private Stack!StackElem stack;
			
			private void advance()
			{
				while(!stack.empty)
				{
					// Advance to next subtoken
					stack.top.index++;
					
					// Reached last subtoken?
					if(stack.top.index >= stack.top.token.subX.length)
					{
						stack.pop();
						continue;
					}
					
					// Set new subtoken
					_front = stack.top.token.subX[stack.top.index];

					// Enter current subtoken?
					static if(is(typeof(pred):string) && (pred.ctfe_strip() == "" || pred.ctfe_strip() == "true"))
					{
						stack ~= StackElem(-1, _front);
						return;
					}
					else
					{
						if(unaryFun!pred(_front))
						{
							stack ~= StackElem(-1, _front);
							return;
						}
					}
				}
				
				_front = null;
			}
			
			void skip()
			{
				// Move to end of this token, then advance.
				stack.top.index = stack.top.token.subX.length;
				advance();
			}
			
			Token front()
			{
				return _front;
			}

			void popFront()
			{
				advance();
			}
			
			@property bool empty()
			{
				return stack.empty;
			}

			@property auto save()
			{
				auto r = Result(start);
				r._front = _front;
				r.stack = stack.dup;
				return r;
			}
		}

		return Result(_this);
	}
}

//TODO: Add way to get token's rule in string form (like what's shown in dumpcgt)
//TODO? Make wrong ctor private in Token_calc!{symbol}? Make all ctors private in Token_calc?
version(Goldie_DynamicStyle)
class Token
{
	private string content = "";
	mixin(getter!(int, "ruleId"));
	mixin(getter!(string, "debugInfo"));
	mixin(getter!(CommentType, "commentMode"));
	mixin(getter!(Language, "lang"));
	SymbolType type;
	Symbol symbol;
	
	this(
		Symbol symbol, Language lang, string content,
		string file="{unknown}", ptrdiff_t line=0,
		ptrdiff_t srcIndexStart=0, ptrdiff_t srcIndexEnd=0,
		CommentType commentMode=CommentType.None,
		string debugInfo=""
	)
	{
		this.content = content;
		
		// Workaround for DMD Bug #2881
		this._commentMode = commentMode;
		
		this._lang = lang;
		this._file = file;
		this._line = line;

		this._debugInfo     = debugInfo;
		this._srcIndexStart = srcIndexStart;
		this._srcIndexEnd   = srcIndexEnd;

		this._ruleId = -1;
		this.symbol = symbol;
		this.type = symbol.type;
		
		if(type == SymbolType.NonTerminal)
			throw new IllegalArgumentException("Called wrong constructor for NonTerminal");
	}

	this(Symbol symbol, Token[] sub, Language lang, int ruleId)
	{
		//TODO: Ensure ruleId is valid for this symbol in both dynamic and static
		this.symbol = symbol;
		this._ruleId = ruleId;
		this._lang = lang;
		this.type = symbol.type;
		this.subX = sub;
		
		if(type != SymbolType.NonTerminal)
			throw new IllegalArgumentException("Called wrong constructor for token that isn't a NonTerminal");
	}
	
	// The sub-tokens of this token (if this is a NonTerminal)
	Token[] subX;
	
	//TODO: Replace these op overloads with alias this once DMD #3537 is fixed.
	//TODO: Make make subX private once Goldie drops support for < DMD 2.057 (due to opDollar)
	//TODO: Need to "replace these op overloads with alias this" AND "make subX private",
	//      but do ONLY ONE of those tasks until the following DMD "alias this"
	//      issues are fixed: #3537, #3626, #5973, #6456
	//alias subX this;
	
	@property size_t length()
	{
		return subX.length;
	}
	
	size_t opDollar()
	{
		return subX.length;
	}
	
	Token opIndex(size_t index)
	{
		return subX[index];
	}

	Token opIndexAssign(Token tok, size_t index)
	{
		return subX[index] = tok;
	}

	Token[] opSlice()
	{
		return subX[];
	}

	Token[] opSlice(size_t a, size_t b)
	{
		return subX[a..b];
	}

	Token[] opSliceAssign(Token tok)
	{
		return subX[] = tok;
	}

	Token[] opSliceAssign(Token tok, size_t a, size_t b)
	{
		return subX[a..b] = tok;
	}

	Token[] opSliceAssign(Token[] toks)
	{
		return subX[] = toks;
	}

	Token[] opSliceAssign(Token[] toks, size_t a, size_t b)
	{
		return subX[a..b] = toks;
	}

	int opApply(int delegate(ref Token) dg)
	{
		int result = 0;

		foreach(ref Token tok; subX)
		{
			result = dg(tok);
			if(result)
				break;
		}
		return result;
	}

	int opApply(int delegate(ref size_t, ref Token) dg)
	{
		int result = 0;

		foreach(size_t i, ref Token tok; subX)
		{
			result = dg(i, tok);
			if(result)
				break;
		}
		return result;
	}

	int opApplyReverse(int delegate(ref Token) dg)
	{
		int result = 0;

		foreach_reverse(ref Token tok; subX)
		{
			result = dg(tok);
			if(result)
				break;
		}
		return result;
	}

	int opApplyReverse(int delegate(ref size_t, ref Token) dg)
	{
		int result = 0;

		foreach_reverse(size_t i, ref Token tok; subX)
		{
			result = dg(i, tok);
			if(result)
				break;
		}
		return result;
	}
	
	mixin(getterLazy!(ptrdiff_t, "line", q{
		if(type == SymbolType.NonTerminal && subX.length > 0)
			return firstLeaf.line;
		else
			return _line;
	}));
	
	mixin(getterLazy!(string, "file", q{
		if(type == SymbolType.NonTerminal && subX.length > 0)
			return firstLeaf.file;
		else
			return _file;
	}));
	
	mixin(getterLazy!(ptrdiff_t, "srcIndexStart", q{
		if(type == SymbolType.NonTerminal && subX.length > 0)
			return firstLeaf.srcIndexStart;
		else
			return _srcIndexStart;
	}));
	
	mixin(getterLazy!(ptrdiff_t, "srcIndexEnd", q{
		if(type == SymbolType.NonTerminal && subX.length > 0)
			return lastLeaf.srcIndexEnd;
		else
			return _srcIndexEnd;
	}));
	
	mixin(getterLazy!(Token, "firstLeaf", q{
		if(type == SymbolType.NonTerminal && subX.length > 0)
		{
			foreach(Token subToken; subX)
			{
				if(subToken.type != SymbolType.NonTerminal || subToken.subX.length > 0)
					return subToken.firstLeaf;
			}
		}

		return this;
	}));
	
	mixin(getterLazy!(Token, "lastLeaf", q{
		if(type == SymbolType.NonTerminal && subX.length > 0)
		{
			foreach_reverse(Token subToken; subX)
			{
				if(subToken.type != SymbolType.NonTerminal || subToken.subX.length > 0)
					return subToken.lastLeaf;
			}
		}

		return this;
	}));
	
	@property ptrdiff_t srcLength()
	{
		return srcIndexEnd - srcIndexStart;
	}

	@property string typeName()
	{
		return symbolTypeToString(type);
	}

	@property string name()
	{
		return symbol.name;
	}

	//TODO? Change-to/suppliment-with something that returns Token_blah!(SymbolType.NonTerminal, "foo")
	mixin(getterLazy!(string, "fullName", q{
		return "%s.%s".format(typeName, name);
	}));
	
	private void ensureValidSymbol(string symbolName)
	{
		if(!_lang.isSymbolNameValid(symbolName))
			throw new Exception(
				"'%s' is not a valid symbol name"
					.format(symbolName)
			);
	}

	bool matches(string parentSymbol, string[] subSymbols...)
	{
		if(_lang.isSymbolNameAmbiguous(parentSymbol))
			throw new Exception(
				"Symbol '%s' is ambiguous, it could be any of the following types: %s\nmatches() doesn't yet support disambiguation of symbol names at runtime."
					.format(parentSymbol, _lang.symbolTypesStrByName(parentSymbol))
			);

		ensureValidSymbol(parentSymbol);

		bool isParentNonTerminal =
			_lang.symbolsByName(parentSymbol)[0].type == SymbolType.NonTerminal;
		
		if(type == SymbolType.NonTerminal && isParentNonTerminal)
			return ruleId == _lang.ruleIdOf(parentSymbol, subSymbols);
		else if(type != SymbolType.NonTerminal && !isParentNonTerminal)
			return parentSymbol == symbol.name && subSymbols.length == 0;
		else
			return false;
	}
	
	//TODO: Optimize with compile-time tricks
	T get(T)(int index=0) if(is(T : Token) && !is(T == Token) && __traits(compiles, T.staticName))
	{
		enforce(index >= 0, "index must be positive");

		foreach(tok; subX)
		if(auto staticTok = cast(T)tok)
		{
			if(index == 0)
				return staticTok;
			else
				index--;
		}
		
		return null;
	}
	
	Ts[$-1] get(Ts...)() if(Ts.length > 1)
	{
		static assert(
			is(Ts[0] : Token) && !is(Ts[0] == Token) && __traits(compiles, Ts[0].staticName),
			"T must be a static-style Token class"
		);

		auto subTok = get!(Ts[0])(0);
		if(subTok)
		{
			static if(Ts.length == 1)
				return subTok;
			else
				return subTok.get!(Ts[1..$]);
		}
		else
			return cast(Ts[$-1])null;
	}

	Token get()(string symbolName, int index=0)
	{
		enforce(index >= 0, "index must be positive");
		ensureValidSymbol(symbolName);

		foreach(tok; subX)
		if(tok.name == symbolName)
		{
			if(index == 0)
				return tok;
			else
				index--;
		}
		
		return null;
	}
	
	Token get()(string[] symbolNames)
	{
		if(symbolNames.length == 0)
			return this;
		
		auto symName = symbolNames[0];
		auto subTok = get(symName);
		if(subTok)
			return subTok.get(symbolNames[1..$]);
		else
			return null;
	}
	
	T getRequired(T)(int index=0) if(is(T : Token) && !is(T == Token))
	{
		auto result = get!(T)(index);

		if(result is null)
			throw new Exception("Token not found");
		
		return result;
	}
	
	Ts[$-1] getRequired(Ts...)() if(Ts.length > 1)
	{
		auto result = get!(Ts)();

		if(result is null)
			throw new Exception("Token not found");
		
		return result;
	}
	
	Token getRequired()(string symbolName, int index=0)
	{
		auto result = get(symbolName, index);

		if(result is null)
			throw new Exception(`Doesn't exist: getRequired(%s, %s)`.format(symbolName.escapeDDQS(), index));
		
		return result;
	}
	
	Token getRequired()(string[] symbolNames)
	{
		auto result = get(symbolNames);

		if(result is null)
			throw new Exception("Token not found");
		
		return result;
	}
	
	override string toString()
	{
		return toString(TokenToStringMode.Smart);
	}
	
	string toString(TokenToStringMode mode)
	{
		switch(mode)
		{
		case TokenToStringMode.Compact:
			return toStringCompact();
			
		case TokenToStringMode.CompactWithSpaces:
			return toStringCompactWithSpaces();
			
		case TokenToStringMode.Smart:
			return toStringSmart();
			
		case TokenToStringMode.Full:
			return toStringFull();
			
		default:
			throw new InternalException("Unknown TokenToStringMode: #%s".format(mode));
		}
	}
	
	string toStringCompact()
	{
		string ret;
		
		switch(type)
		{
		case SymbolType.NonTerminal:
			foreach(Token tok; subX)
				ret ~= tok.toStringCompact();
			break;
			
		case SymbolType.Terminal:
			ret = content;
			break;
			
		case SymbolType.Whitespace:
		case SymbolType.EOF:
		case SymbolType.CommentStart:
		case SymbolType.CommentEnd:
		case SymbolType.CommentLine:
		case SymbolType.Error:
			ret = "";
			break;
			
		default:
			throw new InternalException("Unknown SymbolType: #%s".format(type));
		}
		
		return ret;
	}
	
	string toStringCompactWithSpaces()
	{
		string ret;
		
		switch(type)
		{
		case SymbolType.NonTerminal:
			string[] toks;
			foreach(Token tok; subX)
				toks ~= tok.toStringCompactWithSpaces();
			ret = toks.join(" ");
			break;
			
		case SymbolType.Terminal:
			ret = content;
			break;
			
		case SymbolType.Whitespace:
		case SymbolType.EOF:
		case SymbolType.CommentStart:
		case SymbolType.CommentEnd:
		case SymbolType.CommentLine:
		case SymbolType.Error:
			ret = "";
			break;
			
		default:
			throw new InternalException("Unknown SymbolType: #%s".format(type));
		}
		
		return ret;
	}

	string toStringSmart()
	{
		string ret;
		
		switch(type)
		{
		case SymbolType.NonTerminal:
			string[] toks;
			foreach(Token tok; subX)
			{
				string tokStr = tok.toStringSmart();
				
				if(tokStr == "")
					continue;
					
				if( toks.length > 0 &&
					contains(letters~digits~'_', tokStr[0]     ) &&
					contains(letters~digits~'_', toks[$-1][$-1]) )
				{
					toks ~= " ";
				}

				toks ~= tokStr;
			}
			ret = toks.join("");
			break;
			
		case SymbolType.Terminal:
			ret = content;
			break;
			
		case SymbolType.Whitespace:
		case SymbolType.EOF:
		case SymbolType.CommentStart:
		case SymbolType.CommentEnd:
		case SymbolType.CommentLine:
		case SymbolType.Error:
			ret = "";
			break;
			
		default:
			throw new InternalException("Unknown SymbolType: #%s".format(type));
		}
		
		return ret;
	}

	string toStringFull()
	{
		string ret;
		
		if(type == SymbolType.NonTerminal)
		{
			foreach(Token tok; subX)
				ret ~= tok.toStringFull();
		}
		else
			ret = content;
			
		return ret;
	}

	TreeNode toTreeNode(size_t index=0)
	{
		auto start = srcIndexStart;
		auto node = new TreeNode( "%s: %s".format(index, name) );
		node.addAttribute("srcIndexStart", start);
		//node.addAttribute("srcIndexEnd", srcIndexEnd());
		node.addAttribute("srcLength", srcIndexEnd - start);
		node.addAttribute("line", line+1);
		node.addAttribute("type", typeName);
		node.addAttribute("symbol", name);
		node.addAttribute("commentMode", commentMode);
		if(_debugInfo != "")
			node.addAttribute("debugInfo", debugInfo);
		//node.addAttribute("content", toStringRaw());
		
		if(type == SymbolType.NonTerminal)
		foreach(size_t i, Token tok; subX)
			node.addContent(tok.toTreeNode(i));
		
		return node;
	}
	
	TreeNode toPsuedoTreeNode()
	{
		auto node = new TreeNode(toString(TokenToStringMode.Full));
		node.addAttribute("symbol", fullName);

		if(type == SymbolType.NonTerminal)
		foreach(Token tok; subX)
			node.addContent(tok.toPsuedoTreeNode());
		
		return node;
	}
}

version(Goldie_StaticStyle)
{
	/+S:TOKEN_INHERIT+/class Token/+E:TOKEN_INHERIT+/
	{
		// StringOf is a workaround for DMD Bug #1748
		static enum string StringOf = "Token_calc!("~fullSymbolTypeToString(staticSymbolType)~", "~staticName.stringof~")";
		static enum string staticName = _staticName;
		
		static if(staticSymbolType != SymbolType.NonTerminal) // Terminal?
		{

			// Static Terminal ctor
			this(
				Language lang, string content,
				string file="{unknown}", ptrdiff_t line=0,
				ptrdiff_t srcIndexStart=0, ptrdiff_t srcIndexEnd=0,
				CommentType commentMode=CommentType.None,
				string debugInfo=""
			)
			{
				/+P:SET_STATICID_TERM+/
				super(
					/+P:LANG_CLASSNAME+/DUMMY.staticSymbolTable[staticId],
					lang, content,
					file, line,
					srcIndexStart, srcIndexEnd,
					commentMode,
					debugInfo
				);
			}

		}
		else
		{

			// Static NonTerminal ctor
			this(Token[] sub, Language lang, int ruleId)
			{
				/+P:SET_STATICID_NONTERM+/
				super(/+P:LANG_INSTNAME+/DUMMY.symbolTable[staticId], sub, lang, ruleId);
			}

		}
	}
}
