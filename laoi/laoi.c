
#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <string.h>
#include "aoi.h"

#define METANAME "laoi"

static int
traceback(lua_State *L) {
	const char *msg = lua_tostring(L, 1);
	if (msg)
		luaL_traceback(L, L, msg, 1);
	else {
		lua_pushliteral(L, "(no error message)");
	}
	return 1;
}

struct aoi_space_box
{
	struct aoi_space* space;
};

static int lrelease(lua_State *L)
{
	struct aoi_space_box* ab = lua_touserdata(L, 1);
	if (ab&&ab->space)
	{
		aoi_release(ab->space);
		ab->space = NULL;
	}
	return 0;
}

static int laoi_update(lua_State *L)
{
	struct aoi_space_box *ab = lua_touserdata(L, 1);
	if (ab == NULL || ab->space == NULL)
		return luaL_error(L, "Invalid aoi_space pointer");
	uint32_t id = (uint32_t)luaL_checkinteger(L, 2);
	const char* mode = luaL_checkstring(L, 3);
	float x = (float)luaL_checknumber(L, 4);
	float y = (float)luaL_checknumber(L, 5);
	float z = (float)luaL_checknumber(L, 6);
	float pos[] = { x,y,z };
	aoi_update(ab->space, id, mode, pos);
	return 0;
}

static void cb(void *ud, uint32_t watcher, uint32_t marker) {
	lua_State *L = ud;
	lua_pushcfunction(L, traceback);
	lua_rawgetp(L, LUA_REGISTRYINDEX, cb);//get lua function
	lua_pushinteger(L, watcher);
	lua_pushinteger(L, marker);
	int r = lua_pcall(L, 2, 0, -4);
	if (r == LUA_OK) {
		return;
	}
	else
	{
		printf("aoi_message cb error:%s\n", lua_tostring(L, -1));
	}
	lua_pop(L, 1);
	return;
}

static int laoi_message(lua_State *L)
{
	struct aoi_space_box *ab = lua_touserdata(L, 1);
	if (ab == NULL || ab->space == NULL)
		return luaL_error(L, "Invalid aoi_space pointer");
	luaL_checktype(L, -1, LUA_TFUNCTION);
	lua_rawsetp(L, LUA_REGISTRYINDEX, cb);// LUA_REGISTRYINDEX table[cb]=function
	aoi_message(ab->space, cb, L);
	return 0;
}

static int laoi_create(lua_State *L)
{
	struct aoi_space* as = aoi_new();
	struct aoi_space_box* ab = lua_newuserdata(L, sizeof(*ab));
	ab->space = as;
	if (luaL_newmetatable(L, METANAME))//mt
	{
		luaL_Reg l[] = {
			{ "update",laoi_update },
			{ "message",laoi_message },
			{ NULL,NULL }
		};
		luaL_newlib(L, l); {}
		lua_setfield(L, -2, "__index");//mt[__index] = {}
		lua_pushcfunction(L, lrelease);
		lua_setfield(L, -2, "__gc");//mt[__gc] = lrelease
	}
	lua_setmetatable(L, -2);// set userdata metatable
	lua_pushlightuserdata(L, ab);
	return 2;
}

#if defined(_USRDLL)
#define LUA_EXTENSIONS_DLL __declspec(dllexport)
#else /* use a DLL library */
#define LUA_EXTENSIONS_DLL
#endif

#if __cplusplus
extern "C" {
#endif
int LUA_EXTENSIONS_DLL luaopen_aoi(lua_State *L)
{
	luaL_Reg l[] = {
		{"create",laoi_create},
		{"release",lrelease },
		{NULL,NULL}
	};
	luaL_checkversion(L);
	luaL_newlib(L, l);
	return 1;
}
#if __cplusplus
}
#endif