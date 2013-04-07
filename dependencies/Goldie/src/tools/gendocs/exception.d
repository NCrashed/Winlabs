// Goldie: GOLD Engine for D
// Tools: Generate Documentation
// Written in the D programming language.

module tools.gendocs.exception;

import semitwist.cmd.all;
import goldie.all;

import tools.gendocs.asttag;

class SemanticException : Exception
{
	Token tok;
	AST_Tag ast;
	
	string file;
	ptrdiff_t line;
	ptrdiff_t srcIndexStart;
	ptrdiff_t srcIndexEnd;
	
	this(string msg)
	{
		super(msg);
	}
	
	this(Token tok, string msg)
	{
		this.tok = tok;
		mixin(initMemberFrom("tok", "file", "line", "srcIndexStart", "srcIndexEnd"));
		
		super(genMsg(msg));
	}
	
	this(AST_Tag ast, string msg)
	{
		this.ast = ast;
		mixin(initMemberFrom("ast", "file", "line", "srcIndexStart", "srcIndexEnd"));
		
		super(genMsg(msg));
	}
	
	private string genMsg(string msg)
	{
		return "%s(%s): %s".format(file, line+1, msg);
	}
}

class WrongTokenTypeException : SemanticException
{
	this(Token tok, string msg="")
	{
		super(tok, "Internal Error: Wrong type: " ~ tok.name ~ (msg==""?"":": "~msg));
	}
}
