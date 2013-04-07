﻿// Goldie: GOLD Engine for D
// Tools: Static Lang: Generate Statically-Typed Language Interface
// Written in the D programming language.
//
// Generates a static-style language from a CGT file.

//TODO: Make Token_!(GoldSymbolType.NonTerminal, "foo") abstract. Possible?
//TODO: Accept .grm files directly

module tools.staticlang.main;

import std.conv;
import std.file;
import std.stdio;
import std.string;

import semitwist.util.all;
import goldie.all;
import tools.staticlang.cmd;
import tools.util;

enum string langClass   = Language.stringof;
enum string lexerClass  = Lexer.stringof;
enum string parserClass = Parser.stringof;
enum string tokenClass  = Token.stringof;

enum string symbolTypeStruct = SymbolType.stringof;
enum string subTokenTypeName = "SubTokenType";
enum string versionIdent = "Goldie_StaticStyle";

enum string headerNotice =
`/// This module was generated by the StaticLang tool from
/// Goldie v`~goldieVerStr~`: http://www.semitwist.com/goldie/

`;

struct StoreVar
{
	int numId;
	bool   delegate(int)         filter;
	string delegate(int)[string] subExpandMap;
	string delegate(string, int) subFinalize;
	string delegate(string)      finalize;
}
alias string delegate(string) ModifyVar;

alias string   [string] CVType;
alias StoreVar [string] SVType;
alias ModifyVar[string] MVType;

class Config
{
	private Language lang;
	private Options cmdArgs;
	CVType cvars;
	SVType svars;
	MVType mvars;
	
	this(Options cmdArgs, Language lang)
	{
		this.cmdArgs = cmdArgs;
		this.lang = lang;
		
		genCVars();
		genSVars();
		genMVars();
	}
	
	private string langStaticDataReduction(T)(string a, T b)
	{
		return "%s\n\t\t%s,".format(a, b);
	}

	private string langStaticDataGenerate(T)(T[] table)
	{
		return "[" ~ reduceTo(table, &langStaticDataReduction!(T)) ~ "\n\t]";
	}

