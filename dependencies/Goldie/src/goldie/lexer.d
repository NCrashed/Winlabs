﻿// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

module /+S:PACKAGE+/goldie/+E:PACKAGE+/.lexer;

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

import std.conv;
import std.string;
import std.utf;

import semitwist.util.all;

import goldie.base;
import goldie.exception;
import goldie.file;
import goldie.lang;
import goldie.parser;
import goldie.token;

version(Goldie_StaticStyle)
{
	import goldie.lexer;
	mixin(`
		import `~_packageName~`.lang;
		import `~_packageName~`.token;
	`);
}

//TODO? Make lexer/parser a producer/consumer relationship for streamed parsing
//TODO: Make lexer steppable
//TODO? Generate recording of steps taken
/+S:LEXER_INHERIT+/class Lexer/+E:LEXER_INHERIT+/
{
	version(Goldie_DynamicStyle)
	{
		mixin(getterLazy!("protected", LexError[], "errors", q{
			LexError[] ret;
			foreach(Token tok; _tokens)
			{
				if(tok.type == SymbolType.Error && tok.commentMode == CommentType.None)
				{
					ret ~=
						LexError(
							tok.file, tok.line,
							(tok.srcIndexStart-lineIndicies[tok.line]),
							tok.toString(TokenToStringMode.Full)
						);
				}
			}
			return ret;
		}));
		
		string source;
		mixin(getter!("protected", Token[], "tokens"));

		ptrdiff_t[] lineIndicies;

		ptrdiff_t lineAtIndex(ptrdiff_t index)
		{
			foreach_reverse(ptrdiff_t line, ptrdiff_t lineStart; lineIndicies)
			{
				if(lineStart < index)
					return line;
			}
			return 0;
		}
		
		protected DFAState[] dfaTable;
		protected Symbol[]   symbolTable;
		protected CharSet[]  charSetTable;
		protected void getTables(Language lang)
		{
			dfaTable     = lang.dfaTable;
			symbolTable  = lang.symbolTable;
			charSetTable = lang.charSetTable;
		}

		ptrdiff_t srcIndex=0;
		ptrdiff_t line=0;
		string filename="";
	}

	//TODO? Make comment tok instead of error tok if error occurs in comment mode
	/+P:OVERRIDE+/ Token[] process(string source, Language lang, string filename="")
	{
		this.source = source;
		
		string tok;
		
		srcIndex=0;
		line=0;
		this.filename = filename;
		int  state = lang.initialDFAState;
		bool eof = false;
		bool errorFound = false;
		
		auto commentMode = CommentType.None;
		auto commentModeOfErr = CommentType.None;
		
		bool foundAcceptState;
		typeof(state)    lastAcceptState;
		typeof(srcIndex) lastAcceptIndex;
		
		getTables(lang);
		
		size_t cSize;

		Token mergeErrors(Token tok1, Token tok2)
		in
		{
			mixin(deferAssert!(`tok1.type == SymbolType.Error`));
			mixin(deferAssert!(`tok2.type == SymbolType.Error`));
			mixin(deferAssert!(`tok1.symbol.id == lang.errorSymbol.id`));
			mixin(deferAssert!(`tok2.symbol.id == lang.errorSymbol.id`));
			mixin(deferEnsure!(`tok1.srcIndexStart`, `_ < tok2.srcIndexStart`));
			mixin(deferEnsure!(`tok1.srcIndexEnd`, `_ < tok2.srcIndexEnd`));
			mixin(deferEnsure!(`tok1.srcIndexEnd`, `_ == tok2.srcIndexStart`));
			flushAsserts();
		}
		body
		{
			version(Goldie_DynamicStyle)
				alias Token _ErrorToken;
			else
				alias ThisStaticToken!(SymbolType.Error, "Error") _ErrorToken;
			
			return
				new _ErrorToken(
					/+S:REM+/lang.errorSymbol,/+E:REM+/lang,
					tok1.toString(TokenToStringMode.Full) ~ tok2.toString(TokenToStringMode.Full),
					tok1.file, tok1.line,
					tok1.srcIndexStart,
					tok2.srcIndexEnd,
					tok1.commentMode,
					tok1.debugInfo
				);
		}
		
//TODO: Make sure col values are correct when there are multi-byte chars
		bool advanceState(dchar c)
		{
			bool charAccepted = false;
			foreach(DFAStateEdge edge; dfaTable[state].edges)
			{
				if(charSetTable[edge.charSetIndex].matches(c))
				{
					state = edge.targetDFAStateIndex;
					charAccepted = true;
					tok ~= source[srcIndex..srcIndex+cSize];//to!(string)(c~""d);
					break;
				}
			}
			return charAccepted;
		}
		
		void addToken(Symbol symbol, string content)
		{
			int srcIndexOffset = 0;
			if(symbol.type == SymbolType.Error)
			{
				if(commentMode == CommentType.None)
					errorFound = true;

				if(!eof)
					srcIndexOffset = 1;
			}

			if(content != "" || symbol.type == SymbolType.EOF)
			{
				/+S:ACCEPT_TERM:STORE+/
				_tokens ~=
					new /+S:ACCEPT_TERM:TOKEN_CLASSNAME+/Token/+E:ACCEPT_TERM:TOKEN_CLASSNAME+/(
						/+S:REM+/symbol, /+E:REM+/lang, content,
						filename, line,
						srcIndex+srcIndexOffset-cast(int)content.length,
						srcIndex+srcIndexOffset,
						commentMode,
						null
					);
				/+E:ACCEPT_TERM:STORE+/
				/+P:ACCEPT_TERM+/
			}
			
			// Merge adjacent error tokens
			if( _tokens.length >= 2 &&
			    _tokens[$-2].type == SymbolType.Error &&
			    _tokens[$-1].type == SymbolType.Error )
			{
				_tokens = _tokens[0..$-2] ~ mergeErrors(_tokens[$-2], _tokens[$-1]);
			}
				
			commentMode =
				(
					commentMode == CommentType.None &&
					symbol.type == SymbolType.CommentStart
				)? CommentType.Block :
				(
					commentMode == CommentType.None &&
					symbol.type == SymbolType.CommentLine
				)? CommentType.Line :
				(
					commentMode == CommentType.Block &&
					symbol.type == SymbolType.CommentEnd
				)? CommentType.None :
				commentMode;

			foundAcceptState = false;
		}
		
		//TODO: Unicode adds yet another EOL
		bool isNewline()
		{
			bool ret=false;
			if(srcIndex < source.length)
			{
				if(source[srcIndex] == '\n')  // Win and Unix style
					ret = true;
				else
				{
					if(srcIndex+1 < source.length)
					{
						// Old-Mac style
						if(source[srcIndex] == '\r' && source[srcIndex+1] != '\n')
							ret = true;
					}
				}
			}
			return ret;
		}
		
		_tokens.length = 0;
		foundAcceptState = false;
		lineIndicies.length = 0;
		lineIndicies ~= 0;
		size_t lastAcceptIndexSize;
		
		if(source.length != 0)
		while(!eof)
		{
			dchar c;
			bool charAccepted = false;

			if(srcIndex == source.length)
				eof = true;

			if(!eof)
			{
				cSize = 0;
				
				bool invalidUtf = false;
				auto remainingSource = source[srcIndex..$];
				try
					c = decode(remainingSource, cSize);
				catch(UTFException e)
				{
					errorFound = true;
					invalidUtf = true;
				}
				if(invalidUtf)
					throw new InvalidUtfSequence(this);
					
				charAccepted = advanceState(c);
			}
			
			if(dfaTable[state].accept)
			{
				foundAcceptState = true;
				lastAcceptState  = state;
				lastAcceptIndex  = srcIndex;
				lastAcceptIndexSize = cSize;
			}
			
			bool shouldAdvance = true;
			if(!charAccepted)
			{
				if(!dfaTable[state].accept && foundAcceptState)
				{
					tok = tok[0..$+1-(srcIndex-lastAcceptIndex)];
					state    = lastAcceptState;
					srcIndex = lastAcceptIndex+lastAcceptIndexSize;
					line     = lineAtIndex(srcIndex);
					lineIndicies = lineIndicies[0..line+1];
				}

				if(dfaTable[state].accept)
				{
					auto symbolIndex = dfaTable[state].acceptSymbolIndex;
					addToken(symbolTable[symbolIndex], tok);
					shouldAdvance = false;
				}
				else
				{
					if(!eof)
						tok ~= source[srcIndex..srcIndex+cSize];//to!(string)(c~""d);
					addToken(lang.errorSymbol, tok);
				}

				state = lang.initialDFAState;
				tok = "";
			}
			
			if(shouldAdvance)
			{
				srcIndex += cSize;

				if(isNewline())
				{
					line++;
					
					//auto codePointSize = source[srcIndex..$].nextCodePointSize();
					//if(srcIndex+1 < source.length /*&& line == lineIndicies.length*/)
					lineIndicies ~= srcIndex + source[srcIndex..$].nextCodePointSize();
					
					assert(line == lineIndicies.length - 1);

					if(commentMode == CommentType.Line)
						commentMode = CommentType.None;
				}
			}
		}
		
		addToken(lang.eofSymbol(), "");
		_errors_cached = false;
		
		if(errorFound)
			throw new LexException(this);
		
		return _tokens;
	}
}
