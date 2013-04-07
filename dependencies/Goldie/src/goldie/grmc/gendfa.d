// Goldie: GOLD Engine for D
// Grammar Compiler
// Written in the D programming language.

module goldie.grmc.gendfa;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.datetime;
import std.stdio;
import std.uni;
static import std.file;

import semitwist.util.all;
import goldie.base;
import goldie.grmc.ast;
import goldie.grmc.fsm;
import tools.util;

private AST ast;
private ASTTerminal[Insensitive] terminals;
private ASTCharSet[Insensitive] charSets;
private int initialDFAState;
private bool goldCompat; // GOLD-Compatibility Mode
private bool verbose;

version(GNU) private FSMState!(FSMType.NFA)[] nfaStates; // GDC workaround
else private NFAState[] nfaStates;

private _DFAState[] dfaRawStates;
private _DFAState[] dfaStates;

/// Generate a DFA table
public DFAState[] genDFATable(
	AST ast, out NFA nfa, out _DFA dfaRaw, out _DFA dfa,
	out NFAState[] nfaStates, out _DFAState[] dfaRawStates, out _DFAState[] dfaStates, 
	out int initialDFAState, out dstring[] charSetTable, bool goldCompat=false )
{
	.ast        = ast;
	.terminals  = ast.terminals;
	.charSets   = ast.charSets;
	.goldCompat = goldCompat;
	.verbose    = ast.verbose;

	nfa = genNFA();
	if(!ast.lang.caseSensitive)
		makeNFAInsensitive();
	if(ast.useMappingANSI)
		nfaApplyMappingANSI();

	dfaRaw = genDFA(nfa);
	dfa    = optimizeDFA(dfaRaw);
	charSetTable = genCharSets();
	
	initialDFAState = .initialDFAState;
	nfaStates       = .nfaStates;
	dfaRawStates    = .dfaRawStates;
	dfaStates       = .dfaStates;
	return genDFATable(dfa);
}

private NFA genNFA()
{
	mixin(verboseSection!"Generating NFA");

	NFA nfa;
	foreach(symName, sym; terminals)
	{
		if(
			sym.type != SymbolType.NonTerminal &&
			sym.type != SymbolType.EOF &&
			sym.type != SymbolType.Error
		)
		{
			auto subNFA = toNFA(ast, sym.regex);
			subNFA.end.acceptSymbolId = sym.id;
			if(sym.id >= 0)
				subNFA.end.acceptSymbolName = symName.toString();
			nfa = joinHeadsParallel(nfa, subNFA);
		}
	}
	
	if(!nfa.start && !nfa.end)
		nfa = NFA.newClosed();
	
	nfaStates = nfa.start.genIDs();
	ast.lang.nfaNumStates = cast(int)nfaStates.length;
	return nfa;
}

/+uint[][2] mappingPairs; // For "Character Mapping" = 'Windows-1252'
static this()
{
	uint[][2] mappingPairs = [
		[0x80, 0x20AC],
		[0x82, 0x201A],
		[0x83, 0x0192],
		[0x84, 0x201E],
		[0x85, 0x2026],
		[0x86, 0x2020],
		[0x87, 0x2021],
		[0x88, 0x02C6],
		[0x89, 0x2030],
		[0x8A, 0x0160],
		[0x8B, 0x2039],
		[0x8C, 0x0152],
		[0x91, 0x2018],
		[0x92, 0x2019],
		[0x93, 0x201C],
		[0x94, 0x201D],
		[0x95, 0x2022],
		[0x96, 0x2013],
		[0x97, 0x2014],
		[0x98, 0x02DC],
		[0x99, 0x2122],
		[0x9A, 0x0161],
		[0x9B, 0x203A],
		[0x9C, 0x0153],
		[0x9F, 0x0178],
	];
}+/

