import std.stdio;

import goldie.all; // Import GoldieLib itself
import commas.all; // Import our commas language

int main(string[] args)
{
	try
	{
		auto parseTree = language_commas.parseFile(args[1]).parseTree;
	}
	catch(ParseException e)
	{
		writeln(e.msg);
		return 1;
	}

	return 0;
}
