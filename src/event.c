#include <SDL.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "main.h"

/* C library definitions */

// Callback function which gets called in different thread
uint32_t timer_async_callback(uint32_t delay, void *param){
	Callback *callback = param;
	Timer *timer = callback->data;
	
	SDL_Event event;
	SDL_UserEvent userevent;
	
	userevent.type = SDL_USEREVENT;
	userevent.code = 1;
	userevent.data1 = param;
	
	event.type = SDL_USEREVENT;
	event.user = userevent;
	
	// Push timer event on the event stack,
	// to call the lua function in the main thread
	SDL_PushEvent(&event);
	
	// Return the delay to continue repeating, return 0 to stop
	return (timer->repeat) ? delay : 0;
}

Callback *event_add_callback(lua_State *L, const char *event, int callbackid, void *data){
	lua_getfield(L, LUA_REGISTRYINDEX, "callbacks"); // stack: {callbacks, ...}
	
	/* Increment n */
	lua_getfield(L, -1, "n"); // stack: {n, callbacks, ...}
	int n = lua_tointeger(L, -1);
	lua_pushinteger(L, ++n); // stack: {n+1, n, callbacks, ...}
	lua_replace(L, -2); // stack: {n+1, callbacks, ...}
	lua_setfield(L, -2, "n"); // stack: {callbacks, ...}
	
	/* Create callback struct */
	Callback *callback = lua_newuserdata(L, sizeof(Callback)); // stack: {callback userdata, callbacks, ...}
	callback->fn = callbackid;
	callback->event = event;
	callback->data = data;
	
	/* Add callback userdata to callback table */
	lua_rawseti(L, -2, n); // stack: {callbacks, ...}
	
	lua_pop(L, 1); // stack: {...}
	lua_pushinteger(L, n); // stack: {n, ...}
	printf("[C] Registered callback %d for %s, fn %d\n", n, callback->event, callback->fn);
	return callback;
}

/* Lua API definitions */

int event_on(lua_State *L){
	const char *event = luaL_checkstring(L, 1); // stack: {callback, event}
	int id = luaL_ref(L, LUA_REGISTRYINDEX); // stack: {event}
	event_add_callback(L, event, id, NULL); // stack: {n, event}
	return 1;
}

int event_off(lua_State *L){
	int n = luaL_checkinteger(L, 1); // stack: {n}
	lua_getfield(L, LUA_REGISTRYINDEX, "callbacks"); // stack: {callbacks, n}
	lua_rawgeti(L, -1, n); // stack: {callbacks[n], callbacks, n}
	
	/* Get callback struct */
	void *ptr = lua_touserdata(L, -1);
	if(ptr == NULL){ // No callback present, return false
		lua_pushboolean(L, 0);
		return 1;
	}
	Callback *callback = (Callback*)ptr;
	
	/* Remove callback struct from callback table */
	lua_pushnil(L); // stack: {nil, callbacks[n], callbacks, n}
	lua_rawseti(L, -3, n); // stack: {callbacks[n], callbacks, n}
	
	/* Unreference Lua callback function */
	luaL_unref(L, LUA_REGISTRYINDEX, callback->fn);
	
	lua_pushboolean(L, 1); // Callback successfully removed, return true
	return 1;
}

int event_addTimer(lua_State *L){
	// I have to make this static (or put it on the heap),
	// as it otherwise gets deallocated at the end of this function,
	// and the callback wouldn't be able to use it anymore.
	luaL_checktype(L, 2, LUA_TFUNCTION); // stack: {(repeat?), callback, delay}
	
	/* Create timer */
	static Timer timer;
	timer.delay = luaL_checkinteger(L, 1);
	timer.repeat = lua_toboolean(L, 3);
	
	/* Register timer callback event */
	lua_pushvalue(L, 2); // stack: {callback, (repeat?), callback, delay}
	int id = luaL_ref(L, LUA_REGISTRYINDEX); // stack: {(repeat?), callback, delay}
	Callback *callback = event_add_callback(L, "timer", id, &timer); // stack: {n, (repeat?), callback, delay}
	
	/* Set timer callback id */
	timer.id = SDL_AddTimer(timer.delay, timer_async_callback, callback);
	
	return 1;
}

int event_removeTimer(lua_State *L){
	/* Remove callback */
	event_off(L); // stack: {status, callbacks[n], callbacks, n}
	if(lua_toboolean(L, -1)){ // Callback correctly removed
		/* Remove SDL timer */
		Callback *callback = (Callback*)lua_touserdata(L, -2);
		Timer *timer = callback->data;
		printf("[C] Removing timer %lld (%s), fn %d\n", lua_tointeger(L, 1), callback->event, callback->fn);
		SDL_RemoveTimer(timer->id);
	}
	
	return 1;
}

static const struct luaL_Reg event[] = {
	{"on", event_on},
	{"off", event_off},
	{"addTimer", event_addTimer},
	{"removeTimer", event_removeTimer},
	{NULL, NULL}
};

int luaopen_event(lua_State *L){
	lua_newtable(L);
	luaL_setfuncs(L, event, 0);
	return 1;
}