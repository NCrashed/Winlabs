// Goldie: GOLD Engine for D
// Samples: Dynamic-Language Calculator
// Written in the D programming language.

/++
A simple arithmetic calculator utilizing a calculator grammar
compiled by GOLD.

Uses a dynamically loaded language and dynamic-style tokens.
+/

module samples.calculatorDynamic.main;

import std.conv;
import std.path;
import std.stdio;
import std.string;

import semitwist.util.all : getExecPath;
import semitwist.cmd.plain;

import goldie.all;

real calculate(Token tok)
{
	if(tok.matches("Number"))
		return to!(real)(tok.toString());
		

	else if(tok.matches("<Add Exp>", "<Mult Exp>"))
		return calculate(tok[0]);

	else if(tok.matches("<Add Exp>", "<Add Exp>", "+", "<Mult Exp>"))
		return calculate(tok[0]) + calculate(tok[2]);

	else if(tok.matches("<Add Exp>", "<Add Exp>", "-", "<Mult Exp>"))
		return calculate(tok[0]) - calculate(tok[2]);


	else if(tok.matches("<Mult Exp>", "<Negate Exp>"))
		return calculate(tok[0]);
			
	else if(tok.matches("<Mult Exp>", "<Mult Exp>", "*", "<Negate Exp>"))
		return calculate(tok[0]) * calculate(tok[2]);
		
	else if(tok.matches("<Mult Exp>", "<Mult Exp>", "/", "<Negate Exp>"))
		return calculate(tok[0]) / calculate(tok[2]);
		
	
	else if(tok.matches("<Negate Exp>", "<Value>"))
		return calculate(tok[0]);

	else if(tok.matches("<Negate Exp>", "-", "<Value>"))
		return -calculate(tok[1]);
	
	
	else if(tok.matches("<Value>", "Number"))
		return calculate(tok[0]);

	else if(tok.matches("<Value>", "(", "<Add Exp>", ")"))
		return calculate(tok[1]);

		
	else
		throw new Exception("Unhandled token: %s".format(tok.name));
}

int main(string[] args)
{
	writeln("Calculator");
	
	write("Loading language...");
	stdout.flush();
	Language lang = Language.load(getExecPath()~"../lang/calc.cgt");
	writeln("done!");

	writeln("Enter an arithmetic expression ('exit' to exit)");
	while(true)
	{
		writeln();
		string src = cmd.prompt("calculator>");
		
		if(src.toLower() == "exit")
			break;
			
		try
		{
			Token parseTree = lang.parseCodeX(src).parseTreeX;
			real result = calculate(parseTree);
			writefln("%f", result);
		}
		catch(Exception e)
			writeln(e.msg);
	}
	
	return 0;
}
