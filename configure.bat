@echo OFF
@setlocal

set VERSION=2.4.0
set TFDIR=C:\TreeFrog\%VERSION%
set MONBOC_VERSION=1.21.2
set LZ4_VERSION=1.9.3
set BASEDIR=%~dp0

:parse_loop
if "%1" == "" goto :start
if /i "%1" == "--prefix" goto :prefix
if /i "%1" == "--enable-debug" goto :enable_debug
if /i "%1" == "--enable-gui-mod" goto :enable_gui_mod
if /i "%1" == "--help" goto :help
if /i "%1" == "-h" goto :help
goto :help
:continue
shift
goto :parse_loop


:help
  echo Usage: %0 [OPTION]... [VAR=VALUE]...
  echo;
  echo Configuration:
  echo   -h, --help          display this help and exit
  echo   --enable-debug      compile with debugging information
  echo   --enable-gui-mod    compile and link with QtGui module
  echo;
  echo Installation directories:
  echo   --prefix=PREFIX     install files in PREFIX [%TFDIR%]
  goto :exit

:prefix
  shift
  if "%1" == "" goto :help
  set TFDIR=%1
  goto :continue

:enable_debug
  set DEBUG=yes
  goto :continue

:enable_gui_mod
  set USE_GUI=use_gui=1
  goto :continue

:start
if "%DEBUG%" == "yes" (
  set OPT="CONFIG+=debug"
) else (
  set OPT="CONFIG+=release"
)

::
:: Generates tfenv.bat
::
for %%I in (qmake.exe)  do if exist %%~$path:I set QMAKE=%%~$path:I
for %%I in (cmake.exe)  do if exist %%~$path:I set CMAKE=%%~$path:I
for %%I in (cl.exe)     do if exist %%~$path:I set MSCOMPILER=%%~$path:I
for %%I in (devenv.com) do if exist %%~$path:I set DEVENV=%%~$path:I

if "%QMAKE%" == "" (
  echo Qt environment not found
  exit /b
)
if "%CMAKE%" == "" (
  echo CMake not found
  exit /b
)
if "%MSCOMPILER%" == "" if "%DEVENV%"  == "" (
  echo Visual Studio compiler not found
  exit /b
)

:: vcvarsall.bat setup
set MAKE=nmake
if /i "%Platform%" == "x64" (
  set VCVARSOPT=amd64
  set BUILDTARGET=x64
  set ENVSTR=Environment to build for 64-bit executable  MSVC / Qt
) else (
  set VCVARSOPT=x86
  set BUILDTARGET=win32
  set ENVSTR=Environment to build for 32-bit executable  MSVC / Qt
)

"%DEVENV%" /? | find "Visual Studio 2022" >NUL
if not ERRORLEVEL 1 (
  set VSVER=2022
  if /i "%Platform%" == "x64" (
    set CMAKEOPT=-G"Visual Studio 17 2022" -A x64
  ) else (
    set CMAKEOPT=-G"Visual Studio 17 2022" -A Win32
  )
  goto :step2
)

"%DEVENV%" /? | find "Visual Studio 2019" >NUL
if not ERRORLEVEL 1 (
  set VSVER=2019
  if /i "%Platform%" == "x64" (
    set CMAKEOPT=-G"Visual Studio 16 2019" -A x64
  ) else (
    set CMAKEOPT=-G"Visual Studio 16 2019" -A Win32
  )
  goto :step2
)

"%DEVENV%" /? | find "Visual Studio 2017" >NUL
if not ERRORLEVEL 1 (
  set VSVER=2017
  if /i "%Platform%" == "x64" (
    set CMAKEOPT=-G"Visual Studio 15 2017 Win64"
  ) else (
    set CMAKEOPT=-G"Visual Studio 15 2017"
  )
  goto :step2
)

"%DEVENV%" /? | find "Visual Studio 2015" >NUL
if not ERRORLEVEL 1 (
  set VSVER=2015
  if /i "%Platform%" == "x64" (
    set CMAKEOPT=-G"Visual Studio 14 2015 Win64"
  ) else (
    set CMAKEOPT=-G"Visual Studio 14 2015"
  )
  goto :step2
)


:step2
SET /P X="%ENVSTR%"<NUL
qtpaths.exe --qt-version

