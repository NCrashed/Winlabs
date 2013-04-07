// Goldie: GOLD Engine for D
// Tools: Generate Documentation
// Written in the D programming language.

module tools.gendocs.page;

import std.array;
import std.file;
import std.path;
import std.regex;
import std.stdio;
import std.string;

import semitwist.util.all;
import semitwist.treeout;
import goldie.all;

import tools.gendocs.asttag;
import tools.gendocs.exception;

enum frameAutoVarName = "framed";

struct PageContentUnit
{
	bool isVar;
	string data;
	AST_Tag tag;
	string[] params;
}

PageContentUnit makePageContentUnit_Literal(AST_Tag tag, string data)
{
	PageContentUnit unit;
	unit.tag   = tag;
	unit.data  = data;
	unit.isVar = false;
	return unit;
}

PageContentUnit makePageContentUnit_Var(AST_Tag tag, string varName, string[] params=null)
{
	PageContentUnit unit;
	unit.tag    = tag;
	unit.data   = varName;
	unit.isVar  = true;
	unit.params = params;
	return unit;
}

string makeLink(string url, string label, string cssClass="")
{
	if(cssClass != "")
		cssClass = ` class="%s"`.format(cssClass);
		
	return `<a%s href="%s">%s</a>`.format(cssClass, url, label);
}

string makeDisabledLink(string label, string cssClass="")
{
	if(cssClass != "")
		cssClass = ` class="%s"`.format(cssClass);
		
	return `<span%s>%s</span>`.format(cssClass, label);
}

string toAnchorName(string name)
{
	return replace(name.strip(), regex(`[!(){} ]`, "g"), "_");
}

string highlightMetaParams(string str)
{
	return 
		std.regex.replace!(
			(m)
			{
				return `<span class="metaparam">%s</span>`.format(m.hit);
			}
		)( str, regex(`\{([a-zA-Z0-9_]+)\}`, "g") );
}

// Really just highlights line comments right now.
// Warning: Ignores string literals, so this is mistakenly highlighted:
//   "hello // world"
//TODO: Notice string literals
string highlightCode(string str)
{
	str = 
		std.regex.replace!(
			(m)
			{
				string comment = m.hit;
				string trimComment = comment.strip();
				return
					`<span class="code-comment">%s</span>%s`
						.format(trimComment, comment[trimComment.length..$]);
			}
		)(str, regex(r"//([^\n]*)$", "gm"));

	str = 
		std.regex.replace!(
			(m)
			{
				string line = m.hit[1..$];
				return `<div style="width: 100%%;" class="code-added">%s</div>`.format(line);
			}
		)(str, regex(r"^\+([^\n]*)\n?", "gm"));
	
	return str;
}

class Page
{
	public static Language lang;
	public static bool   trimLinks;
	public static string srcDir;
	public static string astOutDir;
	public static string pageFilename;
	public static Page[string] pageLookup;
	public static bool[string] ambiguousPageNames;
	public static Page[string] typeLookup;
	public static bool[string] typesDefined;

	public static string[string] vars;
	public static string delegate(Page,AST_Tag,string[])[string] dgVars;
	
	public string srcFile;
	public string name;
	public string title;
	public string desc;
	public PageContentUnit[] content;
	public Page parent;
	public Page[] sub;
	
	public Page frame;
	
	public AST_Tag[string] fileASTs;
	
	// If loading fails, this provides access to
	// the partially-constructed object.
	public static Page partialObject;
	
	public this(string filename, Page parent=null)
	{
		auto prevPartialObject = partialObject;
		partialObject = this;
		
		this.parent = parent;
		loadFromFile(filename);

		addToPageLookup(fullName);
		if(name != fullName)
			addToPageLookup(name);

		partialObject = prevPartialObject;
	}
	
	private this(AST_Tag ast, Page parent=null)
	{
		auto prevPartialObject = partialObject;
		partialObject = this;
		
		this.parent = parent;
		loadFromAST(ast);

		addToPageLookup(name);
		addToPageLookup(fullName);

		partialObject = prevPartialObject;
	}
	
