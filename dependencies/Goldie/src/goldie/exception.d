// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

module goldie.exception;

import std.array;
import std.conv;
import std.stdio;
import std.string;

import semitwist.util.all;

import goldie.lexer;
import goldie.parser;
import goldie.token;

//TODO: An easy way for user code to create consistent semantic/etc exceptions
//TODO: Make numErrors a member of this, and display "1 Error(s)" on parse-phase errors.
class ParseException : Exception
{
	Parser parser;
	Lexer lexer;
	
	this(string msg)
	{
		this.parser = null;
		this.lexer = null;
		super(msg);
	}

	this(Parser parser, string msg)
	{
		this.parser = parser;
		this.lexer = parser? parser.lexer : null;
		super(msg);
	}

	protected this(Lexer lexer, string msg="")
	{
		this.parser = null;
		this.lexer = lexer;
		string reductionPred(string str, LexError error)
		{
			return str ~ error.toString() ~ "\n";
		}
		string str;
		if(msg == "")
		{
			str = reduceTo(lexer.errors, &reductionPred);
			str ~= "%s Error(s)".format(lexer.errors.length);
		}
		else
		{
			if(lexer)
				str ~= "%s(%s:%s): %s".format(
					lexer.filename,
					lexer.line+1,
					lexer.srcIndex-lexer.lineIndicies[lexer.lineAtIndex(lexer.srcIndex)]+1,
					msg
				);
			else
				str ~= msg;
		}
		super(str);
	}
}

struct LexError
{
	string file;
	ptrdiff_t line;
	ptrdiff_t pos;
	string content;
	
	string toString()
	{
		return "%s(%s:%s): Syntax Error: '%s'".format(file, line+1, pos+1, printableContent);
	}
	
	mixin(getterLazy!(string, "printableContent", `
		return content.stripNonPrintable().replace("\r"," ").replace("\n"," ");
	`));
}

class LexException : ParseException
{
	this(Lexer lexer, string msg="")
	{
		super(lexer, msg);
	}
}

class InvalidUtfSequence : LexException
{
	this(Lexer lexer)
	{
		super(lexer, "Invalid UTF Sequence");
	}
}

class InternalException : ParseException
{
	this(string msg)
	{
		super("Internal Goldie Error: " ~ msg);
	}

	this(Parser parser, string msg)
	{
		super(parser, "Internal Goldie Error: " ~ msg);
	}
}

class UnexpectedTokenException : ParseException
{
	this(Parser parser)
	{
		auto token = parser.currTok;
		super(
			parser,
			"%s(%s%s): Unexpected %s: '%s'".format(
				token.file, token.line+1,
				parser.lexer?
					":%s".format((token.srcIndexStart-parser.lexer.lineIndicies[token.line])+1) :
					"",
				token.name, token.toString(TokenToStringMode.Full)
			)
		);
	}
}

class UnexpectedEofException : ParseException
{
	this(Parser parser=null)
	{
		if(parser is null)
			super(parser, "Unexpected EOF");
		else
		{
			super(
				parser,
				"%s(%s%s): Unexpected EOF".format(
					parser.currTok? parser.currTok.file : parser.filename,
					parser.currTok? to!(string)(parser.currTok.line+1) : "",
					(parser.currTok && parser.lexer)?
						":%s".format((parser.currTok.srcIndexStart-parser.lexer.lineIndicies[parser.currTok.line])+1) :
						""
				)
			);
		}
	}
}

class LanguageLoadException : StdioException
{
	this(string msg="", string lang="", Exception next=null)
	{
		string fullMsg = "Language '%s'".format(lang);
		if(msg != "")
			fullMsg ~= ": " ~ msg;

		super(fullMsg);

		this.next = next;
	}
}

class LanguageNotFoundException : LanguageLoadException
{
	this(string lang, Exception next=null)
	{
		super("Not found", lang);
	}
}

class IllegalArgumentException : Exception
{
	this(string msg)
	{
		super("Illegal Argument: "~msg);
	}
}