for %%I in (qtenv2.bat) do if exist %%~$path:I set QTENV=%%~$path:I
set TFENV=tfenv.bat
echo @echo OFF> %TFENV%
echo ::>> %TFENV%
echo :: This file is generated by configure.bat>> %TFENV%
echo ::>> %TFENV%
echo;>> %TFENV%
echo set TFDIR=%TFDIR%>> %TFENV%
echo set TreeFrog_DIR=%TFDIR%>> %TFENV%
echo set QTENV="%QTENV%">> %TFENV%
echo set QMAKESPEC=%QMAKESPEC%>> %TFENV%
echo set VCVARSBAT="">> %TFENV%
echo set VSVER=%VSVER%>> %TFENV%
echo set VSWHERE="%%ProgramFiles(x86)%%\Microsoft Visual Studio\Installer\vswhere.exe">> %TFENV%
echo;>> %TFENV%
echo if exist %%QTENV%% call %%QTENV%%>> %TFENV%
echo if exist %%VSWHERE%% ^(>> %TFENV%
echo   for /f "usebackq tokens=*" %%%%i in ^(`%%VSWHERE%% -find  **\vcvarsall.bat`^) do ^(>> %TFENV%
echo     echo %%%%i ^| find "%%VSVER%%" ^>NUL>> %TFENV%
echo     if not ERRORLEVEL 1 ^(>> %TFENV%
echo       set VCVARSBAT="%%%%i">> %TFENV%
echo       goto :break>> %TFENV%
echo     ^)>> %TFENV%
echo   ^)>> %TFENV%
echo ^)>> %TFENV%
echo :break>> %TFENV%
echo if exist %%VCVARSBAT%% ^(>> %TFENV%
echo   echo Setting up environment for MSVC usage...>> %TFENV%
echo   call %%VCVARSBAT%% %VCVARSOPT%>> %TFENV%
echo ^)>> %TFENV%
echo set PATH=%%TFDIR^%%\bin;%%PATH%%>> %TFENV%
echo echo Setup a TreeFrog/Qt environment.>> %TFENV%
echo echo -- TFDIR set to %%TFDIR%%>> %TFENV%
echo cd /D %%HOMEDRIVE%%%%HOMEPATH%%>> %TFENV%

set TFDIR=%TFDIR:\=/%
del /f /q .qmake.stash src\.qmake.stash tools\.qmake.stash >nul 2>&1

:: Builds MongoDB driver
cd /d %BASEDIR%3rdparty
rd /s /q  mongo-driver >nul 2>&1
del /f /q mongo-driver >nul 2>&1
mklink /j mongo-driver mongo-c-driver-%MONBOC_VERSION% >nul 2>&1

cd %BASEDIR%3rdparty\mongo-driver
del /f /q CMakeCache.txt cmake_install.cmake CMakeFiles Makefile >nul 2>&1
set CMAKECMD=cmake %CMAKEOPT% -DCMAKE_CONFIGURATION_TYPES=Release -DENABLE_STATIC=ON -DENABLE_SSL=OFF -DENABLE_SNAPPY=OFF -DENABLE_ZLIB=OFF -DENABLE_ZSTD=OFF -DENABLE_SRV=OFF -DENABLE_SASL=OFF -DENABLE_ZLIB=OFF -DENABLE_SHM_COUNTERS=OFF -DENABLE_TESTS=OFF .
echo %CMAKECMD%
%CMAKECMD%

echo Compiling MongoDB driver library ...
set DEVENVCMD=devenv mongo-c-driver.sln /project mongoc_static /rebuild Release
echo %DEVENVCMD%
%DEVENVCMD% >nul 2>&1
if ERRORLEVEL 1 (
  :: Shows error
  %DEVENVCMD%
  echo;
  echo Build failed.
  echo MongoDB driver not available.
  exit /b
)

:: Builds LZ4
cd %BASEDIR%3rdparty
echo Compiling LZ4 library ...
rd /s /q  lz4 >nul 2>&1
del /f /q lz4 >nul 2>&1
mklink /j lz4 lz4-%LZ4_VERSION% >nul 2>&1
for /F %%i in ('qtpaths.exe --install-prefix') do echo %%i | find "msvc2015" >NUL
if not ERRORLEVEL 1 (
  set VS=VS2015
) else (
  set VS=VS2017
)
set DEVENVCMD=devenv lz4\build\%VS%\lz4.sln /project liblz4 /rebuild "Release|%BUILDTARGET%"
echo %DEVENVCMD%
%DEVENVCMD% >nul 2>&1
if ERRORLEVEL 1 (
  :: Shows error
  %DEVENVCMD%
  echo;
  echo Build failed.
  echo LZ4 not available.
  exit /b
)

cd %BASEDIR%src
if exist Makefile ( %MAKE% -k distclean >nul 2>&1 )
qmake %OPT% target.path='%TFDIR%/bin' header.path='%TFDIR%/include' %USE_GUI%

cd %BASEDIR%tools
if exist Makefile ( %MAKE% -k distclean >nul 2>&1 )
qmake -recursive %OPT% target.path='%TFDIR%/bin' header.path='%TFDIR%/include' datadir='%TFDIR%'
%MAKE% qmake

echo;
echo First, run "%MAKE% install" in src directory.
echo Next, run "%MAKE% install" in tools directory.

:exit
exit /b
