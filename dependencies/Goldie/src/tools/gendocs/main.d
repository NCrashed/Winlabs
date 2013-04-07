// Goldie: GOLD Engine for D
// Tools: Generate Documentation
// Written in the D programming language.
//
// Generates documentation.

module tools.gendocs.main;

import std.uni;

import semitwist.cmd.all;
import goldie.all;

import tools.gendocs.asttag;
import tools.gendocs.cmd;
import tools.gendocs.exception;
import tools.gendocs.page;
import tools.util;

static if(__traits(compiles, std.ascii.digits))
{
	static import std.ascii;
	private alias std.ascii.digits digits;
	private alias std.ascii.letters letters;
}
else
	import std.string;

//TODO: See about allowing subtags in all types of statements.
//TODO: Create [$apiMetaParamHead|metaParamName|...$] (highlights metaparams).
//TODO: Highlight template param names (like in "staticSub!(int index)()")
//TODO: Fix: No file/line reported when [$file|...$] can't find the file.
//TODO: Fix highlighting for [$apiHead| bool compileGrammarGoldCompatibility = false $]
//TODO: Fix highlighting for [$apiHead|[: Token_{languageName}!({symbol}) sub(int index)() :]$]

int main(string[] args)
{
	Options cmdArgs;
	int errLevel = cmdArgs.process(args);
	if(errLevel != -1)
		return errLevel;

	Page.pageFilename = cmdArgs.outFile;
	Page.srcDir       = cmdArgs.srcDir;
	Page.astOutDir    = cmdArgs.astDir;
	Page.trimLinks    = cmdArgs.trimLinks;
	
	if(Page.srcDir.length > 0 && Page.srcDir[$-1] != '/' && Page.srcDir[$-1] != '\\')
		Page.srcDir ~= dirSeparator;
	
	if(Page.astOutDir.length > 0 && Page.astOutDir[$-1] != '/' && Page.astOutDir[$-1] != '\\')
		Page.astOutDir ~= dirSeparator;
	
	if(!cmdArgs.quietMode)
		cmd.echo("Loading templates...");

	Page.vars = 
	[
		""[]: ""[]
	];

	string pageMap(Page p, Page mapRoot)
	{
		string str = "";
		foreach(Page subPage; mapRoot.sub)
		{
			str ~= "<li>";
			str ~= p.linkTo(subPage, "pagemenu-link");
			str ~= pageMap(p, subPage);
			str ~= "</li>\n";
		}
		if(str != "")
			str = "\n<ul class=\"pagemenu-link\">\n"~str~"</ul>\n";
		return str;
	}

	string siteMapRooted(Page p, Page rootPage=null)
	{
		if(rootPage is null)
		{
			rootPage = p;
			while(rootPage.parent !is null)
				rootPage = rootPage.parent;
		}
		
		return
			"<div class=\"pagemenu-link\">" ~
			p.linkTo(rootPage, "pagemenu-link") ~
			"</div>" ~
			pageMap(p, rootPage);
	}

	void ensureValidPage(string name, AST_Tag tag)
	{
		if(!(name in Page.pageLookup))
		{
			if(name in Page.ambiguousPageNames)
				throw new SemanticException(tag, "Ambiguous Page: '%s'".format(name));
			else
				throw new SemanticException(tag, "Unknown Page: '%s'".format(name));
		}
	}

	void ensureValidType(string name, AST_Tag tag)
	{
		if(!(name in Page.typeLookup))
			throw new SemanticException(tag, "Unknown Type: '%s'".format(name));
	}

	//Page.dgVars = 
	//[
	Page.dgVars["title"    ] = (Page p, AST_Tag tag, string[] params) { return p.title;     };
	Page.dgVars["name"     ] = (Page p, AST_Tag tag, string[] params) { return p.name;      };
	Page.dgVars["desc"     ] = (Page p, AST_Tag tag, string[] params) { return p.desc;      };
	Page.dgVars["fullName" ] = (Page p, AST_Tag tag, string[] params) { return p.fullName;  };
	Page.dgVars["urlToBase"] = (Page p, AST_Tag tag, string[] params) { return p.urlToBase; };
	Page.dgVars["urlToRoot"] = (Page p, AST_Tag tag, string[] params) { return p.urlToRoot; };
	
	Page.dgVars["breadcrumbs"] = (Page p, AST_Tag tag, string[] params)
	{
		string str = "";
		for(auto currPage = p; currPage !is null; currPage = currPage.parent)
		{
			if(str != "")
				str = "&nbsp;-> " ~ str;
				
			str = p.linkTo(currPage, "breadcrumb-link", "", "", true) ~ str;
		}

		return str;
	};
	
	Page.dgVars["pageMenu"] = (Page p, AST_Tag tag, string[] params)
	{
		string str = "";
		foreach(Page subPage; p.sub)
		{
			str ~= "<li>";
			str ~= p.linkTo(subPage, "pagemenu-link");
			if(subPage.desc !is null && subPage.desc != "")
			{
				str ~= " - ";
				str ~= subPage.desc;
			}
			str ~= "</li>";
		}
		str = "<ul>"~str~"</ul>";
		return str;
	};
	
	Page.dgVars["pageMap"] = (Page p, AST_Tag tag, string[] params)
	{
		return pageMap(p, p);
	};

	Page.dgVars["siteMapRooted"] = (Page p, AST_Tag tag, string[] params)
	{
		return siteMapRooted(p);
	};

	Page.dgVars["siteMap"] = (Page p, AST_Tag tag, string[] params)
	{
		Page rootPage = p;
		while(rootPage.parent !is null)
			rootPage = rootPage.parent;

		string str = "";
		foreach(subPage; rootPage.sub)
			str ~= siteMapRooted(p, subPage);
			
		return str;
	};

	Page.dgVars["parentPageLink"] = (Page p, AST_Tag tag, string[] params)
	{
		if(p.parent is null)
			return ""[];
		else
			return p.linkTo(p.parent);
	};

	Page.dgVars["pageTitle"] = (Page p, AST_Tag tag, string[] params)
	{
		ensureValidPage(params[0], tag);
		auto target = Page.pageLookup[params[0]];
		return p.linkTo(target, "page-link");
	};

	Page.dgVars["pageName"] = (Page p, AST_Tag tag, string[] params)
	{
		ensureValidPage(params[0], tag);
		auto target = Page.pageLookup[params[0]];
		return p.linkTo(target, "page-link", target.name);
	};

	Page.dgVars["pageLink"] = (Page p, AST_Tag tag, string[] params)
	{
		auto indexOfHash = params[0].locate('#');
		auto pageName = params[0][0..indexOfHash];
		auto anchor = (indexOfHash != params[0].length)? params[0][indexOfHash+1..$] : "";
		
		auto target = p;
		if(pageName != "")
		{
			ensureValidPage(pageName, tag);
			target = Page.pageLookup[pageName];
		}
		return p.linkTo(target, "page-link", params[1], anchor);
	};
	
	Page.dgVars["typeName"] = (Page p, AST_Tag tag, string[] params)
	{
		ensureValidType(params[0], tag);
		return p.linkToType(params[0], "page-link");
	};
	
	Page.dgVars["typeLink"] = (Page p, AST_Tag tag, string[] params)
	{
		ensureValidType(params[0], tag);
		string label = highlightMetaParams(params[1]);
		return p.linkToType(params[0], "page-link", label);
	};
	
	Page.dgVars["apiHead"] = (Page p, AST_Tag tag, string[] params)
	{
		return highlightAPIHead(p, tag, params);
	};
	//];

	Page.lang = Language.load(defaultLangDir~"tmpl.cgt");
	
	Page page;
	try
		page = new Page(cmdArgs.srcFile);
	catch(Exception e)
	{
		if( cast(ParseException)e || cast(SemanticException)e )
		{
			cmd.echo(e.msg);
			
			if(cmdArgs.saveAST)
			{
				auto p = Page.partialObject;
				while(p.parent !is null)
					p = p.parent;
					
				if(!cmdArgs.quietMode)
					cmd.echo("Saving ASTs to JSON...");

				p.saveJSON();
			}
			
			return 1;
		}
		else
			throw e;
	}

	try
	{
		if(cmdArgs.saveAST)
		{
			if(!cmdArgs.quietMode)
				cmd.echo("Saving ASTs to JSON...");
				
			page.saveJSON();
		}

		chdir(cmdArgs.outDir);

		if(!cmdArgs.quietMode)
			cmd.echo("Generating docs...");

		page.save();
	}
	catch(Exception e)
	{
		if( cast(ParseException)e || cast(SemanticException)e )
		{
			cmd.echo(e.msg);
			return 1;
		}
		else
			throw e;
	}
	
	if(!cmdArgs.quietMode)
		cmd.echo("Done!");

	return 0;
}

