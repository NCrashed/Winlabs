//          Copyright Gushcha Anton 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)
module expression;

import exprparser.all;
import goldie.all;
import std.conv;
import std.math;
import std.container;
import std.range;

abstract class ExprTree
{
	this(size_t i = 0)
	{
		childs = new ExprTree[i];
	}

	double compute(double var);

	protected
	{
		ExprTree[] childs;
	}
}

class RootNode : ExprTree
{
	this()
	{
		super(1);
	}

	override double compute(double var)
	{
		return childs[0].compute(var);
	}
}

abstract class BinarNode : ExprTree
{
	this(ExprTree firstExpr, ExprTree secondExpr)
	{
		super();
		childs ~= firstExpr;
		childs ~= secondExpr;
	}

	ExprTree first() @property
	{
		return childs[0];
	}

	ExprTree second() @property
	{
		return childs[1];
	}	
}

class PlusNode : BinarNode
{
	this(ExprTree firstExpr, ExprTree secondExpr)
	{
		super(firstExpr, secondExpr);
	}

	override double compute(double var)
	{
		return first.compute(var) + second.compute(var);
	}
}

class MinusNode : BinarNode
{
	this(ExprTree firstExpr, ExprTree secondExpr)
	{
		super(firstExpr, secondExpr);
	}

	override double compute(double var)
	{
		return first.compute(var) - second.compute(var);
	}
}

class MultNode : BinarNode
{
	this(ExprTree firstExpr, ExprTree secondExpr)
	{
		super(firstExpr, secondExpr);
	}

	override double compute(double var)
	{
		return first.compute(var) * second.compute(var);
	}
}

class DivNode : BinarNode
{
	this(ExprTree firstExpr, ExprTree secondExpr)
	{
		super(firstExpr, secondExpr);
	}

	override double compute(double var)
	{
		return first.compute(var) / second.compute(var);
	}
}

class PowNode : BinarNode
{
	this(ExprTree firstExpr, ExprTree secondExpr)
	{
		super(firstExpr, secondExpr);
	}

	override double compute(double var)
	{
		return cast(double)pow(first.compute(var),second.compute(var));
	}
}

class VarNode : ExprTree
{
	this()
	{
		super();
	}

	override double compute(double var)
	{
		return var;
	}
}

class ConstNode : ExprTree
{
	this(double val)
	{
		super();
		this.val = val;
	}

	override double compute(double var)
	{
		return val;
	}

	protected
	{
		double val;
	}
}

class NegateNode : ExprTree
{
	this(ExprTree node)
	{
		super();
		childs ~= node;
	}

	override double compute(double var)
	{
		return -childs[0].compute(var);
	}
}

abstract class FunctionNode : ExprTree
{
	this(ExprTree[] nodes...)
	{
		super();
		foreach(node; nodes)
			childs ~= node;
	}
}

class SinusNode : FunctionNode
{
	this(ExprTree node)
	{
		super(node);
	}

	override double compute(double var)
	{
		return cast(double)sin(childs[0].compute(var));
	}
}

class CosinusNode : FunctionNode
{
	this(ExprTree node)
	{
		super(node);
	}

	override double compute(double var)
	{
		return cast(double)cos(childs[0].compute(var));
	}
}

class TangesNode : FunctionNode
{
	this(ExprTree node)
	{
		super(node);
	}

	override double compute(double var)
	{
		return cast(double)tan(childs[0].compute(var));
	}
}

class ASinusNode : FunctionNode
{
	this(ExprTree node)
	{
		super(node);
	}

	override double compute(double var)
	{
		return cast(double)asin(childs[0].compute(var));
	}
}

class ACosinusNode : FunctionNode
{
	this(ExprTree node)
	{
		super(node);
	}

	override double compute(double var)
	{
		return cast(double)acos(childs[0].compute(var));
	}
}

class ATangesNode : FunctionNode
{
	this(ExprTree node)
	{
		super(node);
	}

