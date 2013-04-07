@echo off

rem Check args
if "%1" == ""       goto showUsage
if "%1" == "--help" goto showUsage

call bin\goldie-updateServerDocs %*

goto end

:showUsage

echo Usage:   updateServerDocs {version}
echo Example: updateServerDocs 0.5

:end