	private void genCVars()
	{
		auto uniqueSymbolNames = lang.uniqueSymbolNames().sort;
		
		cvars["REM"]           = "";
		cvars["STATIC"]        = "static";
		cvars["OVERRIDE"]      = "override";
		cvars["VERSION"]       = goldieVerStr;
		cvars["PACKAGE"]       = cmdArgs.outputPackage;
		cvars["SHORT_PACKAGE"] = cmdArgs.shortPackage;
		cvars["INIT_STATIC_LANG"] = (`
			version = `~versionIdent~`;
			private enum _packageName = "`~cmdArgs.outputPackage~`";
			private enum _shortPackageName = "`~cmdArgs.shortPackage~`";
		`).normalize();

		cvars["LANG_CLASSNAME"] = langIdent(langClass);
		cvars["LANG_INHERIT"]   = "public class "~cvars["LANG_CLASSNAME"]~" : "~langClass;
		cvars["LANG_INSTNAME"]  = "language_"~cmdArgs.shortPackage;
		cvars["LANG_FILENAME"]  = cmdArgs.cgtFileOnly;

		cvars["LEXER_CLASSNAME"] = langIdent(lexerClass);
		cvars["LEXER_INHERIT"]   = "public class "~cvars["LEXER_CLASSNAME"]~" : "~lexerClass;

		cvars["PARSER_CLASSNAME"] = langIdent(parserClass);
		cvars["PARSER_INHERIT"]   = "public class "~cvars["PARSER_CLASSNAME"]~" : "~parserClass;

		cvars["TOKEN_CLASSNAME"]  = langIdent(tokenClass);
		cvars["TOKEN_INHERIT"]    = "private class _"~cvars["TOKEN_CLASSNAME"]~
			"("~symbolTypeStruct~" staticSymbolType, string _staticName) : Base_"~cvars["TOKEN_CLASSNAME"];

		cvars["SUBTOKENTYPE_NAME"] = langIdent(subTokenTypeName);

		cvars["IS_CORRECT_TOKEN_FUNCNAME"] = langIdent("isCorrectToken");
		cvars["RULE_ID_OF_FUNCNAME"]       = langIdent("ruleIdOf");
		
		cvars["TOKEN_CTOR_TERMFIRST"] =
			"static if(staticSymbolType != "~symbolTypeStruct~".NonTerminal) {\n";
		cvars["TOKEN_CTOR_NONTERMFIRST"] =
			"static if(staticSymbolType == "~symbolTypeStruct~".NonTerminal) {\n";
		cvars["BLOCK_ELSE"] = "} else {";
		cvars["TOKEN_CTOR_END"] = "}";

		cvars["TOKEN_CLASSNAME_TOPNODE"] =
			cvars["TOKEN_CLASSNAME"]~"!("~
			fullSymbolTypeToString(lang.symbolTable[lang.startSymbolIndex].type)~
			", "~escapeDDQS(to!(string)(lang.symbolTable[lang.startSymbolIndex].name))~")";

		// TOKEN_TEMPLATE_1P
		cvars["TOKEN_TEMPLATE_1P"] = "";
		foreach(string symName; uniqueSymbolNames)
		{
			Symbol sym = lang.symbolsByName(symName)[0];
			int i = sym.id;

			if(cvars["TOKEN_TEMPLATE_1P"] != "")
				cvars["TOKEN_TEMPLATE_1P"] ~= "else ";
			
			cvars["TOKEN_TEMPLATE_1P"] ~=
				"static if(staticName == %s)\n".format(escapeDDQS(sym.name));

			SymbolType[] types = [sym.type];
			foreach(int i2, Symbol sym2; lang.symbolTable[i+1..$])
			{
				if(sym.name == sym2.name)
					types ~= sym2.type;
			}
			
			if(types.length == 1)
			{
				cvars["TOKEN_TEMPLATE_1P"] ~=
					("			alias _"~cvars["TOKEN_CLASSNAME"]~"!(%s, staticName) "~cvars["TOKEN_CLASSNAME"]~";\n"~
					"		"
					).format(fullSymbolTypeToString(types[0]));
			}
			else
			{
				string typesStr;
				foreach(int iType, SymbolType type; types)
				{
					if(iType > 0) typesStr ~= ", ";
					typesStr ~= fullSymbolTypeToString(types[iType]);
				}
				cvars["TOKEN_TEMPLATE_1P"] ~=
					("			static assert(false, \""~cvars["TOKEN_CLASSNAME"]~"!('\"~staticName~\n"~
					"				\"') is ambiguous, please specify "~symbolTypeStruct~"\"~\n"~
					"				\" (ex: %s!("~symbolTypeStruct~".Terminal, \\\"+\\\"))\\n\"~\n"~
					"				\"Possible types: ["~typesStr~"]\");\n"~
					"		"
					).format(cvars["TOKEN_CLASSNAME"]);
			}
		}
		cvars["TOKEN_TEMPLATE_1P"] ~=
			"else\n"~
			"			static assert(false,\n"~
			"				\"Invalid token: "~cvars["TOKEN_CLASSNAME"]~"!('\"~staticName~\"')\");";

		// TOKEN_TEMPLATE_2P
		cvars["TOKEN_TEMPLATE_2P"] = "";
		foreach(int i, Symbol sym; lang.symbolTable)
		{
			if(i != 0)
				cvars["TOKEN_TEMPLATE_2P"] ~= "else ";
			
			cvars["TOKEN_TEMPLATE_2P"] ~=
				("static if(staticSymbolType == %s && staticName == %s)\n"~
				"			alias _"~cvars["TOKEN_CLASSNAME"]~"!(staticSymbolType, staticName) "~cvars["TOKEN_CLASSNAME"]~";\n"~
				"		"
				).format(fullSymbolTypeToString(sym.type), escapeDDQS(sym.name));
		}
		cvars["TOKEN_TEMPLATE_2P"] ~=
			"else\n"~
			"			static assert(false,\n"~
			"				\"Invalid token: "~cvars["TOKEN_CLASSNAME"]~"!("~symbolTypeStruct~".\"~\n"~
			"				goldSymbolTypeToString(staticSymbolType)~\", '\"~staticName~\"')\");";

		// TOKEN_TEMPLATE_RULE
		cvars["TOKEN_TEMPLATE_RULE"] = "";
		foreach(int i, Rule rule; lang.ruleTable)
		{
			if(i != 0)
				cvars["TOKEN_TEMPLATE_RULE"] ~= "else ";
			
			cvars["TOKEN_TEMPLATE_RULE"] ~=
				("static if(staticRuleId == %s && staticName == %s)\n"~
				"			alias _"~cvars["TOKEN_CLASSNAME"]~"!("~symbolTypeStruct~".NonTerminal, staticName, staticRuleId) "~cvars["TOKEN_CLASSNAME"]~";\n"~
				"		"
				).format(i, escapeDDQS(lang.symbolTable[rule.symbolIndex].name));
		}
		cvars["TOKEN_TEMPLATE_RULE"] ~=
			"else\n"~
			"			static assert(false,\n"~
			"				\"Invalid token: "~cvars["TOKEN_CLASSNAME"]~"!('\"~\n"~
			"				staticName~\"', \"~ctfe_i2a(staticRuleId)~\")\");";

		// SUBTOKENTYPE_TEMPLATE
		cvars["SUBTOKENTYPE_TEMPLATE"] = "";
		foreach(int i1, Rule rule; lang.ruleTable)
		foreach(int i2, int termIndex; rule.subSymbolIndicies)
		{
			if(!(i1 == 0 && i2 == 0))
				cvars["SUBTOKENTYPE_TEMPLATE"] ~= "else ";
			
			cvars["SUBTOKENTYPE_TEMPLATE"] ~=
				("static if(ruleId == %s && index == %s)\n"~
				"			alias "~cvars["TOKEN_CLASSNAME"]~"!(%s, %s) "~cvars["SUBTOKENTYPE_NAME"]~";\n"
				"		"
				).format(
					i1, i2,
					fullSymbolTypeToString(lang.symbolTable[termIndex].type),
					escapeDDQS(lang.symbolTable[termIndex].name)
				);
		}
		cvars["SUBTOKENTYPE_TEMPLATE"] ~=
			"else\n"~
			"			static assert(false,\n"~
			"				\"Invalid subtoken: "~cvars["SUBTOKENTYPE_NAME"]~
			"!(\"~ctfe_i2a(ruleId)~\", \"~ctfe_i2a(index)~\")\");";
		
		// SET_STATICID_TERM
		cvars["SET_STATICID_TERM"] = "";
		foreach(Symbol sym; lang.symbolTable)
		{
			if(sym.type != SymbolType.NonTerminal)
			{
				if(cvars["SET_STATICID_TERM"] != "")
					cvars["SET_STATICID_TERM"] ~= "else ";
		
				cvars["SET_STATICID_TERM"] ~=
					("static if(staticSymbolType == %s && staticName == %s)\n"~
					"				int staticId = %s;\n"~
					"			"
					).format(fullSymbolTypeToString(sym.type), escapeDDQS(sym.name), sym.id);
			}
		}
		cvars["SET_STATICID_TERM"] ~=
			"else\n"~
			"				static assert(false,\n"~
			"					\"Invalid token: "~cvars["TOKEN_CLASSNAME"]~"!("~symbolTypeStruct~".\"~\n"~
			"					goldSymbolTypeToString(staticSymbolType)~\", '\"~staticName~\"')\");";

		// SET_STATICID_NONTERM
		cvars["SET_STATICID_NONTERM"] = "";
		foreach(Symbol sym; lang.symbolTable)
		{
			if(sym.type == SymbolType.NonTerminal)
			{
				if(cvars["SET_STATICID_NONTERM"] != "")
					cvars["SET_STATICID_NONTERM"] ~= "else ";
		
				cvars["SET_STATICID_NONTERM"] ~=
					("static if(staticName == %s)\n"~
					"				int staticId = %s;\n"~
					"			"
					).format(escapeDDQS(sym.name), sym.id);
			}
		}
		cvars["SET_STATICID_NONTERM"] ~=
			"else\n"~
			"				static assert(false,\n"~
			"					\"Invalid token: "~cvars["TOKEN_CLASSNAME"]~"!("~symbolTypeStruct~".\"~\n"~
			"					goldSymbolTypeToString(staticSymbolType)~\", '\"~staticName~\"')\");";

		// RULE_ID_OF
		cvars["RULE_ID_OF"] = "";
		foreach(int i1, Rule rule; lang.ruleTable)
		{
			if(cvars["RULE_ID_OF"] != "")
				cvars["RULE_ID_OF"] ~= "else ";
			
			auto numSubTokens = rule.subSymbolIndicies.length;
			string cond =
				"\n			staticName == %s && subTokenTypes.length == %s &&\n\t\t"
				.format(
					escapeDDQS(lang.symbolTable[rule.symbolIndex].name),
					numSubTokens==0 ? 1 : numSubTokens
				);
			
			if(numSubTokens == 0)
			{
				cond ~=
					"\t"~cvars["IS_CORRECT_TOKEN_FUNCNAME"]~"!(subTokenTypes[0], SymbolType.Terminal, null)\n\t\t";
			}
			else
			{
				foreach(int i2, int termSymIndex; rule.subSymbolIndicies)
				{
					cond ~=
						("\t%s!(subTokenTypes[%s], %s, %s)"
						).format(
							cvars["IS_CORRECT_TOKEN_FUNCNAME"],
							i2,
							fullSymbolTypeToString(lang.symbolTable[termSymIndex].type),
							escapeDDQS(lang.symbolTable[termSymIndex].name)
						);
					if(i2 != rule.subSymbolIndicies.length-1)
						cond ~= " &&";
					cond ~= "\n\t\t";
				}
			}
			
			cvars["RULE_ID_OF"] ~=
				("static if(%s)\n"~
				"			enum int %s = %s;\n"
				"		"
				).format(cond, cvars["RULE_ID_OF_FUNCNAME"], i1);
		}
		cvars["RULE_ID_OF"] ~=
			"else\n"~
			"			static assert(false,\n"~
			"				\"Invalid rule: "~cvars["RULE_ID_OF_FUNCNAME"]~"!('\"~staticName~\"', ...)\"); //TODO: expand that \"...\"";
		
		//LANG_STATICDATA
		string staticUniqueSymbolNames =
			reduceTo(uniqueSymbolNames,
				(string a, string b)
				{
					return "%s\n\t\t%s,".format(a, b.escapeDDQS());
				}
			);
		staticUniqueSymbolNames = "[" ~ staticUniqueSymbolNames ~ "\n\t]";
		
		cvars["LANG_STATICDATA"] =
			`static enum staticName   = %s;
	static enum staticVer    = %s;
	static enum staticAuthor = %s;
	static enum staticAbout  = %s;
	static enum staticCaseSensitive = %s;

	static enum staticStartSymbolIndex = %s;
	static enum staticInitialDFAState  = %s;
	static enum staticInitialLALRState = %s;
	static enum staticEofSymbolIndex   = %s;
	static enum staticErrorSymbolIndex = %s;

	private static enum _staticUniqueSymbolNameArray = %s;

	private static enum _staticSymbolTable = %s;
	
	private static enum _staticCharSetTable = %s;
	
	private static enum _staticRuleTable = %s;
	
	private static enum _staticDFATable = %s;
	
	private static enum _staticLALRTable = %s;
	
	static immutable staticUniqueSymbolNameArray = _staticUniqueSymbolNameArray;
	static immutable staticSymbolTable  = _staticSymbolTable;
	static immutable staticCharSetTable = _staticCharSetTable;
	static immutable staticRuleTable    = _staticRuleTable;
	static immutable staticDFATable     = _staticDFATable;
	static immutable staticLALRTable    = _staticLALRTable;`
			.format(
				escapeDDQS(lang.name), escapeDDQS(lang.ver), escapeDDQS(lang.author),
				escapeDDQS(lang.about), lang.caseSensitive,
				lang.startSymbolIndex, lang.initialDFAState, lang.initialLALRState,
				lang.eofSymbolIndex, lang.errorSymbolIndex,
				staticUniqueSymbolNames,
				langStaticDataGenerate(lang.symbolTable),
				langStaticDataGenerate(lang.charSetTable),
				langStaticDataGenerate(lang.ruleTable),
				langStaticDataGenerate(lang.dfaTable),
				langStaticDataGenerate(lang.lalrTable)
			);

		//INIT_SYMBOL_LOOKUP
		string symbolLookup = "";
		foreach(string k; uniqueSymbolNames)
		{
			auto v = lang.symbolsByName(k);
			
			symbolLookup ~= symbolLookup==""?"":",";
			auto kStr = k.escapeDDQS();
			symbolLookup ~=
				"\n\t\t\t\t%-20s : [%s]"
					.format(
						kStr,
						reduceTo(v,
							(string a, Symbol b)
							{
								return a ~ (a==""?"":", ") ~ b.toString();
							}
						)
					);
		}
		symbolLookup = "[" ~ symbolLookup ~ "\n\t\t\t]";
		cvars["INIT_SYMBOL_LOOKUP"] = `symbolLookup = %s;`.format(symbolLookup);
			
		// LOOKUP_SYMBOL
		cvars["LOOKUP_SYMBOL"] = "";
		foreach(string k; uniqueSymbolNames)
		{
			auto v = lang.symbolsByName(k);
			cvars["LOOKUP_SYMBOL"] ~=
				"case %-20s return %s;\n\t\t\t".format(k.escapeDDQS()~":", v);
		}
		cvars["LOOKUP_SYMBOL"] ~= "default:\n\t\t\t\treturn [];";
	}