	override double compute(double var)
	{
		return cast(double)atan(childs[0].compute(var));
	}
}

class LogNode : FunctionNode
{
	this(ExprTree node1, ExprTree node2)
	{
		super(node1, node2);
	}

	override double compute(double var)
	{
		return cast(double)(log(childs[0].compute(var))/log(childs[1].compute(var)));
	}
}

//==================================================================================

class ExpressionException : Exception 
{
	this(string msg)
	{
		super(msg);
	}
}

alias Token_exprparser EToken;

ExprTree parseString(string str)
{
	ExprTree tree;
	try
	{
		auto parseTree = language_exprparser.parseCode(str).parseTree;
		tree = parseToken(parseTree);
	}
	catch(ParseException e)
	{
		throw new ExpressionException("Expression parsing failed: "~e.msg);
	}
	return tree;	
}

ConstNode parseToken(EToken!"<Real>" tok)
{
	return new ConstNode(to!double(tok.toString));
}

VarNode parseToken(EToken!"<Var>" tok)
{
	return new VarNode();
}

ExprTree parseToken(EToken!"<AdditionList>" tok)
{
	if(auto t = cast(EToken!("<AdditionList>", "<MultList>"))tok)
		return parseToken(t.sub!0);

	if(auto t = cast(EToken!("<AdditionList>", "<AdditionList>", "+", "<MultList>"))tok)
		return new PlusNode(parseToken(t.sub!0), parseToken(t.sub!2));

	if(auto t = cast(EToken!("<AdditionList>", "<AdditionList>", "-", "<MultList>"))tok)
		return new MinusNode(parseToken(t.sub!0), parseToken(t.sub!2));

	throw new Exception("Unhandled token: "~tok.name);
}

ExprTree parseToken(EToken!"<MultList>" tok)
{
	if(auto t = cast(EToken!("<MultList>", "<PowerList>"))tok)
		return parseToken(t.sub!0);

	if(auto t = cast(EToken!("<MultList>", "<MultList>", "*", "<PowerList>"))tok)
		return new MultNode(parseToken(t.sub!0), parseToken(t.sub!2));

	if(auto t = cast(EToken!("<MultList>", "<MultList>", "/", "<PowerList>"))tok)
		return new DivNode(parseToken(t.sub!0), parseToken(t.sub!2));

	throw new Exception("Unhandled token: "~tok.name);	
}

ExprTree parseToken(EToken!"<PowerList>" tok)
{
	if(auto t = cast(EToken!("<PowerList>", "<NegateExpr>"))tok)
		return parseToken(t.sub!0);

	if(auto t = cast(EToken!("<PowerList>", "<PowerList>", "^", "<NegateExpr>"))tok)
		return new PowNode(parseToken(t.sub!0), parseToken(t.sub!2));

	throw new Exception("Unhandled token: "~tok.name);	
}

ExprTree parseToken(EToken!"<NegateExpr>" tok)
{
	if(auto t = cast(EToken!("<NegateExpr>", "-", "<FuncList>"))tok)
	{
		return new NegateNode(parseToken(t.sub!1));
	}

	if(auto t = cast(EToken!("<NegateExpr>", "<FuncList>"))tok)
	{
		return parseToken(t.sub!0);
	}

	throw new Exception("Unhandled token: "~tok.name);
}

ExprTree parseToken(EToken!"<FuncList>" tok)
{
	if(auto t = cast(EToken!("<FuncList>", "<Real>"))tok)
		return parseToken(t.sub!0);

	if(auto t = cast(EToken!("<FuncList>", "<Var>"))tok)
		return parseToken(t.sub!0);	

	if(auto t = cast(EToken!("<FuncList>", "<Function>"))tok)
		return parseToken(t.sub!0);

	if(auto t = cast(EToken!("<FuncList>", "(", "<AdditionList>", ")"))tok)
		return parseToken(t.sub!1);

	throw new Exception("Unhandled token: "~tok.name);	
}

