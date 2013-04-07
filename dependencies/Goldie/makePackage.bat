@echo off

rem Check args
if "%1" == ""       goto showUsage
if "%1" == "--help" goto showUsage

rem ./release/
rmdir release /S /Q 2> NUL
mkdir release
cd release

call git clone https://bitbucket.org/Abscissa/semitwistdtools.git SemiTwistDTools
call git clone https://bitbucket.org/Abscissa/goldie.git Goldie

rem Cleanup Git's droppings:
rmdir SemiTwistDTools\.git /S /Q 2> NUL
del SemiTwistDTools\.gitignore
rmdir Goldie\.git /S /Q 2> NUL
del Goldie\.gitignore

rem ./release/SemiTwistDTools/
cd SemiTwistDTools
call buildAll.bat all
bin\semitwist-unittests-debug

rem ./release/Goldie/
cd ..\Goldie
mkdir ..\PublicDocs
mkdir ..\PublicDocs\docs
xcopy /E /Q /Y /I docs ..\PublicDocs\docs
..\SemiTwistDTools\bin\semitwist-stbuild-debug all all
call makeDocs.bat
call makeDocs.bat --trimlink --od=..\PublicDocs

rem ./release/
cd ..
rmdir SemiTwistDTools\obj /S /Q 2> NUL
mkdir SemiTwistDTools\obj
rmdir Goldie\obj /S /Q 2> NUL
mkdir Goldie\obj

7z a -bd Goldie-v%1-windows-%2.7z SemiTwistDTools Goldie

rem ./
cd ..
echo Done packaging.

goto end

:showUsage

echo Usage:   makePackage {ver} {arch}
echo Example: makePackage 0.5 x86

:end
