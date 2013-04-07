// Goldie: GOLD Engine for D
// Grammar Compiler
// Written in the D programming language.

module goldie.grmc.fsm;

import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.string;

import semitwist.util.all;
import goldie.base;
import goldie.lang;
import goldie.grmc.ast;

static if(!__traits(compiles, (){ bool x = std.ascii.isUpper(' '); }))
{
	static import std.ctype;
	private immutable useStdCType = true;
}
else
{
	import std.ascii;
	private immutable useStdCType = false;
}

enum FSMType { NFA, DFA }

alias FSM     !(FSMType.NFA) NFA;
alias FSMEdge !(FSMType.NFA) NFAEdge;
alias FSMState!(FSMType.NFA) NFAState;

alias FSM     !(FSMType.DFA) _DFA;
alias FSMEdge !(FSMType.DFA) _DFAEdge;
alias FSMState!(FSMType.DFA) _DFAState;

final class FSMState(FSMType fsmType)
{
	private alias FSMState!(FSMType.NFA) InnerNFAState;

	FSMEdge!fsmType[] edges;
	int acceptSymbolId; // -1 for "none"
	string acceptSymbolName;
	
	static if(fsmType == FSMType.DFA)
	{
		InnerNFAState[] nfaStates;
		int[] ambiguousAcceptIds;
	}
	
	static if(fsmType == FSMType.NFA)
	{
		// The states that can be reached from here *in one step*
		// without consuming any input. May contain duplicates.
		private InnerNFAState[] _partialClosure = null;
		InnerNFAState[] partialClosure()
		{
			if(_partialClosure is null)
			{
				foreach(ref edge; edges)
				if(edge.input == dchar.init)
					_partialClosure ~= edge.target;
			}
			
			return _partialClosure;
		}

		// The states that can be reached from here without consuming any input.
		private InnerNFAState[] _closure = null;
		InnerNFAState[] closure()
		{
			if(_closure is null)
			{
				_closure  = [this];
				InnerNFAState[] todo = [this];
				bool[InnerNFAState] found;
				found[this] = true;
				
				while(todo.length > 0)
				{
					// Pop state off todo
					auto state = todo[$-1];
					todo = todo[0..$-1];
					
					auto statePartialClosure = state.partialClosure;
					foreach(newState; statePartialClosure)
					{
						if(newState !in found)
						{
							found[newState] = true;
							_closure ~= newState;
							todo     ~= newState; // Push onto todo
						}
					}
				}
				
				_closure = array(uniq(sort(_closure)));
			}
			
			return _closure;
		}
	}

	this(FSMEdge!fsmType[] edges = [])
	{
		this.edges = edges;
		acceptSymbolId = -1;
	}
	
	int opCmp(FSMState!fsmType o)
	{
		if(id > o.id) return  1;
		if(id < o.id) return -1;
		return 0;
	}
	
	private static FSMState!fsmType[] allStates;

	long id = -1;
	
	static long nextID;
	FSMState!fsmType[] genIDs()
	{
		markUnvisited();
		clearIDs();
		nextID = 0;
		_genIDs();
		
		auto ret = allStates;
		allStates = null;
		return ret;
	}
	
	private void clearIDs()
	{
		visited = true;
		id = -1;
		allStates = [];
		foreach(ref edge; edges)
		if(!edge.target.visited)
			edge.target.clearIDs();
	}
	
	private void _genIDs()
	{
		id = nextID;
		allStates ~= this;
		nextID++;
		foreach(ref edge; edges)
		if(edge.target.id == -1)
			edge.target._genIDs();
	}

	private bool visited=true;
	private void markUnvisited()
	{
		visited = false;
		foreach(ref edge; edges)
		if(edge.target.visited)
			edge.target.markUnvisited();
	}
	
	private @property string dotName()
	{
		auto str = `"`;
		str ~= "S_";
		str ~= to!string(id);
		if(acceptSymbolId != -1)
		{
			str ~= ": ";
			if(acceptSymbolId >= 0 && acceptSymbolName != "")
				str ~= acceptSymbolName;
			else
			{
				str ~= "#";
				str ~= to!string(acceptSymbolId);
			}
		}
		str ~= `"`;
		return str;
	}
}

