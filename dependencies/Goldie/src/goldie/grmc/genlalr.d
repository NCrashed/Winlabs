// Goldie: GOLD Engine for D
// Grammar Compiler
// Written in the D programming language.

module goldie.grmc.genlalr;

import std.conv;
import std.stdio;
import std.string;

import semitwist.util.all;
import goldie.base;
import goldie.grmc.ast;
import tools.util;

private AST ast;
private Symbol[] symbolTable;
private Rule[] ruleTable;
private int startRuleId;
private int startSymbolIndex;
private int eofSymbolIndex;
private int initialLALRState;
private bool goldCompat; // GOLD-Compatibility Mode
private bool verbose;

// The for each non-terminal, this contains an array of all terminals (their
// IDs) that the non-terminal can start with. /+Iff the non-terminal can derive
// "empty", then -1 is included in the list.+/
// symbolFirstTerminals[nonTerminalSymID] == array of terminal symbol IDs
private int[][] symbolFirstTerminals;
private bool[] symbolDerivesEmpty; // symbolDerivesEmpty[nonTerminalSymID]

private final class _LALRItem
{
	// -- Fields populated by genStates() ------

	int ruleId;
	
	// The value of this is position of the symbol immediately after the marker. Ie:
	//   marker == 0: Marker is at the beginning
	//   marker == theRule.subSymbolIndicies.length: Marker is at the end
	int marker;
	
	_LALRState stateOf;
	_LALRState gotoState;
	
	// -- Fields populated by genLookaheads() ------

	// IDs of the lookahead symbols
	bool[int] lookaheadIDs;
	
	// The items that directly inherit this item's lookahead symbols
	_LALRItem[] copyLookaheadsTo;

	// -- Funcs ------
	
	string toString(int id, int gotoStateId)
	{
		auto rule = ruleTable[ruleId];
		string str =
			"Item %s: Goto State %s: %s ::=".format(
				id,
				gotoStateId,
				symbolTable[rule.symbolIndex].name
			);

		foreach(index, subSymId; rule.subSymbolIndicies)
		{
			if(index == marker)
				str ~= " {DOT}";
			str ~= " ";
			str ~= symbolTable[subSymId].name;
		}
		
		if(marker == rule.subSymbolIndicies.length)
			str ~= " {DOT}";
		
		if(lookaheadIDs.length != 0)
		{
			str ~= "\n    LA:  ";
			foreach(currID, index; lookaheadIDs)
			{
				str ~= " ";
				str ~= symbolTable[currID].name;
			}
		}
		
		return str;
	}

	bool isIn(_LALRItem[] haystack)
	{
		foreach(item; haystack)
		{
			if(item.ruleId == ruleId && item.marker == marker)
				return true;
		}
		return false;
	}

	// ie, Immediately after
	@property bool isNonTerminalAfterMarker()
	{
		return
			symbolAfterMarker.id != -1 &&
			symbolAfterMarker.type == SymbolType.NonTerminal;
	}
	
	@property Symbol symbolAfterMarker()
	{
		if(marker >= rightHandSide.length)
			return Symbol("{Symbol Not Found}", SymbolType.Error, -1);
		
		return symbolTable[rightHandSide[marker]];
	}
	
	@property ref int[] rightHandSide()
	{
		return ruleTable[ruleId].subSymbolIndicies;
	}
	
	@property Symbol reducedSymbol()
	{
		return symbolTable[ruleTable[ruleId].symbolIndex];
	}
	
	// Prevents adding duplicates
	// Returns a bool indicating whether or not anything nothing was added
	bool addLookaheadIDs(T)(T ids) if( is(T==int[]) || is(T==bool[int]) )
	{
		bool added = false;
		foreach(key, value; ids)
		{
			static if( is(T==int[]) )
				auto newId = value;
			else
				auto newId = key;
			
			if(newId !in lookaheadIDs)
			{
				lookaheadIDs[newId] = true;
				added = true;
			}
		}
		return added;
	}
	
	// Returns a bool indicating whether or not anything nothing was added
	bool addLookaheadIDs()(int id)
	{
		bool added = false;
		if(id !in lookaheadIDs)
		{
			lookaheadIDs[id] = true;
			added = true;
		}
		return added;
	}
}

private final class _LALRState
{
	// Populated by genStates
	_LALRItem items[];
	
	// The number of items which were *not* determined by computing the closure
	// (ie, not added by entireStateOf).
	// The kernel items are always 'items[0..kernelSize]'
	size_t kernelSize;
	
	int id;
	