private dchar mapANSIToUni(dchar ch)
{
	// http://www.devincook.com/goldparser/doc/grammars/character-mapping.htm
	switch(ch)
	{
	case 0x80: return 0x20AC;
	case 0x82: return 0x201A;
	case 0x83: return 0x0192;
	case 0x84: return 0x201E;
	case 0x85: return 0x2026;
	case 0x86: return 0x2020;
	case 0x87: return 0x2021;
	case 0x88: return 0x02C6;
	case 0x89: return 0x2030;
	case 0x8A: return 0x0160;
	case 0x8B: return 0x2039;
	case 0x8C: return 0x0152;
	case 0x91: return 0x2018;
	case 0x92: return 0x2019;
	case 0x93: return 0x201C;
	case 0x94: return 0x201D;
	case 0x95: return 0x2022;
	case 0x96: return 0x2013;
	case 0x97: return 0x2014;
	case 0x98: return 0x02DC;
	case 0x99: return 0x2122;
	case 0x9A: return 0x0161;
	case 0x9B: return 0x203A;
	case 0x9C: return 0x0153;
	case 0x9F: return 0x0178;
	default:   return ch;
	}
}

private dchar mapUniToANSI(dchar ch)
{
	// http://www.devincook.com/goldparser/doc/grammars/character-mapping.htm
	switch(ch)
	{
	case 0x20AC: return 0x80;
	case 0x201A: return 0x82;
	case 0x0192: return 0x83;
	case 0x201E: return 0x84;
	case 0x2026: return 0x85;
	case 0x2020: return 0x86;
	case 0x2021: return 0x87;
	case 0x02C6: return 0x88;
	case 0x2030: return 0x89;
	case 0x0160: return 0x8A;
	case 0x2039: return 0x8B;
	case 0x0152: return 0x8C;
	case 0x2018: return 0x91;
	case 0x2019: return 0x92;
	case 0x201C: return 0x93;
	case 0x201D: return 0x94;
	case 0x2022: return 0x95;
	case 0x2013: return 0x96;
	case 0x2014: return 0x97;
	case 0x02DC: return 0x98;
	case 0x2122: return 0x99;
	case 0x0161: return 0x9A;
	case 0x203A: return 0x9B;
	case 0x0153: return 0x9C;
	case 0x0178: return 0x9F;
	default:     return ch;
	}
}

private struct CharMapper
{
	bool  function(dchar) isA;
	bool  function(dchar) isB;
	dchar function(dchar) toA;
	dchar function(dchar) toB;
}

void nfaAddMatchingChars(CharMapper mapper)
{
	foreach(state; nfaStates)
	{
		NFAEdge[] edgesToClone;
		foreach(edge; state.edges)
		if(mapper.isA(edge.input) || mapper.isB(edge.input))
			edgesToClone ~= edge;
		
		foreach(edge; edgesToClone)
		{
			auto ch = edge.input;
			auto newChar = mapper.isA(ch)? mapper.toB(ch) : mapper.toA(ch);
			
			if(newChar != ch)
			{
				NFAEdge newEdge = edge;
				newEdge.input = newChar;
				state.edges ~= newEdge;
			}
		}
	}
}

void makeNFAInsensitive()
{
	mixin(verboseSection!"Making NFA case insensitive");
	
	// Workarounds for DMD Issue #5768
	static if(__traits(compiles,
		()
		{
			auto x = std.uni.isUniLower('x');
			static assert(is(typeof(x)==int));
		}
	))
	{
		static bool isLower(dchar ch)
		{
			return isUniLower(ch)? true : false;
		}
		
		static bool isUpper(dchar ch)
		{
			return isUniUpper(ch)? true : false;
		}
	}
	
	CharMapper mapper;
	
	mapper.isA = &isLower;
	mapper.toA = &toUniLower;

	mapper.isB = &isUpper;
	mapper.toB = &toUniUpper;
	
	nfaAddMatchingChars(mapper);
}

void nfaApplyMappingANSI()
{
	mixin(verboseSection!"Applying Character Mapping to NFA");

	static bool isUni(dchar ch)
	{
		return mapUniToANSI(ch) != ch;
	}
	
	static bool isANSI(dchar ch)
	{
		return mapANSIToUni(ch) != ch;
	}

	CharMapper mapper;
	
	mapper.isA = &isUni;
	mapper.toA = &mapANSIToUni;

	mapper.isB = &isANSI;
	mapper.toB = &mapUniToANSI;
	
	nfaAddMatchingChars(mapper);
}

