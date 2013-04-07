// Goldie: GOLD Engine for D
// Grammar Compiler
// Written in the D programming language.

module goldie.grmc.process;

import std.conv;
import std.path;
import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.all;

// To be mixed into tools.grmc.ast.AST:
template processFuncs()
{
	void process(Token tok)
	{
		if(tok.matches("<Grammar>", "<nl opt>", "<Content>"))
			process(tok.subX[1]);
		
		else if(tok.matches("<Content>", "<Content>", "<Definition>"))
		{
			process(tok.subX[0]);
			process(tok.subX[1]);
		}
		else if(tok.matches("<Content>", "<Definition>"))
			process(tok.subX[0]);
			
		else if(
			tok.matches("<Definition>", "<Parameter>")     ||
			tok.matches("<Definition>", "<Set Decl>")      ||
			tok.matches("<Definition>", "<Terminal Decl>") ||
			tok.matches("<Definition>", "<Rule Decl>")
		)
		{
			process(tok.subX[0]);
		}
			
		else if(tok.matches("<Parameter>", "ParameterName", "<nl opt>", "=", "<Parameter Body>", "<nl>"))
		{
			auto name = Insensitive(processString(tok.subX[0]));
			auto value = processString(tok.subX[3]);
			//mixin(traceVal!("name", "value"));
			switch(name.toString().toLower())
			{
			case "name":
				lang.name = value;
				break;

			case "version":
				lang.ver = value;
				break;

			case "author":
				lang.author = value;
				break;

			case "about":
				lang.about = value;
				break;

			case "start symbol":
				auto cleanValue = value.strip();
				if(cleanValue.length >= 2 && cleanValue[0] == '<' && cleanValue[$-1] == '>')
				{
					cleanValue = cleanValue[1..$-1];
					validateName(tok.subX[3], cleanValue);
				}
					
				params[name] = cleanValue;
				break;

			case "case sensitive":
				switch(value.strip().toLower())
				{
				case "true":
					lang.caseSensitive = true;
					break;
				case "false":
					lang.caseSensitive = false;
					break;
				default:
					error(
						tok,
						"Invalid value for \"%s\" parameter: '%s'\nMust be true or false"
							.format(name, value.strip())
					);
				}
				break;

			case "character mapping":
				switch(value.strip().toLower())
				{
				case "unicode":
					useMappingANSI = false;
					break;
				case "windows-1252":
					useMappingANSI = true;
					break;
				case "ansi":
					useMappingANSI = true;
					break;
				default:
					error(
						tok,
						"Invalid value for \"%s\" parameter: '%s'\nMust be Unicode, Windows-1252, or ANSI (same as Windows-1252)"
							.format(name, value.strip())
					);
				}
				break;

			default:
				params[name] = value;
				warning(tok, "Unrecognized parameter: '%s'".format(name));
				break;
			}
		}

		else if(tok.matches("<Set Decl>", "SetName", "<nl opt>", "=", "<Set Exp>", "<nl>"))
		{
			auto name = Insensitive(processString(tok.subX[0]));

			auto charSet = ASTCharSet();
			processCharSet(tok.subX[3], charSet);
			
			if(name in charSets)
				warning(tok, text("Set redefined: '{", name, "}'"));
			else
				charSets[name] = charSet;
		}

		else if(tok.matches("<Terminal Decl>", "<Terminal Name>", "<nl opt>", "=", "<Reg Exp>", "<nl>"))
		{
			auto name = Insensitive(processString(tok.subX[0]));
			
			auto sym = ASTTerminal(true);
			
			bool duplicate = false;
			if(name in terminals)
			{
				duplicate = true;
				auto cmp = Insensitive("Whitespace");
				if(name == cmp && usingDefaultWhitespace)
				{
					duplicate = false;
					usingDefaultWhitespace = false;
				}
				
				if(duplicate)
					warning(tok, "Duplicate definition for the terminal '%s'".format(name));
			}
			
			if(!duplicate)
			{
				auto cmp1 = Insensitive("Whitespace");
				auto cmp2 = Insensitive("Comment Line");
				auto cmp3 = Insensitive("Comment Start");
				auto cmp4 = Insensitive("Comment End");

				if(name == cmp1)
					sym.type = SymbolType.Whitespace;
				else if(name == cmp2)
					sym.type = SymbolType.CommentLine;
				else if(name == cmp3)
					sym.type = SymbolType.CommentStart;
				else if(name == cmp4)
					sym.type = SymbolType.CommentEnd;

				sym.regex = new ASTRegex();
				processRegex(tok.subX[3], sym.regex);
		
				terminals[name] = sym;
			}
		}

		else if(tok.matches("<Rule Decl>", "Nonterminal", "<nl opt>", "::=", "<Handles>", "<nl>"))
		{
			auto name = Insensitive(processString(tok.subX[0]));
			
			if(name in nonterminals)
				warning(tok, text("Rule was already defined for '<", name, ">'"));
			else
				nonterminals[name] = ASTNonTerminal();
			
			nonterminals[name].rules ~= ASTRuleRHS(); // Init with a starting rule
			if(goldCompat)
			{
				nonterminals[name].rules[$-1].id = nextRuleId;
				nextRuleId++;
			}
			processNonTerminal(tok.subX[3], nonterminals[name]);
		}

		else
			throw new Exception(to!string(__LINE__)~" Unhandled token: %s".format(tok.name));
	}

	void validateName(Token tok, string name)
	{
		auto stripName = name.strip();
		if(name != stripName)
		{
			warning(tok, "Names with leading/trailing whitespace can lead to bugs: %s".format(tok.toString()));
		}
		
		auto whiteChars = defaultCharSets[Insensitive("All Whitespace")].data;
		foreach(dchar ch; stripName)
		if(ch != ' ' && whiteChars.contains(ch))
			warning(tok, "Names with any whitespace other than the space character can lead to bugs: %s".format(tok.toString()));

		if(stripName.contains("  "))
			warning(tok, "Names with consecutive spaces can lead to bugs: %s".format(tok.toString()));
	}
	
	string processString(Token tok)
	{
		if(
			tok.name == "ParameterName" ||
			tok.name == "Nonterminal" ||
			tok.name == "SetName"
		)
		{
			auto str = tok.toString()[1..$-1];
			if(tok.name != "SetLiteral")
				validateName(tok, str);
			return str;
		}
		
		if(tok.name == "SetLiteral")
		{
			auto str = tok.toString()[1..$-1];
			dstring newStr;
			bool inQuote=false;
			bool justOpenedQuote=false;
			foreach(dchar ch; str)
			{
				if(ch == '\'')
				{
					if(inQuote)
					{
						if(justOpenedQuote)
							newStr ~= '\'';

						inQuote         = false;
						justOpenedQuote = false;
					}
					else
					{
						inQuote         = true;
						justOpenedQuote = true;
					}
				}
				else
				{
					newStr ~= ch;
					justOpenedQuote = false;
				}
			}
			return to!string(newStr);
		}
		
		if(tok.name == "Terminal")
		{
			auto str = tok.toString();
			
			if(str.length > 2 && str[0] == '\'' && str[$-1] == '\'')
			{
				if(!contains(str[1..$-1], '\''))
					str = str[1..$-1];
			}
			
			if(str == "''")
				str = "'";
			
			validateName(tok, str);
			return str;
		}

		if(tok.matches("<Terminal Name>", "<Terminal Name>", "Terminal"))
			return processString(tok.subX[0]) ~ " " ~ processString(tok.subX[1]);
		
		if(tok.matches("<Terminal Name>", "Terminal"))
			return processString(tok.subX[0]);
		
		if(tok.matches("<Parameter Body>", "<Parameter Body>", "<nl opt>", "|", "<Parameter Items>"))
			return processString(tok.subX[0]) ~ " " ~ processString(tok.subX[3]);
		
		if(tok.matches("<Parameter Body>", "<Parameter Items>"))
			return processString(tok.subX[0]);
		
		if(tok.matches("<Parameter Items>", "<Parameter Items>", "<Parameter Item>"))
			return processString(tok.subX[0]) ~ " " ~ processString(tok.subX[1]);

		if(tok.matches("<Parameter Items>", "<Parameter Item>"))
			return processString(tok.subX[0]);

		if(tok.name == "<Parameter Item>")
			return processString(tok.subX[0]);

		throw new Exception(to!string(__LINE__)~" Unhandled token: %s".format(tok.name));
	}

	void processCharSet(Token tok, ref ASTCharSet charSet)
	{
		if(tok.matches("<Set Exp>", "<Set Exp>", "<nl opt>", "+", "<Set Item>"))
		{
			processCharSet(tok.subX[0], charSet);
			processCharSet(tok.subX[3], charSet, ASTCharSetMode.Plus);
		}
		else if(tok.matches("<Set Exp>", "<Set Exp>", "<nl opt>", "-", "<Set Item>"))
		{
			processCharSet(tok.subX[0], charSet);
			processCharSet(tok.subX[3], charSet, ASTCharSetMode.Minus);
		}
		else if(tok.matches("<Set Exp>", "<Set Item>"))
		{
			processCharSet(tok, charSet, ASTCharSetMode.Plus);
		}
		else
		{
			throw new Exception(to!string(__LINE__)~" Unhandled token: %s".format(tok.name));
		}
	}

	void processCharSet(Token tok, ref ASTCharSet charSet, ASTCharSetMode mode)
	{
		if(tok.matches("<Set Exp>", "<Set Item>"))
		{
			processCharSet(tok.subX[0], charSet, mode);
		}
		else if(tok.matches("<Set Item>", "SetLiteral"))
		{
			auto chars = processString(tok.subX[0]);
			charSet.combine(to!dstring(chars), mode);
		}
		else if(tok.matches("<Set Item>", "SetName"))
		{
			auto setName = Insensitive(processString(tok.subX[0]));
			charSet.combine(charSetNameToData(setName), mode);
		}
		else
			throw new Exception(to!string(__LINE__)~" Unhandled token: %s".format(tok.name));
	}
	
	void processNonTerminal(Token tok, ref ASTNonTerminal sym)
	{
		if(tok.matches("<Handles>", "<Handles>", "<nl opt>", "|", "<Handle>"))
		{
			processNonTerminal(tok.subX[0], sym);
			sym.rules ~= ASTRuleRHS();
			if(goldCompat)
			{
				sym.rules[$-1].id = nextRuleId;
				nextRuleId++;
			}
			processNonTerminal(tok.subX[3], sym);
		}
		else if(tok.matches("<Handles>", "<Handle>"))
		{
			processNonTerminal(tok.subX[0], sym);
		}
		
		else if(tok.matches("<Handle>", "<Handle>", "<Symbol>"))
		{
			processNonTerminal(tok.subX[0], sym);
			processNonTerminal(tok.subX[1], sym);
		}
		else if(tok.matches("<Handle>", null))
		{
			sym.rules[$-1].symbols ~= ASTRuleSubSymbol(Insensitive(null), SymbolType.Terminal);
		}
		
		else if(tok.matches("<Symbol>", "Terminal"))
		{
			auto termName = Insensitive(processString(tok.subX[0]));
			
			if(termName !in terminals)
			{
				terminals[termName] = ASTTerminal(false, SymbolType.Terminal);
				
				auto regex = new ASTRegex();
				regex.seqs[0].items[0].termLiteral = termName.toString();
				regex.seqs[0].items[0].kleene = Kleene.One;
				terminals[termName].regex = regex;
			}
			
			auto cmp1 = Insensitive("Comment Line");
			auto cmp2 = Insensitive("Comment Start");
			auto cmp3 = Insensitive("Comment End");
			if(
				termName == cmp1  || 
				termName == cmp2  || 
				termName == cmp3  || 
				termName in terminals && (
					terminals[termName].type == SymbolType.Whitespace   || 
					terminals[termName].type == SymbolType.CommentLine  || 
					terminals[termName].type == SymbolType.CommentStart || 
					terminals[termName].type == SymbolType.CommentEnd
				)
			)
			{
				error(tok, "Whitespace and comment symbols are not allowed in rules");
			}
			
			
			sym.rules[$-1].symbols ~=
				ASTRuleSubSymbol(
					termName,
					SymbolType.Terminal
				);
		}
		else if(tok.matches("<Symbol>", "Nonterminal"))
		{
			sym.rules[$-1].symbols ~=
				ASTRuleSubSymbol(
					Insensitive(processString(tok.subX[0])),
					SymbolType.NonTerminal
				);
		}
		
		else
			throw new Exception(to!string(__LINE__)~" Unhandled token: %s".format(tok.name));
	}
	
	void processRegex(Token tok, ASTRegex regex)
	{
		if(tok.matches("<Reg Exp>", "<Reg Exp>", "<nl opt>", "|", "<Reg Exp Seq>"))
		{
			processRegex(tok.subX[0], regex);
			regex.seqs ~= new ASTRegexSeq();
			processRegex(tok.subX[3], regex);
		}
		else if(tok.matches("<Reg Exp>", "<Reg Exp Seq>"))
		{
			processRegex(tok.subX[0], regex);
		}
		
		else if(tok.matches("<Reg Exp Seq>", "<Reg Exp Seq>", "<Reg Exp Item>"))
		{
			processRegex(tok.subX[0], regex);
			regex.seqs[$-1].items ~= new ASTRegexItem();
			processRegex(tok.subX[1], regex);
		}
		else if(tok.matches("<Reg Exp Seq>", "<Reg Exp Item>"))
		{
			processRegex(tok.subX[0], regex);
		}
		
		else if(tok.matches("<Reg Exp Item>", "SetLiteral", "<Kleene Opt>"))
		{
			regex.seqs[$-1].items[$-1].charSetLiteral = processString(tok.subX[0]);
			regex.seqs[$-1].items[$-1].kleene = processKleene(tok.subX[1]);
		}
		else if(tok.matches("<Reg Exp Item>", "SetName", "<Kleene Opt>"))
		{
			regex.seqs[$-1].items[$-1].charSetName = processString(tok.subX[0]);
			regex.seqs[$-1].items[$-1].kleene = processKleene(tok.subX[1]);
		}
		else if(tok.matches("<Reg Exp Item>", "Terminal", "<Kleene Opt>"))
		{
			regex.seqs[$-1].items[$-1].termLiteral = processString(tok.subX[0]);
			regex.seqs[$-1].items[$-1].kleene = processKleene(tok.subX[1]);
		}
		else if(tok.matches("<Reg Exp Item>", "(", "<Reg Exp 2>", ")", "<Kleene Opt>"))
		{
			auto subRegex = new ASTRegex();
			processRegex(tok.subX[1], subRegex);
			regex.seqs[$-1].items[$-1].regex = subRegex;
			regex.seqs[$-1].items[$-1].kleene = processKleene(tok.subX[3]);
		}

		else if(tok.matches("<Reg Exp 2>", "<Reg Exp 2>", "|", "<Reg Exp Seq>"))
		{
			processRegex(tok.subX[0], regex);
			regex.seqs ~= new ASTRegexSeq();
			processRegex(tok.subX[2], regex);
		}
		else if(tok.matches("<Reg Exp 2>", "<Reg Exp Seq>"))
		{
			processRegex(tok.subX[0], regex);
		}
		
		else
			throw new Exception(to!string(__LINE__)~" Unhandled token: %s".format(tok.name));
	}
	
	Kleene processKleene(Token tok)
	{
		if(tok.matches("<Kleene Opt>", "+"))
			return Kleene.OneOrMore;

		if(tok.matches("<Kleene Opt>", "?"))
			return Kleene.ZeroOrOne;

		if(tok.matches("<Kleene Opt>", "*"))
			return Kleene.ZeroOrMore;

		if(tok.matches("<Kleene Opt>", null))
			return Kleene.One;
		
		throw new Exception(to!string(__LINE__)~" Unhandled token: %s".format(tok.name));
	}
}