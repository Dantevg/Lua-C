#pragma once

#include <stdint.h> // for uint32_t

#include <lua.h>
#include <lauxlib.h>

/* C library definitions */

typedef struct Timer {
	int id;     // The SDL timer ID
	int delay;  // The delay in ms
	int repeat; // 1 = repeat, 0 = don't repeat
} Timer;

typedef struct Callback {
	int id;            // The callback id in the callback table
	int fn;            // The function id in the Lua registry
	void *data;        // Optional extra data
	const char *event; // The event name
} Callback;

// Callback function which gets called in different thread
// Receives the callback struct, puts it in an event and pushes that into the event queue
uint32_t timer_async_callback(uint32_t delay, void *param);

// Creates a callback for the function in the given registry id, for the given event,
// with the given data, and places it into the callback table
// Returns the callback struct, and places the callback id on the stack
Callback *event_add_callback(lua_State *L, const char *event, int callbackid, void *data);

// Dispatches event to Lua callbacks
void event_dispatch_callbacks(lua_State *L, const char *eventname, int args);

// Handle events and dispatch them to Lua
int event_loop(lua_State *L);

/* Lua API definitions */

// Registers an event callback
// Expects an event name, and a callback function
// Returns the callback id
int event_on(lua_State *L);

// Deregisters an event callback
// Expects a callback id, as returned by event_on
// Returns whether the callback was successfully removed
int event_off(lua_State *L);

// Adds a timer callback
// Expects a delay in milliseconds, a callback function, and optionally a boolean repeat
// Returns the callback id
int event_addTimer(lua_State *L);

// Deregisters a timer callback
// Expects a callback id
// Returns whether the timer was successfully removed
int event_removeTimer(lua_State *L);

// Adds an event to the queue
int event_push(lua_State *L);

LUAMOD_API int luaopen_event(lua_State *L);