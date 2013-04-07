@echo off

rem Check args
if "%1" == ""       goto showUsage
if "%1" == "--help" goto showUsage

call updateServerDocs "%1" "C:\Inetpub\wwwroot\goldie"

goto end

:showUsage

echo Usage:   updateServerDocs-example {version}
echo Example: updateServerDocs-example 0.5

:end