private string highlightAPIHead(Page p, AST_Tag tag, string[] params)
{
	// Split on left-parens that aren't preceeded by a '!'
	string[] splitNonBangLeftParen(string inStr)
	{
		string[] ret = [];
		bool prevWasBang=false;
		//size_t i = 0;
		//while(true)
		for(size_t i=0; i<inStr.length; i++)
		{
			//if(i == inStr.length)
			//	break;
				
			if(!prevWasBang && inStr[i] == '(')
			{
				ret ~= inStr[0..i];
				inStr = (i+1 < inStr.length)? inStr[i+1..$] : "";
				i = -1;
				prevWasBang = false;
			}
			else
				prevWasBang = inStr[i] == '!';
			//i++;
		}

		return ret ~ inStr;
	}

	string str = "";
	auto splitLines = params[0].strip().split("\n");
	foreach(string line; splitLines)
	{
		line = line.strip();
		if(line == "")
		{
			str ~= "<br />\n";
			continue;
		}
		
		// Split on left-parens that aren't preceeded by a '!'
		auto splitParens = splitNonBangLeftParen(line);
		
		// Separate member paramaters from the rest
		auto head = splitParens[0];
		splitParens = splitParens[1..$];
		
		// Extract member name
		auto nameStart = head.locatePrior(' ') + 1; // UTF-safe because ' ' is one code-point
		if(nameStart > head.length)
			nameStart = 0;
		auto attrAndRet = head[0..nameStart].strip();
		auto name = head[nameStart..$];
		
		// Extract attribute list and return type
		auto templStart = attrAndRet.locatePrior('!'); // UTF-safe because '!' is one code-point
		auto retTypeStart = attrAndRet.locatePrior(' ', templStart) + 1; // UTF-safe because ' ' is one code-point
		if(retTypeStart > attrAndRet.length)
			retTypeStart = 0;
		auto attr = attrAndRet[0..retTypeStart].strip();
		auto retType = attrAndRet[retTypeStart..$];
		retType = highlightAPIHeadParams(p, tag, retType, false);
		
		// Output everything except params
		str ~=
			`<span class="attr">%s</span> %s <span class="ident">%s</span>`
				.format(attr, retType, name);
		
		// Output params
		if(splitParens.length > 0)
		{
			// Output template params
			foreach(paren; splitParens[0..$-1])
			{
				str ~= "(";
				str ~= highlightAPIHeadParams(p, tag, paren, false);
			}

			// Output regular params
			auto lastParen = splitParens[$-1];
			str ~= "(";
			str ~= highlightAPIHeadParams(p, tag, lastParen, true);
		}
		
		str ~= "<br />\n";
	}
	
	return `<div class="api-head">%s</div>`.format(str);
}

