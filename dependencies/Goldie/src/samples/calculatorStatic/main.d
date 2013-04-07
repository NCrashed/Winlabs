// Goldie: GOLD Engine for D
// Samples: Static-Language Calculator
// Written in the D programming language.

/++
A simple arithmetic calculator utilizing a calculator grammar
compiled by GOLD.

Uses a statically loaded language and static-style tokens.

To re-generate the static language used by this app, run
the following command from the main Goldie directory:
	makeBuiltinStaticLangs
+/

module samples.calculatorStatic.main;

import std.conv;
import std.stdio;
import std.string;

import semitwist.cmd.plain;

import goldie.all;

import samples.calculatorStatic.calc.all;

real calculate(Token_calc!"Number" tok)
{
	return to!real(tok.toString());
}

real calculate(Token_calc!"<Add Exp>" tok)
{
	if(auto t = cast(Token_calc!("<Add Exp>", "<Mult Exp>"))tok)
		return calculate(t.sub!0);
	
	if(auto t = cast(Token_calc!("<Add Exp>", "<Add Exp>", "+", "<Mult Exp>"))tok)
		return calculate(t.sub!0) + calculate(t.sub!2);
	
	if(auto t = cast(Token_calc!("<Add Exp>", "<Add Exp>", "-", "<Mult Exp>"))tok)
		return calculate(t.sub!0) - calculate(t.sub!2);
	
	throw new Exception("Unhandled token: %s".format(tok.name));
}

real calculate(Token_calc!"<Mult Exp>" tok)
{
	if(auto t = cast(Token_calc!("<Mult Exp>", "<Negate Exp>"))tok)
		return calculate(t.sub!0);

	if(auto t = cast(Token_calc!("<Mult Exp>", "<Mult Exp>", "*", "<Negate Exp>"))tok)
		return calculate(t.sub!0) * calculate(t.sub!2);

	if(auto t = cast(Token_calc!("<Mult Exp>", "<Mult Exp>", "/", "<Negate Exp>"))tok)
		return calculate(t.sub!0) / calculate(t.sub!2);

	throw new Exception("Unhandled token: %s".format(tok.name));
}

real calculate(Token_calc!"<Negate Exp>" tok)
{
	if(auto t = cast(Token_calc!("<Negate Exp>", "<Value>"))tok)
		return calculate(t.sub!0);

	if(auto t = cast(Token_calc!("<Negate Exp>", "-", "<Value>"))tok)
		return -calculate(t.sub!1);

	throw new Exception("Unhandled token: %s".format(tok.name));
}

real calculate(Token_calc!"<Value>" tok)
{
	if(auto t = cast(Token_calc!("<Value>", "Number"))tok)
		return calculate(t.sub!0);

	if(auto t = cast(Token_calc!("<Value>", "(", "<Add Exp>", ")"))tok)
		return calculate(t.sub!1);

	throw new Exception("Unhandled token: %s".format(tok.name));
}

real calculate(Token_calc!() tok)
{
	throw new Exception("Unhandled token: %s".format(tok.name));
}

int main(string[] args)
{
	writeln("Calculator");
	Language_calc lang = language_calc;
	// Note: At this point, the "dynamic" style could be used if desired, as
	//       demonstrated in the "calculatorDynamic" sample. But, since the
	//       language was loaded statically this time, we also have the option
	//       of using the "static" style, which is what this app demonstrates.

	writeln("Enter an arithmetic expression ('exit' to exit)");
	while(true)
	{
		writeln();
		string src = cmd.prompt("calculator>");
		
		if(src.toLower() == "exit")
			break;
			
		try
		{
			auto parseTree = lang.parseCode(src).parseTree;
			real result = calculate(parseTree);
			writefln("%f", result);
		}
		catch(Exception e)
			writeln(e.msg);
	}
	
	return 0;
}
