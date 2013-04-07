@echo off

if not exist "test-cache" (

	echo Exporting Goldie/SemiTwistDTools masters from version control...
	echo These will be cached. To download them again,
	echo delete the 'test-cache' directory.

	rem ./test-cache/
	mkdir test-cache
	cd test-cache
	
	call git clone https://bitbucket.org/Abscissa/semitwistdtools.git SemiTwistDTools
	call git clone https://bitbucket.org/Abscissa/goldie.git Goldie

	rem Cleanup Git's droppings:
	rmdir SemiTwistDTools\.git /S /Q 2> NUL
	del SemiTwistDTools\.gitignore
	rmdir Goldie\.git /S /Q 2> NUL
	del Goldie\.gitignore

	rem ./
	cd ..
)

rem ./test/
rmdir test /S /Q 2> NUL
xcopy test-cache test /E /I /Q /H /K /Y
cd test

set GOLDIE_SAVE_PATH=%PATH%

call dvm use 2.055
call ..\runTestsHelper.bat "DMD 2.055"
set PATH=%GOLDIE_SAVE_PATH%

call dvm use 2.056
call ..\runTestsHelper.bat "DMD 2.056"
set PATH=%GOLDIE_SAVE_PATH%

call dvm use 2.057
call ..\runTestsHelper.bat "DMD 2.057"
set PATH=%GOLDIE_SAVE_PATH%

call dvm use 2.058
call ..\runTestsHelper.bat "DMD 2.058"
set PATH=%GOLDIE_SAVE_PATH%

call dvm use 2.059
call ..\runTestsHelper.bat "DMD 2.059"
set PATH=%GOLDIE_SAVE_PATH%

rem ./
cd ..
echo Done testing.