	bool[] hasShift; // hasShift[terminalSymbolId]
	
	string toString(_LALRState[] states)
	{
		string str = "State %s:".format(id);
		foreach(int itemId, item; items)
		{
			auto rule = ruleTable[item.ruleId];
			int gotoStateId=-1;
			foreach(int stateId, state; states)
			if(state is item.gotoState)
			{
				gotoStateId = stateId;
				break;
			}
			str ~= "\n" ~ indent(item.toString(itemId, gotoStateId), "  ");
		}
		return str;
	}
}

/// Generate an LALR table
public LALRState[] genLALRTable(
	AST ast, Symbol[] symbolTable, Rule[] ruleTable,
	int startSymbolIndex, int eofSymbolIndex,
	out int initialLALRState, bool goldCompat=false)
{
	auto rootSymbolId = cast(int)symbolTable.length;
	startRuleId = cast(int)ruleTable.length;
	symbolTable ~= Symbol("<S'>", SymbolType.NonTerminal, rootSymbolId);
	ruleTable ~= Rule(rootSymbolId, [startSymbolIndex, eofSymbolIndex]);
	startSymbolIndex = rootSymbolId;
	
	.ast              = ast;
	.symbolTable      = symbolTable;
	.ruleTable        = ruleTable;
	.startSymbolIndex = startSymbolIndex;
	.eofSymbolIndex   = eofSymbolIndex;
	.goldCompat       = goldCompat;
	.verbose          = ast.verbose;

	_LALRState[] states = genStates();
	precomputeHelperData(states);
	precomputeFirstTerminals(states);
	genLookaheads(states);

	//foreach(state; states)
	//	writeln(state.toString(states));

	initialLALRState = .initialLALRState;
	return genFinalTable(states);
}

private _LALRState[] genStates()
{
	mixin(verboseSection!"Generating LALR states");

	_LALRState[] states;
	_LALRState[] statesToProcess;

	bool isStartingItemOfRuleIn(int ruleId, _LALRItem[] items)
	{
		foreach(item; items)
		{
			if(item.marker == 0 && item.ruleId == ruleId)
				return true;
		}
		return false;
	}
	
	// Return all items that belong in the same state as the given starting items.
	// Parsing theory books usually call this the "closure" of the items.
	_LALRItem[] entireStateOf(_LALRItem[] items)
	{
		bool foundNewItems;
		auto updatedItems = items;
		items = [];
		do
		{
			foundNewItems = false;
			auto oldNumItems = items.length;
			items = updatedItems;
			foreach(i, item; items[oldNumItems..$])
			{
				if(item.isNonTerminalAfterMarker)
				foreach(int ruleId, rule; ruleTable)
				if(rule.symbolIndex == item.symbolAfterMarker.id)
				if(!isStartingItemOfRuleIn(ruleId, items))
				{
					auto newItem = new _LALRItem();
					newItem.ruleId = ruleId;
					newItem.marker = 0;
					updatedItems ~= newItem;
					
					foundNewItems = true;
				}
			}
		} while(foundNewItems);

		return updatedItems;
	}
	
	_LALRState findExistingState(_LALRState state)
	{
		foreach(stateId, currState; states)
		if(currState.kernelSize == state.items.length)
		{
			bool matches=true;
			foreach(stateItem; state.items)
			{
				if(!stateItem.isIn(currState.items[0..currState.kernelSize]))
				{
					matches = false;
					break;
				}
			}
			if(matches)
				return currState;
		}
		
		return null;
	}
	
	_LALRState addState(_LALRState state)
	{
		auto existingState = findExistingState(state);

		if(existingState)
			return existingState;
		else
		{
			state.kernelSize = state.items.length;
			state.id = cast(int)states.length;
			states ~= state;
			statesToProcess ~= state;
			return state;
		}
	}
	
	_LALRState nextStateOf(_LALRState currState, int symId)
	{
		_LALRState newState;
		
		foreach(currItem; currState.items)
		if(currItem.symbolAfterMarker.id == symId)
		{
			// For consitency with GOLD, don't bother making state for:
			//    <S'> ::= {"Start Symbol"} EOF {DOT}
			if(symId == eofSymbolIndex && currItem.ruleId == startRuleId && currItem.marker == 1)
				return null;

			auto newItem = new _LALRItem();
			newItem.ruleId = currItem.ruleId;
			newItem.marker = currItem.marker+1;
		
			if(newState is null)
				newState = new _LALRState();
			
			bool itemAlreadyExists=false;
			foreach(nsi; newState.items)
			if(nsi.ruleId == newItem.ruleId && nsi.marker == newItem.marker)
				itemAlreadyExists = true;
			
			if(!itemAlreadyExists)
				newState.items ~= newItem;
		}
		
		return newState;
	}
	
	auto startState = new _LALRState();
	foreach(int ruleId, rule; ruleTable)
	if(rule.symbolIndex == startSymbolIndex)
	{
		startState.items ~= new _LALRItem();
		startState.items[$-1].ruleId = ruleId;
		startState.items[$-1].marker = 0;
	}
	addState(startState);
	initialLALRState = 0;
	
	while(statesToProcess.length > 0)
	{
		auto currState = statesToProcess[0];
		statesToProcess = statesToProcess[1..$];
		
		currState.items = entireStateOf(currState.items);

		foreach(int symId, sym; symbolTable)
		{
			auto nextState = nextStateOf(currState, symId);

			if(nextState !is null)
			{
				auto gotoState = addState(nextState);
			
				foreach(currItem; currState.items)
				if(currItem.symbolAfterMarker.id == symId)
					currItem.gotoState = gotoState;
			}
		}
	}

	return states;
}

