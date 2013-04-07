// Goldie: GOLD Engine for D
// Tools: Generate Documentation
// Written in the D programming language.

module tools.gendocs.asttag;

import semitwist.cmd.all;
import semitwist.treeout;
import goldie.all;

import tools.gendocs.exception;

mixin(genEnum("Stmt", [
	"var"[],
	"data",
	"rem",
	"name",
	"title",
	"desc",
	"frame",
	"urlLink",
	"div",
	"span",
	"code",
	"file",
	"page",
	"pageTitle",
	"pageName",
	"pageLink",
	"typeName",
	"typeLink",
	"link",
	"ident",
	"attr",
	"paramName",
	"apiDef",
	"apiHead",
	"apiHeadPlain",
	"apiSection",
	"apiSectionType",
	"definesType"
]));

class AST_Tag
{
	public Stmt stmt;
	public string[] params;
	
	public string data;
	public AST_Tag[] sub;
	
	public string file;
	public ptrdiff_t line;
	public ptrdiff_t srcIndexStart;
	public ptrdiff_t srcIndexEnd;

	public this(Token tok)
	{
		mixin(initMemberFrom("tok", "file", "line", "srcIndexStart", "srcIndexEnd"));
		loadFromToken(tok);
	}
	
	public TreeNode toTreeNode(int id=0)
	{
		auto nodeName = "%s: %s".format(id, enumStmtToString(stmt));
		auto node = new TreeNode(nodeName);
		
		if(params !is null)
		foreach(int i, string p; params)
			node.addAttribute("param "~to!(string)(i), p);

		if(data !is null)
			node.addAttribute("data", data);
			
		node.addAttribute("srcIndexStart", srcIndexStart);
		node.addAttribute("srcLength", srcIndexEnd - srcIndexStart);

		foreach(int i, AST_Tag subTag; sub)
			node.addContent(subTag.toTreeNode(i));
		
		return node;
	}
	
	private string getStatementName(Token tok)
	{
		if( !tok.matches("<TagContent>", "<Section>")   ||
			!tok.subX[0].matches("<Section>", "Literal") )
		{
			throw new SemanticException(
				tok, 
				"Statement names cannot contain tags or quotes: '%s'".format( tok.toString() )
			);
		}
		
		return tok.subX[0].subX[0].toString().strip();
	}
	
	private void loadFromTagContentToken(Token tok)
	{
		if(
			tok.matches("<TagContent>", "<Section>") ||
			tok.matches("<TagContent>", "<TagContent>", "<Section>") )
		{
			Token[] sectionList = [];
			Token currTok = tok;
			while(true)
			{
				if(currTok.matches("<TagContent>", "<TagContent>", "<Section>"))
				{
					sectionList = currTok.subX[1] ~ sectionList;
					currTok = currTok.subX[0];
				}
				else if(currTok.matches("<TagContent>", "<Section>"))
				{
					sectionList = currTok.subX[0] ~ sectionList;
					break;
				}
				else
					throw new WrongTokenTypeException(currTok);
			}
			
			sub = [];
			data = "";
			foreach(int i, Token section; sectionList)
			{
				auto newNode = new AST_Tag(section);
				sub ~= newNode;
				
				if(i == 0 && section.matches("<Section>", "Literal"))
					newNode.data = newNode.data.stripLeft();

				if(i == sectionList.length-1 && section.matches("<Section>", "Literal"))
					newNode.data = newNode.data.stripRight();
				
				if(data !is null && newNode.stmt == Stmt.data)
					data ~= newNode.data;
				
				if(newNode.stmt != Stmt.data)
					data = null; // "string data" is no longer applicable since a Statement exists
			}
		}
		else
			throw new WrongTokenTypeException(tok);
	}
	