private string highlightAPIHeadParams(Page p, AST_Tag tag, string data, bool highlightVarNames)
{
	string str = "";
	auto paramSections = tokenizeParams(data);
	int parenDepth = 0;
	bool isAfterEquals = false;
	foreach(int paramSectionIndex, ParamTok section; paramSections)
	{
		switch(section.type)
		{
		case ParamTokType.Ident:
			if(highlightVarNames && parenDepth == 0)
			{
				if(paramSectionIndex < paramSections.length)
				{
					bool nextSectionFound = false;
					ParamTok nextSection;
					foreach(ParamTok potentialNextSection; paramSections[paramSectionIndex+1..$])
					if(potentialNextSection.type != ParamTokType.Whitespace)
					{
						nextSectionFound = true;
						nextSection = potentialNextSection;
						break;
					}
					
					auto nextType = nextSection.type;
					bool isParamName=false;
					if(nextType == ParamTokType.Equals)
						isParamName = true;
					else if(!isAfterEquals)
					{
						if( nextType == ParamTokType.Comma || nextType == ParamTokType.CloseParen )
							isParamName = true;
						else if( nextType == ParamTokType.Misc )
						{
							if(nextSection.str.length >= 3 && nextSection.str[0..3] == "...")
								isParamName = true;
						}
					}
					
					if(isParamName)
					{
						str ~=
							`<span class="param-name">%s</span>`
								.format(section.str);
						continue;
					}
				}
			}
			
			if(section.str in Page.typeLookup)
				str ~= p.linkToType(section.str, "page-link");
			else
				str ~= section.str;
			break;
			
		case ParamTokType.Comma:
			isAfterEquals = false;
			str ~= section.str;
			break;
			
		case ParamTokType.Equals:
			isAfterEquals = true;
			str ~= section.str;
			break;
			
		case ParamTokType.OpenParen:
			parenDepth++;
			str ~= section.str;
			break;
			
		case ParamTokType.CloseParen:
			parenDepth--;
			str ~= section.str;
			break;
			
		case ParamTokType.Whitespace:
		case ParamTokType.Misc:
			str ~= section.str;
			break;

		default:
			throw new Exception("Internal Exception: Unhandled ParamTokType '%s'".format(section.type));
		}
	}
	
	return str;
}

enum ParamTokType
{
	Ident, Whitespace, Comma, OpenParen, CloseParen, Equals, Misc
}

struct ParamTok
{
	ParamTokType type;
	string str;
}

ParamTok[] tokenizeParams(string data)
{
	ParamTokType modeOf(dchar c)
	{
		switch(c)
		{
		case ',': return ParamTokType.Comma;
		case '(': return ParamTokType.OpenParen;
		case ')': return ParamTokType.CloseParen;
		case '=': return ParamTokType.Equals;
		
		default:
			if(isWhite(c))
				return ParamTokType.Whitespace;

			if(contains(to!dstring(letters~digits), c) || contains("_{}"d, c))
				return ParamTokType.Ident;
				
			return ParamTokType.Misc;
		}
	}
	
	ParamTok[] ret = [];
	dstring str = "";
	auto mode = ParamTokType.Whitespace;
	foreach(c; to!(dstring)(data))
	{
		auto nextMode = modeOf(c);
		if(mode != nextMode)
		{
			ret ~= ParamTok(mode, to!(string)(str));
			str = "";
		}
		str ~= c;
		mode = nextMode;
	}
	ret ~= ParamTok(mode, to!(string)(str));
	return ret;
}