private void precomputeHelperData(_LALRState[] states)
{
	mixin(verboseSection!"Precomputing LALR helper data");

	foreach(state; states)
	{
		// Set 'stateOf' member for items
		foreach(item; state.items)
			item.stateOf = state;

		// Find shift actions
		state.hasShift.length = ast.firstNonTerminalId;
		foreach(item; state.items)
		if(item.gotoState !is null && !item.isNonTerminalAfterMarker)
			state.hasShift[item.symbolAfterMarker.id] = true;
	}
}
	
// Find the "first terminals" for each non-terminal
private void precomputeFirstTerminals(_LALRState[] states)
{
	mixin(verboseSection!"Precomputing first terminals");

	int[][] ruleFirstTerminals;
	bool [] ruleDerivesEmpty;
	
	symbolFirstTerminals .length = symbolTable.length;
	symbolDerivesEmpty   .length = symbolTable.length;
	ruleFirstTerminals   .length = ruleTable.length;
	ruleDerivesEmpty     .length = ruleTable.length;

	// Returns: Added element?
	static bool addToSet(ref int[] set, int newElem)
	{
		foreach(existingElem; set)
		if(existingElem == newElem)
			return false;

		set ~= newElem;
		return true;
	}
	
	// Returns: Added any elements?
	static bool addAllToSet(ref int[] set, int[] newElems)
	{
		bool added = false;
		foreach(elem; newElems)
		{
			if(addToSet(set, elem))
				added = true;
		}
		return added;
	}

	bool propagatedTerminals;
	
	void processSymbol()(int symId)
	{
		if(symbolTable[symId].type == SymbolType.NonTerminal)
		{
			symbolDerivesEmpty[symId] = false;
			
			foreach(ruleId, rule; ruleTable) if(rule.symbolIndex == symId)
			{
				if(addAllToSet(symbolFirstTerminals[symId], ruleFirstTerminals[ruleId]))
					propagatedTerminals = true;

				if(ruleDerivesEmpty[ruleId])
					symbolDerivesEmpty[symId] = true;
			}
		}
		else
		{
			symbolFirstTerminals[symId] = [symId];
			symbolDerivesEmpty[symId] = false;
		}
	}
	
	// Finds all the terminals that could possibly be first
	// in the derivation of the rule provided.
	void processRule(int ruleId)
	{
		ruleDerivesEmpty[ruleId] = true;
		foreach(symId; ruleTable[ruleId].subSymbolIndicies)
		{
			if(addAllToSet(ruleFirstTerminals[ruleId], symbolFirstTerminals[symId]))
				propagatedTerminals = true;

			if(!symbolDerivesEmpty[symId])
			{
				ruleDerivesEmpty[ruleId] = false;
				break;
			}
		}
	}

	do
	{
		propagatedTerminals = false;

		foreach(int symId, sym; symbolTable)
			processSymbol(symId);

		foreach(int ruleId, rule; ruleTable)
			processRule(ruleId);

	} while(propagatedTerminals);
}