	private bool filter(string key)(int i)
	{
		static if(key == "ACCEPT_TERM")
		{
			return lang.symbolTable[i].type != SymbolType.NonTerminal;
		}
		else static if(key == "REDUCE")
		{
			return true;
		}
		else
			static assert(false, "Invalid key: "~key);
	}
	
	private string subExpandMap(string key)(int i)
	{
		static if(key == "ACCEPT_TERM")
		{
			auto sym = lang.symbolTable[i];
			return
				cvars["TOKEN_CLASSNAME"]~"!("~
				fullSymbolTypeToString(sym.type)~
				", "~escapeDDQS(to!(string)(sym.name))~")";
		}
		else static if(key == "REDUCE")
		{
			return
				cvars["TOKEN_CLASSNAME"]~"!("~
				escapeDDQS(
					to!(string)
					( lang.symbolTable[lang.ruleTable[i].symbolIndex].name )
				)~
				", %s)".format(i);
		}
		else
			static assert(false, "Invalid key: "~key);
	}
	
	private string subFinalize(string key)(string str, int i)
	{
		static if(key == "ACCEPT_TERM")
		{
			return
				("				case %s:").format(i)~str~
				"	break;\n\n";
		}
		else static if(key == "REDUCE")
		{
			return
				("						case %s:").format(i)~str~
				"	break;\n";
		}
		else
			static assert(false, "Invalid key: "~key);
	}
	
