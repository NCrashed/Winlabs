@echo off

echo.
echo ================== Using: %1 ==================
echo.

rem call which dmd
dmd

del SemiTwistDTools\bin\semitwist-*.exe 2> NUL
del Goldie\bin\goldie-*.exe 2> NUL
del Goldie\tutorial\section3\commas.cgt 2> NUL
del Goldie\tutorial\sections5-6\commas.cgt 2> NUL
rmdir Goldie\tutorial\sections5-6\commas /S /Q 2> NUL
del Goldie\tutorial\sections5-6\*.exe 2> NUL

rem ./test/SemiTwistDTools/
cd SemiTwistDTools
call buildAll.bat all
bin\semitwist-unittests-debug

rem ./test/Goldie/
cd ..\Goldie
..\SemiTwistDTools\bin\semitwist-stbuild-debug all all -x=-I../SemiTwistDTools/src
bin\goldie-sampleGenericParse-debug lang/valid_sample2.calc lang/calc.cgt
call makeDocs.bat

rem ./test/Goldie/tutorial/section3/
echo Testing tutorial section3
cd tutorial\section3
..\..\bin\goldie-grmc-debug commas.grm
..\..\bin\goldie-staticlang-debug commas.cgt --pack=commas

rem ./test/Goldie/tutorial/sections5-6/
echo Testing tutorial sections5-6
cd ..\sections5-6
..\..\bin\goldie-grmc-debug commas.grm
..\..\bin\goldie-staticlang-debug commas.cgt --pack=commas

echo ...program1
rdmd --build-only -I../../../SemiTwistDTools/src -I../../src -ofprogram1 program1.d
program1 test.commas

echo ...program2
rdmd --build-only -I../../../SemiTwistDTools/src -I../../src -ofprogram2 program2.d
program2 test.commas
program2 test-different-sizes.commas
program2 test-out-of-range.commas

echo ...program3
rdmd --build-only -I../../../SemiTwistDTools/src -I../../src -ofprogram3 program3.d
program3 test.commas
program3 test-different-sizes.commas
program3 test-out-of-range.commas

rem ./test/
cd ..\..\..
