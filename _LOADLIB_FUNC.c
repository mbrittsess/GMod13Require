static const char* guidLoadLibFunc = "{50A9E9B7-C5F6-4e6e-A2FB-FA6DFDED741C}";

#include <windows.h>
#include <stdio.h>
#include <stdarg.h>

#define GMMODULE
 #include <Interface.h>
#undef GMMODULE

/* This bit will only work if you're using the MSCRT; I only know of Pelles C having an implementation of asprintf() and
Pelles C doesn't support C++, like the Garry API requires */
extern "C" static int asprintf(char** ptr, const char* format, ...) {
    va_list char_count_list;
    va_list char_print_list;
    
    va_start(char_count_list, format);
    va_start(char_print_list, format);
    
   {size_t char_count = (size_t)_vscprintf(format, char_count_list);
    char* output = (char*)malloc(char_count+1); /* We do NOT free this memory ourselves. */
    _vsnprintf(output, char_count, format, char_print_list);
    
    va_end(char_count_list);
    va_end(char_print_list);
    
    *ptr = output;
    
    return (int)char_count;};
};

#define Prep GarrysMod::Lua::ILuaBase* I = L->luabase

/* Something of the equivalent of ll_register() from loadlib.c */
extern "C" static HMODULE* get_module_handle(lua_State* L, const char* libpath) {
    Prep;
    HMODULE* pLibHandle;
    static const char* LIBPREFIX = "LOADLIB: ";
    
    I->PushSpecial(GarrysMod::Lua::SPECIAL_REG);
    
    const char* registered_key = NULL;
        /* Remember to free() registered_key later */
    unsigned int key_len = (unsigned int)asprintf((char**)&registered_key, "%s%s", LIBPREFIX, libpath);
    
    I->PushString(registered_key, key_len);
    I->GetTable(-2);
    
    if (!I->IsType(-1, GarrysMod::Lua::Type::NIL)) {
        /* An entry already exists for us. */
        pLibHandle = (HMODULE*)I->GetUserdata(-1);
    } else {
        I->Pop(1);
        I->PushString(registered_key, key_len);
        
        pLibHandle = (HMODULE*)I->NewUserdata((unsigned int)sizeof(HMODULE));
       *pLibHandle = NULL;
        
        /* TODO: Would be a better idea for us to create our own metatable instead of assuming the __gc() for this one does what 5.1 does */
        I->GetField(-3, "_LOADLIB");
        I->SetMetaTable(-2);
        I->SetTable(-3);
    };
    
    free((void*)registered_key);
    return pLibHandle;
};

extern "C" static void push_system_error_msg(lua_State *L) {
    Prep;
    
    DWORD ErrorId = GetLastError();
    const char* Message = NULL;
    
    DWORD CharCount = FormatMessageA(
        FORMAT_MESSAGE_IGNORE_INSERTS
      | FORMAT_MESSAGE_FROM_SYSTEM
      | FORMAT_MESSAGE_ALLOCATE_BUFFER,
        NULL,
        ErrorId,
        0x0409, /* Locale ID for en-US, I wish I had a more readable way to do this without involving MUI */
        (LPSTR)&Message,
        1,
        NULL);
    
    if (CharCount != 0) {
        I->PushString(Message, CharCount);
        LocalFree((HLOCAL)Message);
    } else {
        /* Getting the message failed. */
        Message = NULL;
        unsigned int CharCount = asprintf((char**)&Message, "system error %u\n", ErrorId);
        I->PushString(Message, CharCount);
        free((void*)Message);
    };
};

/* Something of a combination of ll_loadfunc() and ll_loadlib() from loadlib.c, in the form of a lua_CFunction.
The arguments are:
-- Path to the library we want to get a function from
-- Name of the function we want to get from said library
The return values are either:
-- The function requested
-- nil, a human-readable error message, and a string "no_file", "link_fail", or "no_func" */
extern "C" static int loadlib_func(lua_State* L) {
    Prep;
    
    if (I->Top() > 2) {
        I->Pop(I->Top() - 2);
    };
    
    I->CheckType(1, GarrysMod::Lua::Type::STRING);
    I->CheckType(2, GarrysMod::Lua::Type::STRING);
    
   {const char* libpath  = I->GetString(1, NULL);
    const char* funcname = I->GetString(2, NULL);
    
    /* Does the library exist at all? */
    FILE* fLib = fopen(libpath, "r");
    if (fLib == NULL) { /* Library can't be opened, likely doesn't exist */
        static const char* FileNotFoundReason = "no_file";
        char*              FileNotFoundMsg = NULL;
        unsigned int       MsgLen = (unsigned int)asprintf((char**)&FileNotFoundMsg, "No file '%s'", libpath);
        
        I->PushNil();
        I->PushString(FileNotFoundMsg, MsgLen);
        I->PushString(FileNotFoundReason, sizeof("no_file")-1);
        
        free((void*)FileNotFoundMsg);
        return 3;
    };
    
    /* Alright, let's try to get a handle for the module */
    HMODULE* pLibHandle = get_module_handle(L, libpath);
    if (*pLibHandle == NULL) { /* Library is not linked to this process yet */
        *pLibHandle = LoadLibraryA(libpath);
        if (*pLibHandle == NULL) { /* Failed to link the library */
            static const char* LinkFailReason = "link_fail";
            
            I->PushNil();
            push_system_error_msg(L);
            I->PushString(LinkFailReason, sizeof("link_fail")-1);
            
            return 3;
        };
    };
    
    /* And now to get the function we're looking for. */
    GarrysMod::Lua::CFunc ReqFunction = (GarrysMod::Lua::CFunc)GetProcAddress(*pLibHandle, funcname);
    if (ReqFunction == NULL) { /* Didn't find the function */
        static const char* NoFuncReason = "no_func";
        
        I->PushNil();
        push_system_error_msg(L);
        I->PushString(NoFuncReason, sizeof("no_func")-1);
        
        return 3;
    } else {
        I->PushCFunction(ReqFunction);
        
        return 1;
    };};
};

extern "C" __declspec(dllexport) int gmod13_open(lua_State* L) {
    Prep;
    
    I->Pop(I->Top());
    I->PushSpecial(GarrysMod::Lua::SPECIAL_REG);
    
    /* Check if we've already been loaded before, it shouldn't matter but you never know */
    I->GetField(1, guidLoadLibFunc);
    if (I->IsType(-1, GarrysMod::Lua::Type::NIL)) { /* We haven't been run yet */
        I->Pop(1);
        I->PushCFunction(loadlib_func);
        I->SetField(1, guidLoadLibFunc);
    };
    
    return 0;
};

extern "C" __declspec(dllexport) int gmod13_close(lua_State* L) {
    return 0;
};