	private string finalize(string key)(string str)
	{
		static if(key == "ACCEPT_TERM")
		{
			return
				"switch(symbol.id)\n"~
				"				{\n"~
				str~
				"				default:\n"~
				"					throw new InternalException(\"Accepting unexpected symbol #%s\".format(symbol.id));\n"~
				"				}";
		}
		else static if(key == "REDUCE")
		{
			return
				"switch(chosenAction.target)\n"~
				"						{\n"~
				str~
				"						default:\n"~
				"							throw new InternalException(\"Reducing to unexpected rule #%s\".format(chosenAction.target));\n"~
				"						}";
		}
		else
			static assert(false, "Invalid key: "~key);
	}
	
	void genSVars()
	{
		svars["ACCEPT_TERM"] = StoreVar();
		svars["ACCEPT_TERM"].numId = cast(int)lang.symbolTable.length;
		svars["ACCEPT_TERM"].filter = &this.filter!("ACCEPT_TERM");
		svars["ACCEPT_TERM"].subExpandMap =
			[
				"TOKEN_CLASSNAME": &this.subExpandMap!("ACCEPT_TERM")
			];
		svars["ACCEPT_TERM"].subFinalize = &this.subFinalize!("ACCEPT_TERM");
		svars["ACCEPT_TERM"].finalize = &this.finalize!("ACCEPT_TERM");

		svars["REDUCE"] = StoreVar();
		svars["REDUCE"].numId = cast(int)lang.ruleTable.length;
		svars["REDUCE"].filter = &this.filter!("REDUCE");
		svars["REDUCE"].subExpandMap =
			[
				"TOKEN_CLASSNAME": &this.subExpandMap!("REDUCE")
			];
		svars["REDUCE"].subFinalize = &this.subFinalize!("REDUCE");
		svars["REDUCE"].finalize = &this.finalize!("REDUCE");
	}