	private void addToPageLookup(string name)
	{
		if(!(name in ambiguousPageNames))
		{
			if(name in pageLookup)
			{
				pageLookup.remove(name);
				ambiguousPageNames[name] = true;
			}
			else
				pageLookup[name] = this;
		}
	}
	
	public @property string fullName()
	{
		return parent? parent.fullName~"."~name : name;
	}
	
	public @property string urlToRoot()
	{
		return (parent? "../" ~ parent.urlToRoot : "");
	}
	
	public @property string urlToBase()
	{
		return "../" ~ urlToRoot();
	}
	
	public @property string urlFromRoot()
	{
		return (parent? parent.urlFromRoot ~ name ~ "/" : "");
	}

	public string urlTo(Page target)
	{
		return this.urlToRoot ~ target.urlFromRoot;
	}

	public string linkTo(Page target, string cssClass="", string label="", string anchor="", bool nbsp=false)
	{
		if(label == "")
			label = target.title;
			
		if(nbsp)
			label = label.replace(" ", "&nbsp;");
			
		if(this is target && anchor == "")
			return makeDisabledLink(label, cssClass);
		else
		{
			auto url = "%s%s%s".format(
				urlTo(target),
				trimLinks? "" : pageFilename,
				anchor==""? "" : ("#"~toAnchorName(anchor))
			);
			return makeLink(url, label, cssClass);
		}
	}
	
	public string linkToType(string type, string cssClass="", string label="")
	{
		auto target = typeLookup[type];
		
		if(label == "")
			label = highlightMetaParams(type);
		
		string anchor = "";
		if(target.typesDefined.keys.length > 1)
			anchor = "#" ~ toAnchorName(type);
		
		if(this is target)
		{
			if(anchor == "")
				return makeDisabledLink(label, cssClass);
			else
				return makeLink(anchor, label, cssClass);
		}
		else
		{
			auto url = urlTo(target) ~ (trimLinks?"":pageFilename);
			if(target.name != type)
				url ~= anchor;

			return makeLink(url, label, cssClass);
		}
	}
	
	// For debugging
	public string toStringAll()
	{
		string str = toString();
		
		foreach(Page subPage; sub)
			str ~= subPage.toStringAll();
		
		return str;
	}
	
	// For debugging
	public override string toString()
	{
		string str = "";
		
		str ~= "Src File : " ~ srcFile  ~ nlStr;
		str ~= "Name     : " ~ name     ~ nlStr;
		str ~= "Full Name: " ~ fullName ~ nlStr;
		str ~= "Title    : " ~ title    ~ nlStr;
		str ~= "Desc     : " ~ desc     ~ nlStr;

		str ~= "Sub Pages:" ~ nlStr;
		foreach(Page subPage; sub)
			str ~= "  " ~ subPage.name ~ nlStr;

		str ~= "Content:" ~ nlStr;
		str ~= contentString() ~ nlStr;
		str ~= "--------------------------------------------------------"~nlStr;
		return str;
	}

	public string contentString(Page frameOf=null, string framed="")
	{
		string str = "";
		foreach(PageContentUnit unit; content)
		{
			if(!unit.isVar)
				str ~= unit.data;
			else
			{
				auto varName = unit.data;
				if(frameOf && varName == frameAutoVarName)
					str ~= framed;
				else if(varName in dgVars)
					str ~= dgVars[varName](frameOf? frameOf : this, unit.tag, unit.params);
				else if(varName in vars)
					str ~= vars[varName];
				else
					throw new SemanticException(
						unit.tag, "Undefined var '%s'".format(varName)
					);
			}
		}

		if(frame)
			str = frame.contentString(this, str);
		
		return str;
	}
	
	private void loadFromFile(string filename)
	{
		srcFile = srcDir~filename;
		auto code = readUTFFile!string(srcFile);
		loadFromCode(code, srcFile);
	}

	private void loadFromCode(string code, string filename="")
	{
		auto pt = lang.parseCodeX(code, filename).parseTreeX;
		auto ast = new AST_Tag(pt);
		loadFromAST(ast);
	}

	private void loadFromAST(AST_Tag ast)
	{
		foreach(AST_Tag tag; ast.sub)
		{
			if(tag.stmt == Stmt.data)
				loadFromAST_Literal(tag);
			else
				loadFromAST_Statement(tag);
		}
		
		fileASTs[ast.file] = ast;
	}