/// This also detects/reports shift-reduce conflicts,
/// and resolves them by assuming "shift".
private void genLookaheads(_LALRState[] states)
{
	_LALRItem[] findItems(int ruleId, int marker)
	{
		_LALRItem[]	ret;
		
		foreach(state; states)
		foreach(item; state.items)
		if(item.ruleId == ruleId && item.marker == marker)
			ret ~= item;

		return ret;
	}
	
	// Returns all the terminals that could possibly be first
	// in the derivation of the sequence provided.
	int[] allFirstTerminals(int[] symbolIDs)
	{
		int[] firstIDs;
		
		void addFirst(int id)
		{
			foreach(existingId; firstIDs)
			if(existingId == id)
				return;

			firstIDs ~= id;
		}
		
		void addFirsts(int[] ids)
		{
			foreach(id; ids)
				addFirst(id);
		}
		
		foreach(symId; symbolIDs)
		{
			addFirsts(symbolFirstTerminals[symId]);
			if(!symbolDerivesEmpty[symId])
				break;
		}
		
		return firstIDs;
	}

	// Can all of the provided symbols derive empty?
	bool allCanDeriveEmpty(int[] symbolIDs)
	{
		foreach(symId; symbolIDs)
		if(!symbolDerivesEmpty[symId])
			return false;
		
		return true;
	}

	int[][][] shiftReduceConflicts;

	void shiftReduceConflict(int stateId, int symId, int ruleId)
	{
		foreach(existingRuleId; shiftReduceConflicts[stateId][symId])
		if(existingRuleId == ruleId)
			return;
		
		shiftReduceConflicts[stateId][symId] ~= ruleId;
	}

	shiftReduceConflicts.length = states.length;
	foreach(ref conflicts; shiftReduceConflicts)
		conflicts.length = ast.firstNonTerminalId;
	
	// "Spontaneously generated" lookaheads
	{
		mixin(verboseSection!"Spontaneously generating LALR lookaheads");

		foreach(int stateId, state; states)
		foreach(item; state.items)
		{
			auto rhs = ruleTable[item.ruleId].subSymbolIndicies;

			if(item.symbolAfterMarker.id != -1)
			{
				// Make note that lookaheads will propagate with the advancement of the marker
				if(item.gotoState !is null)
				foreach(item2; item.gotoState.items)
				if(item.ruleId == item2.ruleId && item.marker+1 == item2.marker)
					item.copyLookaheadsTo ~= item2;

				// Suppose this state contains these items:
				//    <A> ::= <B> {DOT} <C> <D> <E>  (ie 'item')
				//    <C> ::= {DOT} <F> <G>          (ie 'item2')
				//
				// Then:
				//
				// 1. Every terminal that can be the beginning of "<D> <E>"
				//    is "spontaneously generated" to be a lookahead
				//    for 'item2', ie "<C> ::= ..."
				// 
				// 2. If "<C> <D>" can be (ie, "derive") "nothing", then
				//    make note that lookaheads will propagate from 'item'
				//    to 'item2'
				if(item.isNonTerminalAfterMarker)
				foreach(item2; state.items)
				if(item2.marker == 0 && item2.reducedSymbol == item.symbolAfterMarker)
				{
					auto rhsTail = rhs[item.marker+1..$];
					auto firstTerminals = allFirstTerminals(rhsTail);

					foreach(firstTermIndex, int firstTermSymId; firstTerminals)
					{
						// Check for and handle shift-reduce conflicts:
						//
						// If this is a reduce action, check if this state
						// already has a shift for it. If so, it's a
						// shift-reduce conflict and we'll handle it here.
						if(item2.gotoState is null) // Is item2 a reduce action?
						{
							// Is there an existing shift this reduce conflicts with?
							if(state.hasShift[firstTermSymId])
							{
								shiftReduceConflict(stateId, firstTermSymId, item2.ruleId);
								
								// Resolve conflict by skipping this lookahead for reduce
								continue;
							}
						}
						
						// Add new lookaheads
						item2.addLookaheadIDs(firstTermSymId);
					}
					
					// Make note of propagation
					if(allCanDeriveEmpty(rhsTail))
						item.copyLookaheadsTo ~= item2;
				}
			}
		}
	}
	
	// "Propagated" lookaheads
	{
		mixin(verboseSection!"Propagating LALR lookaheads");

		bool propagatedNewLookaheads = true;
		while(propagatedNewLookaheads)
		{
			propagatedNewLookaheads = false;
			foreach(state; states)
			foreach(item; state.items)
			foreach(targetItem; item.copyLookaheadsTo)
			{
				foreach(int lookaheadSymId, bool dummy; item.lookaheadIDs)
				{
					// Check for and handle shift-reduce conflicts:
					// Intra-state conflics were already handled while
					// spontaneously-generating lookaheads
					if(state != targetItem.stateOf)
					if(targetItem.gotoState is null) // Is targetItem a reduce action?
					{
						// Is there an existing shift this reduce conflicts with?
						if(targetItem.stateOf.hasShift[lookaheadSymId])
						{
							//foundConflict = true;
							shiftReduceConflict(
								targetItem.stateOf.id,
								lookaheadSymId,
								targetItem.ruleId
							);
							
							// Resolve conflict by not propagating this lookahead for reduce
							continue;
						}
					}
					
					// Propagate lookaheads
					auto added = targetItem.addLookaheadIDs(lookaheadSymId);
					if(added)
						propagatedNewLookaheads = true;
				}
			}
		}
	}
	
	// Report shift-reduce conflicts
	foreach(stateId, elemState; shiftReduceConflicts)
	foreach(symId, elemSym; elemState)
	if(elemSym.length > 0)
	{
		string rulesStr;
		foreach(ruleId; elemSym)
		{
			rulesStr ~= "\n    ";
			rulesStr ~= ast.lang.ruleToString(ruleId);
		}
		
		ast.warning(
			ast.parser.parseTreeX,
			("Shift-Reduce conflict, assuming shift:\n"~
			"  In LALR State #%s\n"~
			"  Either shift: %s\n"~
			"  Or reduce a rule: %s\n")
				.format(stateId, symbolTable[symId].name, rulesStr)
		);
	}
}