	private string staticIdent(string str)
	{
		dstring dstr = to!(dstring)(str);
		dstr = toUpper(dstr[0..1])[0] ~ dstr[1..$];
		return "static" ~ to!(string)(dstr);
	}
	
	private string langIdent(string str)
	{
		return toLangIdent(str, cmdArgs.shortPackage);
	}
	
	void genMVars()
	{
		mvars["STATIC_IDENT"] = &staticIdent;
		mvars["LANG_IDENT"]   = &langIdent;
	}
}

int main(string[] args)
{
	Options cmdArgs;
	int errLevel = cmdArgs.process(args);
	if(errLevel != -1)
		return errLevel;

	auto lang = Language.load(cmdArgs.cgtFile);
	auto conf = new Config(cmdArgs, lang);
	auto cvars = conf.cvars;
	auto svars = conf.svars;
	auto mvars = conf.mvars;
	
	foreach(string moduleName; ["all", "lang", "langHelper", "lexer", "parser", "token"])
		processModule(cmdArgs, cvars, svars, mvars, lang, moduleName);
	
	return 0;
}

void processModule(Options cmdArgs, CVType cvars, SVType svars, MVType mvars, Language lang, string moduleName)
{
	string src = readUTFFile!string(goldiePackageDir~moduleName~".d");

	foreach(string k, string v; cvars)
		src.expand(k, v);
	
	foreach(string key, StoreVar sv; svars)
		src.expandStore(cvars, lang, key, sv);

	foreach(string key, ModifyVar mv; mvars)
		src.expandModify(key, mv);

	src = cast(string)bomCodeOf(BOM.UTF8) ~ headerNotice ~ src;
	
	if(!exists(cmdArgs.outputDir))
		mkdirRecurse(cmdArgs.outputDir);
	else if(!isDir(cmdArgs.outputDir))
		throw new Exception("'"~cmdArgs.outputDir~"' is a file, not a directory.");
		
	auto file = new File(cmdArgs.outputDir~moduleName~".d", "wb");
	scope(exit) file.close;	
	file.rawWrite(src);
}

