﻿/// This module was generated by the StaticLang tool from
/// Goldie v0.9: http://www.semitwist.com/goldie/

// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

module samples.calculatorStatic.calc.langHelper;

version = Goldie_StaticStyle;
private enum _packageName = "samples.calculatorStatic.calc";
private enum _shortPackageName = "calc";
version(Goldie_StaticStyle) {} else
	version = Goldie_DynamicStyle;

version(Goldie_StaticStyle)
{
	// This is a workaround for the cyclic dependency probelms in static constructors
	private extern(C) void language_calc_staticCtor();
	static this()
	{
		language_calc_staticCtor();
	}
}
