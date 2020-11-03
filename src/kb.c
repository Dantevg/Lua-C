#include <SDL2/SDL.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "kb.h"

/* C library definitions */

/* Lua API definitions */

// Returns whether a key is down
int kb_down(lua_State *L){
	const char *keyname = lua_tostring(L, 1);
	SDL_Keycode keycode = SDL_GetKeyFromName(keyname);
	SDL_Scancode scancode = SDL_GetScancodeFromKey(keycode);
	const uint8_t *state = SDL_GetKeyboardState(NULL);
	
	lua_pushboolean(L, state[scancode]);
	return 1;
}

// Returns whether a physical key is down
int kb_scancodeDown(lua_State *L){
	const char *keyname = lua_tostring(L, 1);
	SDL_Keycode scancode = SDL_GetScancodeFromName(keyname);
	const uint8_t *state = SDL_GetKeyboardState(NULL);
	
	lua_pushboolean(L, state[scancode]);
	return 1;
}

LUAMOD_API int luaopen_kb(lua_State *L){
	lua_newtable(L);
	luaL_setfuncs(L, kb_f, 0);
	return 1;
}