private LALRState[] genFinalTable(_LALRState[] states)
{
	mixin(verboseSection!"Generating final LALR table");

	LALRState[] lalrTable;
	lalrTable.length = states.length;
	
	void addAction(int stateId, LALRAction newAction)
	{
		foreach(action; lalrTable[stateId].actions)
		if(action == newAction)
			return;
		
		lalrTable[stateId].actions ~= newAction;
	}
	
	foreach(int stateId, state; states)
	foreach(item; state.items)
	{
		// Accept
		if(item.ruleId == startRuleId && item.marker == 1)
		{
			addAction(stateId, LALRAction(eofSymbolIndex, LALRAction.Type.Accept, 0));
			continue;
		}

		// Reduce
		if(item.gotoState is null)
		{
			foreach(int lookaheadID, index; item.lookaheadIDs)
				addAction(stateId, LALRAction(lookaheadID, LALRAction.Type.Reduce, item.ruleId));

			continue;
		}
		
		// Goto
		auto sym = item.symbolAfterMarker;
		if(sym.type == SymbolType.NonTerminal)
		{
			addAction(stateId, LALRAction(sym.id, LALRAction.Type.Goto, item.gotoState.id));
			continue;
		}

		// Shift
		addAction(stateId, LALRAction(sym.id, LALRAction.Type.Shift, item.gotoState.id));
	}

	if(goldCompat)
		sortFinalTable(lalrTable);

	return lalrTable;
}

// For GOLD compatibility mode
public void sortFinalTable(ref LALRState[] lalrTable)
{
	int[] findActions(LALRAction[] actions, LALRAction.Type type)
	{
		int[] ret;
		
		foreach(int index, action; actions)
		if(action.type == type)
			ret ~= index;
		
		return ret;
	}
	
	int[] sortActions(LALRAction[] actions, int[] oldOrder)
	{
		int[] newOrder;
		while(oldOrder.length > 0)
		{
			int firstSymId = int.max;
			int firstValue;
			int firstIndex;
			foreach(int index, value; oldOrder)
			{
				auto symId = actions[value].symbolId;
				if(symId < firstSymId)
				{
					firstSymId = symId;
					firstValue = value;
					firstIndex = index;
				}
			}
			
			newOrder ~= firstValue;
			oldOrder =
				oldOrder[0..firstIndex] ~
				(firstIndex < oldOrder.length-1 ? oldOrder[firstIndex+1..$] : []);
		}
		return newOrder;
	}
	
	// Order: Accept, Shift, Goto, Reduce
	foreach(stateId; 0..lalrTable.length)
	{
		auto oldActions = lalrTable[stateId].actions.dup;
		int[] newAccepts = sortActions( oldActions, findActions(oldActions, LALRAction.Type.Accept) );
		int[] newShifts  = sortActions( oldActions, findActions(oldActions, LALRAction.Type.Shift ) );
		int[] newGotos   = sortActions( oldActions, findActions(oldActions, LALRAction.Type.Goto  ) );
		int[] newReduces = sortActions( oldActions, findActions(oldActions, LALRAction.Type.Reduce) );
		
		auto newOrder = newAccepts ~ newShifts ~ newGotos ~ newReduces;
		lalrTable[stateId].actions.length = 0;
		foreach(index; newOrder)
			lalrTable[stateId].actions ~= oldActions[index];
	}
}