void expand(ref string src, string ident, string newStr)
{
	src.expandPlace(ident, newStr, "/+P:%s+/DUMMY");
	src.expandPlace(ident, newStr, "/+P:%s+/");
	src.expandStartEnd(ident, newStr, "/+S:%s+/", "/+E:%s+/");
}

void expandPlace(ref string src, string ident, string newStr, string findStr)
{
	findStr = findStr.format(ident);
	size_t i=0;
	while(true)
	{
		i = src.locate(findStr, i);
		if(i == src.length)
			break;
		
		src = src[0..i] ~ newStr ~ src[i+findStr.length..$];
	}
}

string expandSingleStartEnd(ref string src, string ident, string newStr, string findStart, string findEnd)
{
	findStart = findStart.format(ident);
	findEnd   = findEnd  .format(ident);
	string content=null;
	size_t iStart=0;
	while(true)
	{
		iStart = src.locate(findStart, iStart);
		if(iStart == src.length)
			break;
		
		size_t iEnd = src.locate(findEnd, iStart+findStart.length);
		if(iEnd == src.length)
			throw new Exception("Found '%s' with no matching '%s'".format(findStart, findEnd));
		
		content = src[iStart+findStart.length..iEnd];
		src = src[0..iStart] ~ newStr ~ src[iEnd+findEnd.length..$];
	}
	
	return content;
}

string expandStartEnd(ref string src, string ident, string newStr, string findStart, string findEnd, bool doAll=true)
{
	findStart = findStart.format(ident);
	findEnd   = findEnd  .format(ident);
	string content=null;
	size_t iStart=0;
	while(true)
	{
		iStart = src.locate(findStart, iStart);
		if(iStart == src.length)
			break;
		
		size_t iEnd = src.locate(findEnd, iStart+findStart.length);
		if(iEnd == src.length)
			throw new Exception("Found '%s' with no matching '%s'".format(findStart, findEnd));
		
		content = src[iStart+findStart.length..iEnd];
		src = src[0..iStart] ~ newStr ~ src[iEnd+findEnd.length..$];
		
		if(!doAll)
			break;
	}
	
	return content;
}

void expandStore(ref string src, CVType cvars, Language lang, string ident, StoreVar sv)
{
	auto store = src.expandStartEnd(ident~":STORE", "", "/+S:%s+/", "/+E:%s+/");
	if(store)
	{
		string newStr = "";
		for(int symIndex=0; symIndex < sv.numId; symIndex++)
		if( !sv.filter || (sv.filter && sv.filter(symIndex)) )
		{
			string storeFilled = store.idup;
			foreach(string key, string delegate(int) semDg; sv.subExpandMap)
			if(semDg)
			{
				string newSubStr = semDg(symIndex);
				storeFilled.expand(ident~":"~key, newSubStr);
			}
			if(sv.subFinalize)
				storeFilled = sv.subFinalize(storeFilled, symIndex);
			newStr ~= storeFilled;
		}
		
		if(sv.finalize)
			newStr = sv.finalize(newStr);
			
		src.expand(ident, newStr);
	}
}

void expandModify(ref string src, string ident, ModifyVar mv)
{
	while(true)
	{
		auto store = src.expandStartEnd("TO:"~ident, "/+P:__CURR_MVAR__+/", "/+S:%s+/", "/+E:%s+/", false);
		if(store is null)
			break;
		else
		{
			store = mv(store);
			src.expandPlace("__CURR_MVAR__", store, "/+P:%s+/");
		}
	}
}