struct FSMEdge(FSMType fsmType)
{
	dchar input; // dchar.init for "none", but only if this is an NFA
	FSMState!fsmType target;
	
	// Name of character set that 'input' came from.
	// This is not always available and might be blank for many edges.
	string origCharSetName;
	
	// ID# of charset from final compiled language that this edge represents.
	// Note that the charsets in the final language are NOT the same as the
	// charsets defined in the grammar.
	int langCharSetId = -1;
	
	this(FSMState!fsmType target, dchar input, string origCharSetName="")
	{
		this.input = input;
		this.target = target;
		this.origCharSetName = origCharSetName;
	}
	
	static if(fsmType == FSMType.NFA)
	this(FSMState!fsmType target)
	{
		this(target, dchar.init);
	}
}

struct FSM(FSMType fsmType)
{
	FSMState!fsmType start;
	FSMState!fsmType end; // 'end' isn't actually used for DFAs
	
	static FSM!fsmType newClosed(dchar input=dchar.init)
	{
		auto fsm = FSM!fsmType.newOpen();
		fsm.start.edges = [FSMEdge!fsmType(fsm.end, input)];
		return fsm;
	}
	
	static FSM!fsmType newOpen()
	{
		FSM!fsmType fsm;
		fsm.start = new FSMState!fsmType();
		fsm.end   = new FSMState!fsmType();
		return fsm;
	}
	
	void ensureValid()
	{
		assert((start && end) || (!start && !end));
	}
}

NFA joinSerial(NFA a, NFA b, dchar input=dchar.init)
in
{
	a.ensureValid();
	b.ensureValid();
}
body
{
	if(!a.start && !a.end) return b;
	if(!b.start && !b.end) return a;

	a.end.edges ~= NFAEdge(b.start, input);
	return NFA(a.start, b.end);
}

NFA joinHeadsParallel(NFA a, NFA b)
{
	return joinParallelImpl(a, b, false);
}

NFA joinParallel(NFA a, NFA b)
{
	return joinParallelImpl(a, b, true);
}

private NFA joinParallelImpl(NFA a, NFA b, bool joinTails)
in
{
	a.ensureValid();
	b.ensureValid();
}
body
{
	if(!a.start && !a.end && !b.start && !b.end) return NFA.newOpen();
	if(!a.start && !a.end) return joinParallelImpl(NFA.newOpen(), b, joinTails);
	if(!b.start && !b.end) return joinParallelImpl(NFA.newOpen(), a, joinTails);
	
	a.start.edges ~= NFAEdge(b.start);
	if(joinTails)
		b.end.edges ~= NFAEdge(a.end);
	return a;
}

NFA applyKleene(NFA nfa, Kleene kleene)
in
{
	nfa.ensureValid();
	assert(nfa.start && nfa.end);
}
body
{
	void applyZero()
	{
		nfa.start.edges ~= NFAEdge(nfa.end);
	}
	void applyMore()
	{
		nfa.end.edges ~= NFAEdge(nfa.start);
	}

	final switch(kleene)
	{
	case Kleene.One:
		// Do nothing
		break;
		
	case Kleene.OneOrMore:
		applyMore();
		break;
		
	case Kleene.ZeroOrOne:
		applyZero();
		break;
		
	case Kleene.ZeroOrMore:
		applyZero();
		applyMore();
		break;
	}
	return nfa;
}

NFA charSetDataToNFA(dstring data, string charSetName="")
{
	auto nfa = NFA.newOpen();
	
	foreach(dchar ch; data)
		nfa.start.edges ~= NFAEdge(nfa.end, ch, charSetName);
	
	return nfa;
}

NFA toNFA(AST ast, ASTRegex regex)
{
	NFA nfa;
	foreach(seq; regex.seqs)
		nfa = joinParallel(nfa, toNFA(ast, seq));
	
	return nfa;
}

NFA toNFA(AST ast, ASTRegexSeq seq)
{
	NFA nfa;
	foreach(item; seq.items)
		nfa = joinSerial(nfa, toNFA(ast, item));

	return nfa;
}