	/// [:...:]: Quote, or Literal
	private void loadFromAST_Literal(AST_Tag tag)
	{
		content ~= PageContentUnit(false, tag.data);
	}

	/// [$...$]: Statement
	private void loadFromAST_Statement(AST_Tag tag)
	{
		void ensureTagHasData()
		{
			if(tag.data is null)
			{
				if(tag.sub.length == 0)
				{
					throw new SemanticException(
						tag,
						"Missing data in '%s' tag".format(enumStmtToString(tag.stmt))
					);
				}
				else
				{
					throw new SemanticException(
						tag,
						"Tag '%s' cannot contain sub-tags".format(enumStmtToString(tag.stmt))
					);
				}
			}
		}
		
		void ensureUnset(string var, string newVal)
		{
			if(var !is null)
			{
				throw new SemanticException(
					tag,
					"Page '%s' already set to '%s' (Tried to re-set to '%s')"
						.format( enumStmtToString(tag.stmt), var, newVal )
				);
			}
		}
		
		void registerType(string name)
		{
			name = name.strip();
			if(name in typeLookup)
			{
				throw new SemanticException(tag,
					"Type '%s' already defined on page '%s'"
						.format(name, typeLookup[name].fullName)
				);
			}
			typeLookup[name] = this;
			typesDefined[name] = true;
			
			auto index = name.locate('!'); // UTF-safe because '!' is one code-unit.
			if(index != name.length)
			{
				typeLookup[name[0..index]] = this;
				typesDefined[name[0..index]] = true;
			}
		}

		void makeAPISection(AST_Tag tag)
		{
			string moduleStr = "";
			if(tag.params[1] != "")
			{
				moduleStr =
					`<p class="module-decl">module %s</p>`
						.format(tag.params[1]);
			}
			
			auto label = highlightMetaParams(tag.data);
			
			content ~=
				makePageContentUnit_Literal(
					tag,
					`%s<div class="api-section"><a name="%s" />%s</div>`
						.format(moduleStr, toAnchorName(tag.params[0]), label)
				);
		}

		switch(tag.stmt)
		{
		case Stmt.data:
			string data = "";
			foreach(AST_Tag subTag; tag.sub)
			{
				loadFromAST(subTag);
				data ~= subTag.data;
			}
			content ~= makePageContentUnit_Literal(tag, data);
			break;

		case Stmt.rem:
			// Do nothing
			break;
			
		case Stmt.var:
			auto varName = tag.params[0];
			content ~= makePageContentUnit_Var(tag, varName);
			break;

		case Stmt.name:
			ensureTagHasData();
			ensureUnset(name, tag.data);
			name = tag.data;
			break;

		case Stmt.title:
			ensureTagHasData();
			ensureUnset(title, tag.data);
			title = tag.data;
			break;

		case Stmt.desc:
			ensureTagHasData();
			ensureUnset(desc, tag.data);
			desc = tag.data;
			break;

		case Stmt.definesType:
			ensureTagHasData();
			registerType(tag.data);
			break;

		case Stmt.frame:
			ensureTagHasData();
			ensureUnset(frame?"frame":null, tag.data);
			frame = new Page(tag.data);
			break;
			
		//TODO? Make a preDiv
		case Stmt.div:
			ensureTagHasData();
			content ~= makePageContentUnit_Literal(tag, `<div class="%s">%s</div>`.format(tag.params[0], tag.data));
			break;

		case Stmt.span:
			ensureTagHasData();
			content ~= makePageContentUnit_Literal(tag, `<span class="%s">%s</span>`.format(tag.params[0], tag.data));
			break;

		case Stmt.code:
			ensureTagHasData();

			//TODO: Strip extra indents.
			tag.data = std.array.replace(tag.data, "\t", "    "); //TODO: Make adjustable
			tag.data = tag.data.escapeHTML();
			if(tag.params[0].startsWith("highlight"))
				tag.data = highlightCode(tag.data);
			
			if(tag.params[0].startsWith("plain") || tag.params[0].startsWith("highlight"))
				content ~= makePageContentUnit_Literal(tag, `<div class="code-%s">%s</div>`.format(tag.params[0], tag.data));
			else
				content ~= makePageContentUnit_Literal(tag, `<span class="code-%s">%s</span>`.format(tag.params[0], tag.data));
			break;

		case Stmt.ident:
			ensureTagHasData();
			string data = highlightMetaParams(tag.data);
			content ~= makePageContentUnit_Literal(tag, `<span class="ident">%s</span>`.format(data));
			break;

		case Stmt.attr:
			ensureTagHasData();
			content ~= makePageContentUnit_Literal(tag, `<span class="attr">%s</span>`.format(tag.data));
			break;

		case Stmt.paramName:
			ensureTagHasData();
			content ~= makePageContentUnit_Literal(tag, `<span class="param-name">%s</span>`.format(tag.data));
			break;

		case Stmt.urlLink:
			ensureTagHasData();
			content ~= makePageContentUnit_Literal(tag, `<a class="extern-link" href="%s">%s</a>`.format(tag.data, tag.data));
			break;

		case Stmt.link:
			ensureTagHasData();
			content ~= makePageContentUnit_Literal(tag, `<a class="extern-link" href="%s">%s</a>`.format(tag.params[0], tag.data));
			break;

		case Stmt.apiDef:
			ensureTagHasData();
			content ~= makePageContentUnit_Literal(tag, `<div class="api-def">%s</div>`.format(tag.data));
			break;

		case Stmt.apiHeadPlain:
			ensureTagHasData();
			content ~= makePageContentUnit_Literal(tag, `<div class="api-head"><span class="ident">%s</span></div>`.format(tag.data));
			break;

		case Stmt.apiHead:
			ensureTagHasData();
			content ~= makePageContentUnit_Var(tag, enumStmtToString(tag.stmt), [tag.data]);
			break;

		case Stmt.apiSection:
			ensureTagHasData();
			makeAPISection(tag);
			break;

		case Stmt.apiSectionType:
			ensureTagHasData();
			registerType(tag.params[0]);
			makeAPISection(tag);
			break;

		case Stmt.file:
			ensureTagHasData();
			loadFromFile(tag.data);
			break;
			
		case Stmt.page:
			sub ~= new Page(tag, this);
			break;
			
		case Stmt.pageTitle:
		case Stmt.pageName:
		case Stmt.typeName:
			ensureTagHasData();
			content ~= makePageContentUnit_Var(tag, enumStmtToString(tag.stmt), [tag.data]);
			break;
			
		case Stmt.pageLink:
		case Stmt.typeLink:
			ensureTagHasData();
			content ~= makePageContentUnit_Var(tag, enumStmtToString(tag.stmt), [tag.params[0], tag.data]);
			break;
			
		default:
			throw new SemanticException(
				tag,
				"Internal Exception: Unhandled statement: %s"
					.format( enumStmtToString(tag.stmt) )
			);
		}
	}
	
