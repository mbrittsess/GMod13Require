@echo off
setlocal
::If you are using this file to build the libraries yourself, you will have to edit the lines from here...
set gmod_include="C:\devtools\gmod13headers"

set SDKInc="C:\devtools\WindowskSDK\Include"
set SDKLib="C:\devtools\WindowskSDK\Lib"

set DDKInc="C:\devtools\WindowsDDK\inc\ddk"

set APIInc="C:\devtools\WindowsDDK\inc\api"
set APILib="C:\devtools\WindowsDDK\lib\win7\i386"

set CRTInc="C:\devtools\WindowsDDK\inc\crt"
set CRTLib="C:\devtools\WindowsDDK\lib\Crt\i386"

set LuaPInc="C:\Program Files (x86)\Lua\5.1\include"

set CL86="C:\devtools\WindowsDDK\bin\x86\x86\cl.exe"
set LINK86="C:\devtools\WindowsDDK\bin\x86\x86\link.exe"
set LIB86=%LINK86% /LIB
::Down to here, in order to get it to run on your own. Some of the above might not actually be used. You'll need an ounce of knowledge.

%CL86% /c /MD /I%CRTInc% /I%APIInc% /I%LuaPInc% /I%gmod_include% /Tp_LOADLIB_FUNC.c /Foloadlib.obj
if errorlevel 1 goto :eof
%LINK86% /DLL /EXPORT:gmod13_open /EXPORT:gmod13_close /LIBPATH:%APILib% /LIBPATH:%SDKLib% /LIBPATH:%CRTLib% /OUT:gmsv__LOADLIB_FUNC_win32.dll loadlib.obj
if errorlevel 1 goto :eof

del loadlib.obj
del gmsv__LOADLIB_FUNC_win32.lib
del gmsv__LOADLIB_FUNC_win32.exp
copy gmsv__LOADLIB_FUNC_win32.dll gmcl__LOADLIB_FUNC_win32.dll

::call copy_basic

endlocal