	private void loadFromToken(Token tok)
	{
		if(tok.matches("<Tag>", "[$", "<TagContentList>", "$]"))
		{
			loadFromToken(tok.subX[1]);
		}
		else if(
			tok.matches("<TagContentList>", "<TagContent>") ||
			tok.matches("<TagContentList>", "<TagContentList>", "|", "<TagContent>") )
		{
			Token[] contentList = [];
			Token currTok = tok;
			while(true)
			{
				if(currTok.matches("<TagContentList>", "<TagContentList>", "|", "<TagContent>"))
				{
					contentList = currTok.subX[2] ~ contentList;
					currTok = currTok.subX[0];
				}
				else if(currTok.matches("<TagContentList>", "<TagContent>"))
				{
					contentList = currTok.subX[0] ~ contentList;
					break;
				}
				else
					throw new WrongTokenTypeException(currTok);
			}
			
			string stmtName = getStatementName(contentList[0]);
			auto isValidStmtName = true;
			try
				stmt = stringToEnumStmt(stmtName);
			catch(Exception e)
				isValidStmtName = false;
			
			if(contentList.length == 1 &&
				(!isValidStmtName || stmt == Stmt.name || stmt == Stmt.title || stmt == Stmt.desc) )
			{
				// Tag is shorthand for "[$var|...$]" statement
				stmt = Stmt.var;
				params = [ getStatementName(contentList[0]) ];
			}
			else
			{
				// Tag is ordinary statement
				if(!isValidStmtName)
					throw new SemanticException(
						contentList[0],
						"Invalid statement: '%s'".format(stmtName)
					);
				
				Token[] remainingContentList;
				switch(stmt)
				{
				case Stmt.data:
					// Don't allow explicit data statement because it doesn't
					// work and isn't needed anyway.
					throw new SemanticException(
						contentList[0],
						"Invalid statement: '%s'".format(stmtName)
					);
					
				case Stmt.rem:
				case Stmt.name:
				case Stmt.title:
				case Stmt.desc:
				case Stmt.frame:
				case Stmt.urlLink:
				case Stmt.ident:
				case Stmt.attr:
				case Stmt.paramName:
				case Stmt.file:
				case Stmt.page:
				case Stmt.pageTitle:
				case Stmt.pageName:
				case Stmt.typeName:
				case Stmt.apiHead:
				case Stmt.apiHeadPlain:
				case Stmt.apiDef:
				case Stmt.definesType:
					remainingContentList = contentList[1..$];
					if(remainingContentList.length == 0)
					{
						throw new SemanticException(
							tok,
							"Missing content data for '%s'".format(stmtName)
						);
					}
					break;
					
				case Stmt.var:
				case Stmt.div:
				case Stmt.span:
				case Stmt.code:
				case Stmt.pageLink:
				case Stmt.typeLink:
				case Stmt.link:
					if(contentList.length < 2)
						throw new SemanticException(
							tok,
							"Missing parameter for '%s'".format(stmtName)
						);

					params = [ getStatementName(contentList[1]) ];
					remainingContentList = contentList[2..$];
					
					if(remainingContentList.length == 0 && stmt != Stmt.var)
						throw new SemanticException(
							tok,
							"Missing content data for '%s'".format(stmtName)
						);
					break;

				case Stmt.apiSection:
				case Stmt.apiSectionType:
					if(contentList.length < 3)
						throw new SemanticException(
							tok,
							"Missing parameter for '%s'".format(stmtName)
						);

					params = [ getStatementName(contentList[1]), getStatementName(contentList[2]) ];
					remainingContentList = contentList[3..$];
					
					if(remainingContentList.length == 0 && stmt != Stmt.var)
						throw new SemanticException(
							tok,
							"Missing content data for '%s'".format(stmtName)
						);
					break;

				default:
					throw new SemanticException(
						tok,
						"Internal Exception: Unhandled Stmt '%s'".format(stmtName)
					);
				}
				
				if(remainingContentList.length > 1)
				{
					throw new SemanticException(
						remainingContentList[0],
						"Content cannot have unquoted pipe '|', use '[:|:]' instead."
					);
				}
				else if(remainingContentList.length == 1)
					loadFromTagContentToken(remainingContentList[0]);
			}
		}
		else if(
			tok.matches("<TagContent>", "<Section>") ||
			tok.matches("<TagContent>", "<TagContent>", "<Section>") )
		{
			// Execution should only end up here if the <TagContent> is the root of the parse-tree.
			
			//TODO? Can't check this unless a "parent" member is added to Token.
			//if(tok.parent !is null)
			//	throw new Exception("Internal Error: Only a parse-tree root <TagContent> should get here.");
			
			stmt = Stmt.data;
			loadFromTagContentToken(tok);
		}
		else if(tok.matches("<Section>", "<Tag>"))
		{
			loadFromToken(tok.subX[0]);
		}
		else if(tok.matches("<Section>", "Quote"))
		{
			stmt = Stmt.data;
			data = tok.subX[0].toString()[2..$-2]; // Strip the "[:" and ":]"
		}
		else if(tok.matches("<Section>", "Literal"))
		{
			stmt = Stmt.data;
			data = tok.subX[0].toString();
		}
		else
			throw new WrongTokenTypeException(tok);
	}
}