	public void save()
	{
		if(!exists(name))
			mkdir(name);
		chdir(name);
		
		std.file.write(pageFilename, cast(string)bomCodeOf(BOM.UTF8) ~ contentString());
	
		foreach(Page subPage; sub)
			subPage.save();
		
		chdir("..");
	}

	public void saveJSON()
	{
		bool[string] filesHandled;
		saveJSON(filesHandled);
	}
	
	private void saveJSON(ref bool[string] filesHandled)
	{
		foreach(string srcFile, AST_Tag ast; fileASTs)
		if(!(srcFile in filesHandled))
		{
			filesHandled[srcFile] = true;
			
			auto tree = fileASTs[srcFile].toTreeNode;
			tree.addAttribute("file", srcFile);
			tree.addAttribute("source", readUTFFile!string(srcFile));
			tree.addAttribute("parseTreeMode", true);
			//tree.addAttribute("suggestedLabel", "data, params");
			auto jsonOutput = tree.format(formatterPrettyJSON);
			auto outFile = astOutDir ~ baseName(srcFile) ~ ".ast.json";
			std.file.write(outFile, jsonOutput);
		}

		if(frame !is null)
			frame.saveJSON(filesHandled);
			
		foreach(Page subPage; sub)
			subPage.saveJSON(filesHandled);
	}
}
