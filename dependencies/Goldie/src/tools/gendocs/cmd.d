// Goldie: GOLD Engine for D
// Tools: Generate Documentation
// Written in the D programming language.

module tools.gendocs.cmd;

import getopt = std.getopt;
import std.path;
import std.stdio;

import semitwist.cmdlineparser;
import semitwist.util.all;

import goldie.all;
import tools.util;


struct Options
{
	bool help;
	bool saveAST;
	bool quietMode;
	bool trimLinks;
	
	string astDir  = "";
	string outFile = "index.html";
	string outDir  = ".";
	string srcFile = "";

	// Generated
	string srcDir = "";

	// Returns errorlevel program should exit immediately with.
	// If returns -1, everything is OK and program should continue without exiting.
	int process(string[] args)
	{
		auto infoHeader = helpInfoHeader("GenDocs", "2010-2012 Nick Sabalausky");
		auto helpScreen =
			infoHeader ~ "\n\n" ~ `
Generates HTML documentation.

Usage:   goldie-gendocs [options] main-template-file [options]
Example: goldie-gendocs docssrc/docs.tmpl

--help, /?             Displays this help screen
-d, --od <dir>         Output directory (default: ".")
-i, --of <index-name>  Filename of output pages (default: "index.html")
--trimlink             Trim filename from internal links
-q, --quiet            Quiet mode

--ast           Save abstract syntax trees to JSON (for use in JsonViewer)
--astd <dir>    JSON AST output directory (implies --ast) (default: curr dir)
			`.normalize()~"\n";

		if(args.length == 1)
		{
			write(helpScreen);
			return 0;
		}

		getopt.endOfOptions = "";
		try getopt.getopt(
			args,
			getopt.config.caseSensitive,
			"help",      &help,
			"d|od",      &outDir,
			"i|of",      &outFile,
			"trimlink",  &trimLinks,
			"q|quiet",   &quietMode,
			"ast",       &saveAST,
			"astd",      &astDir
		);
		catch(Exception e)
		{
			stderr.writeln(e.msg);
			stderr.writeln(suggestHelpMsg);
			return 1;
		}
		
		if(help || args.contains("/?"))
		{
			write(helpScreen);
			return 0;
		}

		if(args.length < 2)
		{
			stderr.writeln("Must specify a main template file.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		if(args.length > 2)
		{
			stderr.writeln("Can only specify one main template file.");
			stderr.writeln(suggestHelpMsg);
			return 1;
		}

		srcFile = args[1];

		void ensureTrailingSlash(ref string path)
		{
			// UTF-safe because '/' and '\\' are one code-unit
			if(path[$-1] != '/' && path[$-1] != '\\')
				path ~= "/";
		}
		
		if(astDir != "")
		{
			saveAST = true;
			ensureTrailingSlash(astDir);
		}
		
		if(outDir == "")
			outDir = getExecPath()~"../docs/";
		ensureTrailingSlash(outDir);

		if(srcFile == "")
			srcFile = getExecPath()~"../docssrc/Docs.tmpl";
		
		srcDir  = dirName(srcFile);
		srcFile = baseName(srcFile);
		
		return -1; // All ok
	}
}
/+
class CmdArgs
{
	mixin(getter!(bool, "shouldExit"));

	public this(string[] args)
	{
		init();
		shouldExit = !parse(args);
	}
	
	// Direct command-line args
	public bool help;
	public bool detailhelp;
	public bool saveAST=false;
	public bool quietMode=false;
	public bool trimLinks=false;
	
	public string astDir  = "";
	public string outFile = "index.html";
	public string outDir  = ".";
	public string srcFile = "";

	// Generated
	public string srcDir = "";

	// Private ------
	private CmdLineParser cmd;
	
	private void init()
	{
		cmd = new CmdLineParser();
		mixin(defineArg!(cmd, "help",   help,       ArgFlag.Optional, "Displays a help summary and exits" ));
		mixin(defineArg!(cmd, "detail", detailhelp, ArgFlag.Optional, "Displays a detailed help message and exits" ));

		mixin(defineArg!(cmd, "",   srcFile, ArgFlag.Required, "Main template file" ));
		mixin(defineArg!(cmd, "od", outDir,  ArgFlag.Optional, "Output directory" ));
		mixin(defineArg!(cmd, "of", outFile, ArgFlag.Optional, "Filename of output pages" ));
		
		mixin(defineArg!(cmd, "trimlink", trimLinks, ArgFlag.Optional, "Trim filename from internal links" ));

		mixin(defineArg!(cmd, "q",    quietMode, ArgFlag.Optional, "Quiet mode" ));
		mixin(defineArg!(cmd, "ast",  saveAST,   ArgFlag.Optional, "Save abstract syntax trees to JSON (for use in JsonViewer)" ));
		mixin(defineArg!(cmd, "astd", astDir,    ArgFlag.Optional, "JSON AST output directory (implies -ast) (default: curr dir)" ));
	}
	
	enum helpHeader = 
		helpInfoHeader("GenDocs", "2010-2012 Nick Sabalausky") ~
		"\n\n" ~
		"Generates HTML documentation.\n";

	// Returns: Should processing proceed? If false, the program should exit.
	private bool parse(string[] args)
	{
		const string sampleUsageMsg = "Sample Usage: goldie-gendocs docssrc/docs.tmpl\n";
		cmd.parse(args);
		if(detailhelp)
		{
			writeln(helpHeader);
			writeln(sampleUsageMsg);
			write(cmd.getDetailedUsage());
			return false;
		}
		if(!cmd.success || help)
		{
			writeln(helpHeader);
			writeln(sampleUsageMsg);
			write(cmd.getUsage(14));
			if(!help)
			{
				writeln();
				write(cmd.errorMsg);
			}
			return false;
		}

		void ensureTrailingSlash(ref string path)
		{
			// UTF-safe because '/' and '\\' are one code-unit
			if(path[$-1] != '/' && path[$-1] != '\\')
				path ~= "/";
		}
		
		if(astDir != "")
		{
			saveAST = true;
			ensureTrailingSlash(astDir);
		}
		
		if(outDir == "")
			outDir = getExecPath()~"../docs/";
		ensureTrailingSlash(outDir);

		if(srcFile == "")
			srcFile = normalize(getExecPath()~"../docssrc/Docs.tmpl");
		
		srcDir  = dirName(srcFile);
		srcFile = baseName(srcFile);
		
		return true;
	}
}
+/