struct NFAStateSet
{
	NFAState[] states;
	
	//TODO: Clean up this and all other uses of useNoThrowSafeToHash
	//      once DMD 2.058 and below are no lonegr supported.
	static if(useNoThrowSafeToHash)
	{
		const nothrow @trusted hash_t toHash()
		{
			hash_t hash = states.length;
			foreach(state; states)
				hash = cast(hash_t)((hash << 7) | (hash >> ((hash_t.sizeof*8)-7)) ^ state.id);
			return hash;
		}
	}
	else
	{
		const hash_t toHash()
		{
			hash_t hash = states.length;
			foreach(state; states)
				hash = cast(hash_t)((hash << 7) | (hash >> ((hash_t.sizeof*8)-7)) ^ state.id);
			return hash;
		}
	}
	
	const int opCmp(ref const NFAStateSet b)
	{
		if(states.length > b.states.length) return 1;
		if(states.length < b.states.length) return -1;
		foreach(i; 0..states.length)
		{
			if(states[i].id > b.states[i].id) return 1;
			if(states[i].id < b.states[i].id) return -1;
		}
		return 0;
	}

	const bool opEquals(ref const NFAStateSet b)
	{
		return states == b.states;
	}
}

private _DFA genDFA(NFA nfa)
{
	mixin(verboseSection!"Converting NFA to DFA");

	void processAcceptStates(_DFAState state)
	{
		foreach(nfaState; state.nfaStates)
		if(nfaState.acceptSymbolId != -1)
		{
			if(state.acceptSymbolId == -1)
			{
				state.acceptSymbolId   = nfaState.acceptSymbolId;
				state.acceptSymbolName = nfaState.acceptSymbolName;
			}
			else
			{
				if(state.ambiguousAcceptIds.length == 0)
					state.ambiguousAcceptIds = [state.acceptSymbolId];

				if(find(state.ambiguousAcceptIds, nfaState.acceptSymbolId) == [])
					state.ambiguousAcceptIds ~= nfaState.acceptSymbolId;
			}
		}

		if(state.ambiguousAcceptIds.length > 1)
		{
			int highestPriority = 0;
			foreach(symId; state.ambiguousAcceptIds)
			{
				auto sym = ast.terminalFromId(symId);
				if(sym.priority > highestPriority)
					highestPriority = sym.priority;
			}
			
			if(highestPriority > 0)
			{
				typeof(state.ambiguousAcceptIds) newAcceptIds;
				
				foreach(symId; state.ambiguousAcceptIds)
				if(ast.terminalFromId(symId).priority == highestPriority)
					newAcceptIds ~= symId;
				
				state.ambiguousAcceptIds = newAcceptIds;
				
				// Successfully disambiguated?
				if(state.ambiguousAcceptIds.length == 1)
				{
					state.acceptSymbolId = state.ambiguousAcceptIds[0];
					state.acceptSymbolName = ast.symNameFromId(state.acceptSymbolId).toString();
					state.ambiguousAcceptIds = null;
				}
			}
		}
	}

	_DFA dfa;
	_DFAState[] todo;
	_DFAState[NFAStateSet] dfaStateLookup;

	dfa.start = new _DFAState();
	dfa.start.nfaStates = closure([nfa.start]);
	dfa.start.nfaStates = array(sort(dfa.start.nfaStates));
	foreach(nfaState; dfa.start.nfaStates)
	if(nfaState.acceptSymbolId != -1)
		ast.error(ast.parser.parseTreeX, text("Terminal '",nfaState.acceptSymbolName,"' can be zero-length"));

	//mixin(traceVal!("dfa.start.nfaStates.length"));
	//foreach(state; dfa.start.nfaStates)
	//	mixin(traceVal!("state.id"));
	
	todo = [dfa.start];
	dfaRawStates = [dfa.start];
	while(todo.length > 0)
	{
		// Pop state off todo
		auto state = todo[$-1];
		todo = todo[0..$-1];

		auto inputs = state.nfaStates.allUniqueInputs();
		foreach(input; inputs)
		{
			auto nfaStates = nextStates(state.nfaStates, input);
			nfaStates = closure(nfaStates);

			auto nfaStateSet = NFAStateSet(nfaStates);
			auto pExistingState = nfaStateSet in dfaStateLookup;
			if(pExistingState)
			{
				state.edges ~= _DFAEdge(*pExistingState, input);
				continue;
			}

			//mixin(traceVal!("nfaStates.length"));
			//foreach(nfaState; nfaStates)
			//	mixin(traceVal!("nfaState.id"));

			auto newState = new _DFAState();
			newState.nfaStates = nfaStates;
			state.edges ~= _DFAEdge(newState, input);
			todo ~= newState;
			dfaRawStates ~= newState;
			dfaStateLookup[nfaStateSet] = newState;
		}
	}
	
	foreach(state; dfaRawStates)
		processAcceptStates(state);

	foreach(state; dfaRawStates)
	if(state.ambiguousAcceptIds.length > 0)
	{
		string names = "";
		foreach(id; state.ambiguousAcceptIds)
		{
			if(names != "")
				names ~= " ";
			
			names ~= text("'", ast.lang.symbolTable[id].name, "'");
		}
		
		ast.error(
			ast.parser.parseTreeX,
			"Ambiguous terminals: "~names
		);
	}

	dfaRawStates = dfa.start.genIDs();
	enforce(
		dfaRawStates.length <= int.max,
		text("More DFA states than the CGT format can handle (failed: ",dfaRawStates.length," <= ",int.max,")")
	);
	
	//ast.lang.dfaRawNumStates = dfaRawStates.length;
	return dfa;
}

