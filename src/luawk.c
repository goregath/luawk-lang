#include <lauxlib.h>
#include <lua.h>
#include <lualib.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#if LUA_VERSION_NUM == 501
  #define LUA_OK 0
#endif

/* Copied from lua.c */

static lua_State *globalL = NULL;

static void lstop (lua_State *L, lua_Debug *ar) {
  (void)ar;  /* unused arg. */
  lua_sethook(L, NULL, 0, 0);  /* reset hook */
  luaL_error(L, "interrupted!");
}

static void laction (int i) {
  signal(i, SIG_DFL); /* if another SIGINT happens, terminate process */
  lua_sethook(globalL, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

static int msghandler (lua_State *L) {
  const char *msg = lua_tostring(L, 1);
  if (msg == NULL) {  /* is error object not a string? */
  	if (luaL_callmeta(L, 1, "__tostring") &&  /* does it have a metamethod */
  			lua_type(L, -1) == LUA_TSTRING)  /* that produces a string? */
  		return 1;  /* that is the message */
  	else
  		msg = lua_pushfstring(L, "(error object is a %s value)", luaL_typename(L, 1));
  }
  /* Call debug.traceback() instead of luaL_traceback() for Lua 5.1 compatibility. */
  lua_getglobal(L, "debug");
  lua_getfield(L, -1, "traceback");
  /* debug */
  lua_remove(L, -2);
  lua_pushstring(L, msg);
  /* original msg */
  lua_remove(L, -3);
  lua_pushinteger(L, 2);  /* skip this function and traceback */
  lua_call(L, 2, 1); /* call debug.traceback */
  return 1;  /* return the traceback */
}

static int docall (lua_State *L, int narg, int nres) {
  int status;
  int base = lua_gettop(L) - narg;  /* function index */
  lua_pushcfunction(L, msghandler);  /* push message handler */
  lua_insert(L, base);  /* put it under function and args */
  globalL = L;  /* to be available to 'laction' */
  signal(SIGINT, laction);  /* set C-signal handler */
  status = lua_pcall(L, narg, nres, base);
  signal(SIGINT, SIG_DFL); /* reset C-signal handler */
  lua_remove(L, base);  /* remove message handler from the stack */
  return status;
}

LUALIB_API int luaopen_luawk(lua_State *L);
LUALIB_API int luawk_preload(lua_State *L);

typedef struct argv_t {
  int argc;
  char **argv;
} argv_t;

LUALIB_API int argv_index(lua_State *L) {
  argv_t *a;
  int i;
  luaL_checkudata(L, 1, "argv");
  i = (int) luaL_checkinteger(L, 2);
  a = (argv_t *) lua_touserdata(L, 1);
  if (i >= 0 && i < a->argc) {
    lua_pushstring(L, a->argv[i]);
    return 1;
  }
  return 0;
}

LUALIB_API int argv_len(lua_State *L) {
  argv_t *a;
  luaL_checkudata(L, 1, "argv");
  a = (argv_t *) lua_touserdata(L, 1);
  lua_pushinteger(L, a->argc - 1);
  return 1;
}

int main(int argc, char *argv[]) {
  lua_State *L = luaL_newstate();
  argv_t *a;
  luaL_openlibs(L);
  luawk_preload(L);
  // arg table is implemented as userdata due to a bug during bulk copying
  a = (argv_t *) lua_newuserdata(L, sizeof(argv_t));
  a->argc = argc;
  a->argv = argv;
  luaL_newmetatable(L, "argv");
  lua_pushcfunction(L, argv_index);
  lua_setfield(L, -2, "__index");
  lua_pushcfunction(L, argv_len);
  lua_setfield(L, -2, "__len");
  lua_setmetatable(L, -2);
  lua_setglobal(L, "arg");
  lua_pushcfunction(L, luaopen_luawk);
  if (docall(L, 0, LUA_MULTRET)) {
    const char *errmsg = lua_tostring(L, 1);
    if (errmsg) {
      fprintf(stderr, "%s\n", errmsg);
    }
    lua_close(L);
    return 1;
  }
  lua_close(L);
  return 0;
}