NFA toNFA(AST ast, ASTRegexItem item)
{
	NFA nfa;
	auto cmp = Insensitive(null);
	
	if(item.regex)
		nfa = toNFA(ast, item.regex);
	else if(item.charSetLiteral)
		nfa = charSetDataToNFA( to!dstring(item.charSetLiteral) );
	else if(item.charSetName != cmp)
		nfa = charSetDataToNFA( ast.charSetNameToData(item.charSetName), item.charSetName.toString() );
	else if(item.termLiteral)
	{
		if(item.termLiteral.length > 0)
		{
			auto dstr = to!dstring(item.termLiteral);
			nfa = NFA.newClosed(dstr[0]);

			if(dstr.length > 1)
			foreach(dchar ch; dstr[1..$])
			{
				auto newEnd = new NFAState();
				nfa.end.edges = [ NFAEdge(newEnd, ch) ];
				nfa.end = newEnd;
			}
		}
	}
	
	return applyKleene(nfa, item.kleene);
}

/// Get all states that can be reached from the 'start' states without
/// consuming any input (including the 'start' states themselves).
NFAState[] closure(NFAState[] start)
{
	if(start.length == 1)
		return start[0].closure();
		
	NFAState[] ret;
	foreach(state; start)
		ret ~= state.closure();
	
	return array(uniq(sort(ret)));
}

dchar[] allUniqueInputs(NFAState[] states)
{
	bool[dchar] inputs;
	foreach(state; states)
	foreach(ref edge; state.edges)
	{
		//if(edge.input != dchar.init && find(ret, edge.input) == [])
		//	ret ~= edge.input;
		if(edge.input != dchar.init)
			inputs[edge.input] = true;
	}
	
	return inputs.keys;
}

NFAState[] nextStates(NFAState[] states, dchar input)
{
	NFAState[] ret;
	foreach(state; states)
	foreach(ref edge; state.edges)
	if(edge.input == input)
		ret ~= edge.target;
	
	return ret;
}

string toDOT(FSMType fsmType)(FSMState!fsmType[] allStates, AST ast)
in
{
	foreach(i, state; allStates)
		assert(i == state.id, "");
}
body
{
	auto dot = "digraph fsm {\n";
	dot ~= "	rankdir=LR;\n";
	dot ~= "	edge [ fontname=\"monospace\" fontsize=16 ];\n";
	
	string acceptStates = "	node [ fontname=\"monospace\" fontsize=14 shape=doubleoctagon ];\n";
	acceptStates ~= "	";
	bool foundAcceptState=false;
	foreach(state; allStates)
	if(state.acceptSymbolId != -1)
	{
		acceptStates ~= state.dotName;
		acceptStates ~= " ";
		foundAcceptState = true;
	}
	acceptStates ~= ";\n";
	if(foundAcceptState)
		dot ~= acceptStates;
	
	dot ~= "	node [ fontname=\"monospace\" fontsize=14 shape=circle ];\n";
	
	foreach(state; allStates)
		dot ~= toDOTEdges(allStates, state, ast);
	
	dot ~= "}\n";
	return dot;
}