private dstring[] genCharSets()
{
	mixin(verboseSection!"Generating character sets");

	dstring[] table;
	
	foreach(state; dfaStates)
	{
		dstring[] inputTable;
		inputTable.length = dfaStates.length;
		foreach(ref edge; state.edges)
		{
			assert(edge.input != dchar.init);
			assert(find(inputTable[cast(uint)edge.target.id], edge.input) == []);
			
			inputTable[cast(uint)edge.target.id] ~= edge.input;
		}
		
		state.edges.length = 0;
		
		foreach(targetId, inputSet; inputTable)
		if(inputSet.length > 0)
		{
			inputSet = array(sort(inputSet.dup)).idup;
			dstring[] findResult = find(table, inputSet);
			auto newEdge = _DFAEdge(dfaStates[targetId], '\0');
			if(findResult == [])
			{
				table ~= inputSet;
				newEdge.langCharSetId = cast(int)table.length-1;
			}
			else
				newEdge.langCharSetId = cast(int)(table.length - findResult.length);

			state.edges ~= newEdge;
		}
	}
	
	return table;
}

private _DFA optimizeDFA(_DFA dfaRaw)
{
	//mixin(verboseSection!"Optimizing DFA");

	_DFA dfa;
	dfaStates = dfaRawStates;
	
	//TODO? Implement optimizeDFA
	
	return dfaRaw;
}

private DFAState[] genDFATable(_DFA dfa)
{
	mixin(verboseSection!"Generating final DFA table");

	DFAState[] table;
	
	initialDFAState = cast(int)dfa.start.id;
	table.length = dfaStates.length;
	foreach(state; dfaStates)
	{
		auto accept = state.acceptSymbolId != -1;
		auto acceptSymbolIndex = (state.acceptSymbolId == -1)? -1 : state.acceptSymbolId;
		table[cast(int)state.id] = DFAState(accept, acceptSymbolIndex);
		foreach(ref edge; state.edges)
			table[cast(int)state.id].edges ~= DFAStateEdge(edge.langCharSetId, cast(int)edge.target.id);
	}

	return table;
}
