@echo off
echo Bootstrapping STBuild...

move *.map obj > _junk_.junk 2> _junk_.junk2
del /Q _junk_.junk
del /Q _junk_.junk2
del /Q obj\*.*

rdmd --build-only --force -ofbin\semitwist-stbuild-bootstrap -odobj -Isrc -release -O src\semitwist\apps\stmanage\stbuild\main.d

move *.map obj > _junk_.junk 2> _junk_.junk2
del /Q _junk_.junk
del /Q _junk_.junk2
del /Q obj\*.*