private string toDOTEdges(FSMType fsmType)(FSMState!fsmType[] allStates, FSMState!fsmType state, AST ast)
{
	string dot = "";
	int[][long] inputTable;
	string[][long] charSetNameTable;
	foreach(ref edge; state.edges)
	{
		if(edge.langCharSetId != -1)
		{
			if(!(edge.target.id in inputTable))
				inputTable[edge.target.id] = [];
			
			inputTable[edge.target.id] ~= cast(int[])ast.rawCharSetTable[edge.langCharSetId];
		}
		else if(edge.input == dchar.init)
			dot ~= `	%s -> %s [ style=dashed color=red ];`.formatln(state.dotName, edge.target.dotName);
		else if(edge.origCharSetName != "" && edge.origCharSetName[0] != '&' && edge.origCharSetName[0] != '#')
		{
			if(!(edge.target.id in charSetNameTable))
				charSetNameTable[edge.target.id] = [];
			
			if( !contains(charSetNameTable[edge.target.id], edge.origCharSetName) )
				charSetNameTable[edge.target.id] ~= edge.origCharSetName;
		}
		else
		{
			if(!(edge.target.id in inputTable))
				inputTable[edge.target.id] = [];
			
			inputTable[edge.target.id] ~= cast(int)edge.input;
		}
	}
	
	// Convert int return values to bool
	// These need to be ASCII-only
	static if(useStdCType)
	{
		static bool isUpper(dchar ch) { return std.ctype.isupper(ch) != 0; }
		static bool isLower(dchar ch) { return std.ctype.islower(ch) != 0; }
		static bool isDigit(dchar ch) { return std.ctype.isdigit(ch) != 0; }
	}
	
	static bool isPunct(dchar ch) { return contains(`~!@#$%^*()_-+=\:;'<>.,?/`d, ch); }
	static bool isNamedPunct(dchar ch) { return contains(" \t\r\n\v\f{}&[]|`\"\&nbsp;"d, ch); }

	bool splitCond(int prevCh, int ch)
	{
		if(ch > prevCh + 1) return true;
		
		if(isUpper(ch) != isUpper(prevCh)) return true;
		if(isLower(ch) != isLower(prevCh)) return true;
		if(isDigit(ch) != isDigit(prevCh)) return true;
		if(isPunct(ch) || isPunct(prevCh)) return true;
		if(isNamedPunct(ch) || isNamedPunct(prevCh)) return true;
			
		return false;
	}
	
	int[2][][long] inputRangeTable;
	foreach(targetId, inputs; inputTable)
		inputRangeTable[targetId] = toRangedPairs!splitCond(inputs);
	
	string labelOfChar(int chCode, bool useBracketsOnEsc)
	{
		auto ch = cast(dchar)chCode;
		if(isUpper(ch) || isLower(ch) || isDigit(ch) || isPunct(ch))
			return text(ch);
		
		auto ret = "";
		if(useBracketsOnEsc) ret ~= "[";
		
		if(chCode == '[') ret ~= "LSqBracket";
		else if(chCode == ']' ) ret ~= "RSqBracket";
		else if(chCode == '{' ) ret ~= "LCurly";
		else if(chCode == '}' ) ret ~= "RCurly";
		else if(chCode == '|' ) ret ~= "Pipe";
		else if(chCode == '"' ) ret ~= "DblQuot";
		else if(chCode == '`' ) ret ~= "BackTick";
		else if(chCode == '&' ) ret ~= "Amp";
		else if(chCode == ' ' ) ret ~= "Sp";
		else if(chCode == '\t') ret ~= "Tab";
		else if(chCode == '\r') ret ~= "CR";
		else if(chCode == '\n') ret ~= "NL";
		else if(chCode == '\v') ret ~= "VT";
		else if(chCode == '\f') ret ~= "FF";
		else if(chCode == '\&nbsp;') ret ~= "NBSP";
		else
			ret ~= "%Xh".format(chCode);
		
		if(useBracketsOnEsc) ret ~= "]";
		return ret;
	}
	
	string[long] edgeLabels;
	foreach(targetId, charSetNames; charSetNameTable)
	foreach(name; charSetNames)
	{
		if(!(targetId in edgeLabels))
			edgeLabels[targetId] = "";

		edgeLabels[targetId] ~= "{";
		edgeLabels[targetId] ~= name;
		edgeLabels[targetId] ~= "}";
	}
	
	foreach(targetId, inputs; inputRangeTable)
	foreach(inPair; inputs)
	{
		if(!(targetId in edgeLabels))
			edgeLabels[targetId] = "";

		if(inPair[0] == inPair[1])
			edgeLabels[targetId] ~= labelOfChar(inPair[0], true);
		else
		{
			edgeLabels[targetId] ~= "[";
			edgeLabels[targetId] ~= labelOfChar(inPair[0], false);
			edgeLabels[targetId] ~= "-";
			edgeLabels[targetId] ~= labelOfChar(inPair[1], false);
			edgeLabels[targetId] ~= "]";
		}
	}
		
	foreach(targetId, label; edgeLabels)
	{
		//if(label.length > 50)
		//	label = label[0..20] ~ "..." ~ label[$-20..$];
			
		dot ~= `	%s -> %s [ label="%s" ];`.formatln(state.dotName, allStates[cast(uint)targetId].dotName, label);
	}
	return dot;
}
