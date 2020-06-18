@echo off
del "C:\Program Files (x86)\Steam\steamapps\infectiousfight\garrysmod\garrysmod\lua\bin\gmsv__LOADLIB_FUNC_win32.dll"
del "C:\Program Files (x86)\Steam\steamapps\infectiousfight\garrysmod\garrysmod\lua\bin\gmcl__LOADLIB_FUNC_win32.dll"
copy gmsv__LOADLIB_FUNC_win32.dll "C:\Program Files (x86)\Steam\steamapps\infectiousfight\garrysmod\garrysmod\lua\bin\gmsv__LOADLIB_FUNC_win32.dll"
copy gmcl__LOADLIB_FUNC_win32.dll "C:\Program Files (x86)\Steam\steamapps\infectiousfight\garrysmod\garrysmod\lua\bin\gmcl__LOADLIB_FUNC_win32.dll"
del  gmsv__LOADLIB_FUNC_win32.dll
del  gmcl__LOADLIB_FUNC_win32.dll