ExprTree parseToken(EToken!"<Function>" tok)
{
	string funcName = (tok.getRequired!(EToken!"Identifier")()).toString;
	EToken!"<ParamList>" paramsTok = tok.getRequired!(EToken!"<ParamList>")();
	if(funcName == "sin")
	{
		/*if(auto t = cast(EToken!("<ParamList>", "<ParamList>", ",", "<AdditionList>"))paramsTok)
		{
			if(auto t2 = cast(EToken!("<ParamList>", "<AdditionList>"))t.sub!0)
			{
				return new SinusNode(parseToken(t2.sub!0), parseToken(t.sub!2));
			}
		}*/
		if(auto t = cast(EToken!("<ParamList>", "<AdditionList>"))paramsTok)
		{
			return new SinusNode(parseToken(t.sub!0));
		}	
		throw new Exception("Sinus arity error!");
	} 
	else if(funcName == "cos")
	{
		if(auto t = cast(EToken!("<ParamList>", "<AdditionList>"))paramsTok)
		{
			return new CosinusNode(parseToken(t.sub!0));
		}	
		throw new Exception("Cosinus arity error!");
	}
	else if(funcName == "tan")
	{
		if(auto t = cast(EToken!("<ParamList>", "<AdditionList>"))paramsTok)
		{
			return new TangesNode(parseToken(t.sub!0));
		}	
		throw new Exception("Tanges arity error!");
	}	
	else if(funcName == "acos")
	{
		if(auto t = cast(EToken!("<ParamList>", "<AdditionList>"))paramsTok)
		{
			return new ACosinusNode(parseToken(t.sub!0));
		}	
		throw new Exception("Acosinus arity error!");
	}	
	else if(funcName == "asin")
	{
		if(auto t = cast(EToken!("<ParamList>", "<AdditionList>"))paramsTok)
		{
			return new ASinusNode(parseToken(t.sub!0));
		}	
		throw new Exception("Asinus arity error!");
	}	
	else if(funcName == "atan")
	{
		if(auto t = cast(EToken!("<ParamList>", "<AdditionList>"))paramsTok)
		{
			return new ATangesNode(parseToken(t.sub!0));
		}	
		throw new Exception("Atanges arity error!");
	}		
	else if(funcName == "log")
	{
		if(auto t = cast(EToken!("<ParamList>", "<ParamList>", ",", "<AdditionList>"))paramsTok)
		{
			if(auto t2 = cast(EToken!("<ParamList>", "<AdditionList>"))t.sub!0)
			{
				return new LogNode(parseToken(t2.sub!0), parseToken(t.sub!2));
			}
		}
		throw new Exception("Log arity error!");
	}
	else if(funcName == "ln")
	{
		if(auto t = cast(EToken!("<ParamList>", "<AdditionList>"))paramsTok)
		{
			return new LogNode(parseToken(t.sub!0), new ConstNode(cast(double)E));
		}	
		throw new Exception("Ln arity error!");
	}
	else if(funcName == "lb")
	{
		if(auto t = cast(EToken!("<ParamList>", "<AdditionList>"))paramsTok)
		{
			return new LogNode(parseToken(t.sub!0), new ConstNode(2.0));
		}	
		throw new Exception("Lb arity error!");
	}
	throw new Exception("Unhandled token: "~tok.name);
}

unittest
{
	import std.stdio;

	assert(parseString("2 + 2").compute(0.0) == 4.0);
	assert(parseString("2 + 2 * 2").compute(0.0) == 6.0);
	assert(parseString("2 + (2 + 5)").compute(0.0) == 9.0);
	assert(parseString("x + 2").compute(4.0) == 6.0);
	assert(parseString("sin( x ) + 1").compute(0.0) == 1.0);
	assert(parseString("2 ^ x + 2").compute(2.0) == 6.0);
}