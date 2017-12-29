@echo off

set    zip=btime.zip
set ifiles=aa04.9b+aa06.13b+aa05.10b+aa07.15b+aa12.7k+ab13.9k+ab10.10k+ab11.12k+aa8.13k+ab9.15k+ab00.1b+ab01.3b+ab02.4b+ab03.6b+ab14.12h
set  ofile=a.btime.rom

rem =====================================
setlocal ENABLEDELAYEDEXPANSION

set pwd=%~dp0
echo.
echo.

if EXIST %zip% (

	!pwd!7za x -otmp %zip%
	if !ERRORLEVEL! EQU 0 ( 
		cd tmp

		copy /b/y %ifiles% !pwd!%ofile%
		if !ERRORLEVEL! EQU 0 ( 
			echo.
			echo ** done **
			echo.
			echo Copy "%ofile%" into root of SD card
		)
		cd !pwd!
		rmdir /s /q tmp
	)

) else (

	echo Error: Cannot find "%zip%" file
	echo.
	echo Put "%zip%", "7za.exe" and "%~nx0" into the same directory
)

echo.
echo.
pause

