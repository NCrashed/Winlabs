// Goldie: GOLD Engine for D
// GoldieLib
// Written in the D programming language.

module /+S:PACKAGE+/goldie/+E:PACKAGE+/.langHelper;

/+P:INIT_STATIC_LANG+/
version(Goldie_StaticStyle) {} else
	version = Goldie_DynamicStyle;

version(Goldie_StaticStyle)
{
	// This is a workaround for the cyclic dependency probelms in static constructors
	private extern(C) void /+P:LANG_INSTNAME+/_staticCtor();
	static this()
	{
		/+P:LANG_INSTNAME+/_staticCtor();
	}
}
