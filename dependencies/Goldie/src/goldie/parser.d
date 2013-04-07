﻿// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

module /+S:PACKAGE+/goldie/+E:PACKAGE+/.parser;

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

import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.base;
import goldie.exception;
import goldie.lang;
import goldie.lexer;
import goldie.token;

version(Goldie_StaticStyle)
{
	import goldie.parser;
	mixin(`
		import `~_packageName~`.lang;
		import `~_packageName~`.token;
	`);
}

//TODO? Optionally generate recording of steps taken
//TODO: Make parser steppable
/+S:PARSER_INHERIT+/class Parser/+E:PARSER_INHERIT+/
{
	version(Goldie_DynamicStyle)
	{
		int[] rulesUsed;
		Stack!Token tokenStack;
		Stack!int   stateStack;
		
		Token parseTreeX;
		Lexer lexer;
		Language lang;
		string filename;
		
		Token currTok;

		int tokIndex;
		int state;

		protected LALRState[] lalrTable;
		protected Rule[]      ruleTable;
		protected Symbol[]    symbolTable;
		protected void getTables(Language lang)
		{
			lalrTable   = lang.lalrTable;
			ruleTable   = lang.ruleTable;
			symbolTable = lang.symbolTable;
		}
	}

	version(Goldie_StaticStyle)
		/+P:TOKEN_CLASSNAME_TOPNODE+/DUMMY parseTree;
	
	/+P:OVERRIDE+/ Token process(Token[] tokens, Language lang, string filename="", Lexer lexer=null)
	{
		tokenStack = new Stack!Token();
		stateStack = new Stack!int();
		rulesUsed.length = 0;
		if(!__ctfe)
			rulesUsed.reserve(1024);
		parseTreeX = null;
		currTok = null;
		this.lexer = lexer;
		this.lang = lang;
		this.filename = filename;
		
		tokIndex=0;
		state=lang.initialLALRState;

		bool done=false;
		
		getTables(lang);
		
		Token getPendingToken()
		{
			Token tok;
			bool inComment=false;
			bool lineComment;
			do
			{
				if(tokIndex >= tokens.length)
					throw new UnexpectedEofException(this);

				tok = tokens[tokIndex];
				currTok = tok;
				tokIndex++;
				
				// Handle comments
				if(!inComment)
				{
					switch(tok.type)
					{
					case SymbolType.CommentLine:
						inComment = true;
						lineComment = true;
						break;
					case SymbolType.CommentStart:
						inComment = true;
						lineComment = false;
						break;
					default:
						break;
					}
				}
				else
				{
					if(lineComment)
					{
						auto tokContent = tok.toString(TokenToStringMode.Full);
						if(contains(tokContent, "\n"[0]) || contains(tokContent, "\r"[0]))
							inComment = false;
					}
					else
					{
						if(tok.type == SymbolType.CommentEnd)
							inComment = false;
					}
				}
			} while(inComment || // End of do-while
			         (
				         tok.type != SymbolType.Terminal &&
			             tok.type != SymbolType.EOF
			         )
			     );
				 
			tokIndex--;
			return tok;
		}

		void shift()
		{
			tokenStack ~= getPendingToken();
			stateStack ~= state;
			tokIndex++;
		}
		
		LALRAction chosenAction;
		int chosenActionId;
		bool actionFound;

		void lookupAction(Token tok)
		{
			actionFound=false;
			auto tokId = tok.symbol.id;
			foreach(int id, LALRAction action; lalrTable[state].actions)
			if(tokId == action.symbolId)
			{
				chosenAction = action;
				chosenActionId = id;
				actionFound = true;
				break;
			}
			//mixin(traceVal!("tok", "tok.id", "actionFound", "chosenActionId", "chosenAction"));
			//mixin(traceVal!("actionFound", "chosenAction.type"));
		}
		
		void displayStack()
		{
			foreach(Token tok; tokenStack)
			{
				writefln(
					"    %s(%s): %-25s '%s'",
					tok.file, tok.line+1,
					tok.fullName ~ ":",
					tok.toString(TokenToStringMode.Full)
				);
			}
		}
		
		while(!done)
		{
			auto tok = getPendingToken();
			lookupAction(tok);
			
			if(actionFound)
			{
				switch(chosenAction.type)
				{
				case LALRAction.Type.Shift:
					shift();
					state = chosenAction.target;
					//mixin(traceVal!("chosenActionId"));
					//writefln(`Shift:  %-10s new state: %s`,
					//         `"`~tok.toStringRaw()~`"`, state);
					//displayStack();
					break;

				case LALRAction.Type.Reduce:
					auto rule = ruleTable[chosenAction.target];
					auto reductionSize = rule.subSymbolIndicies.length;
					if(tokenStack.length < reductionSize)
						throw new InternalException(
							this, 
							"Tried to reduce more tokens than exist on the stack. Have %s, need %s, rule #%s"
								.format(tokenStack.length, reductionSize, chosenAction.target)
						);
					rulesUsed ~= chosenAction.target;
					
					// Perform Reduction
					Token[] reducedTokens;
					if(reductionSize > 0)
					{
						auto reductionStart = tokenStack.length - reductionSize;
						reducedTokens = tokenStack[reductionStart..tokenStack.length].dup;
						tokenStack.pop(reductionSize);
						state = stateStack[reductionStart];
						stateStack.pop(reductionSize);
					}

					Token reducedToken;
					
					version(Goldie_DynamicStyle)
					{
						reducedToken = new Token
							(symbolTable[rule.symbolIndex], reducedTokens, lang, chosenAction.target);
					}
					else
					{
						/+S:REDUCE:STORE+/
							reducedToken = new /+P:REDUCE:TOKEN_CLASSNAME+/DUMMY(reducedTokens, lang);
						/+E:REDUCE:STORE+/
						/+P:REDUCE+/
					}
					
					tokenStack ~= reducedToken;
					stateStack ~= state;
					
					// Ensure reduced tokens symbols match the rule's right-side
					if(reducedTokens.length != reductionSize)
						throw new InternalException(
							this,
							"Reduced an incorrent number of tokens. Expected %s, Actual %s"
								.format(reductionSize, reducedTokens.length)
						);
						
					foreach(int i, Token t; reducedTokens)
					{
						if(t.symbol.id != rule.subSymbolIndicies[i])
							throw new InternalException(
								this,
								`Reduced token #%s does not match rule. Expected "%s", Actual "%s"`
									.format(i, symbolTable[rule.subSymbolIndicies[i]].name, t.name)
							);
					}
					//mixin(traceVal!("chosenActionId"));
					//writef(`Reduce: %-15s (next: "%s") new state: %s`,
					//       `"`~reducedToken.name~`"`, tok.toStringRaw(), state);
					
					// Find and perform goto
					lookupAction(reducedToken);
					if(!actionFound)
						throw new ParseException(this, "Couldn't find appropriate goto after reduction.");
					if(chosenAction.type != LALRAction.Type.Goto)
						throw new InternalException(
							this,
							"After reduction, found action type #%s instead of goto."
								.format(chosenAction.type)
						);
					
					state = chosenAction.target;
					//writefln(`, %s`, state);
					//displayStack();
					break;

				case LALRAction.Type.Goto:
/*					
					state = chosenAction.target;
					writefln(`Goto: "%s", state -> %s`,
					         tok.name, state);
*/
					throw new InternalException(this, "Unexpected Goto");

				case LALRAction.Type.Accept:
					if(tokIndex < tokens.length-1)
						throw new InternalException(
							this,
							"Extra tokens exist beyond end of parsing. Current token: #%s of %s"
								.format(tokIndex, tokens.length)
						);
					done = true;
					//Stdout.formatln(`Accept!`);
					break;

				default:
					throw new InternalException(
						this,
						"Unknown action type (#%s) found when parsing. LALR state #%s"
							.format(chosenAction.type, state)
					);
				}
			}
			else
			{
				throw new UnexpectedTokenException(this);
			}
			
			if(tokenStack.length != stateStack.length)
				throw new InternalException(
					this,
					"tokenStack[%s] and stateStack[%s] sizes out of sync."
						.format(tokenStack.length, stateStack.length)
				);
		}
		
		if(tokenStack.length == 1)
		{
			if(!tokenStack[0])
				throw new InternalException("At end of parsing, parse tree root is null");

			if(tokenStack[0].symbol.id != lang.startSymbolIndex)
			{
				throw new InternalException(
					"At end of parsing, parse tree root is wrong symbol: '%s', expected '%s'"
						.format(
							symbolTable[tokenStack[0].symbol.id],
							symbolTable[lang.startSymbolIndex]
						)
				);
			}
			parseTreeX = tokenStack[0];
			version(Goldie_StaticStyle)
			{
				parseTree = cast(typeof(parseTree))parseTreeX;
			}
		}
		else
			throw new InternalException("At end of parsing, length of token stack is %s, expected 1.".format(tokenStack.length));

		return parseTreeX;
	}
}
