/***
 * The `thread` module provides simple, unsafe (for now) multithreading access.
 * 
 * @module thread
 */

#if defined(_WIN32) || defined(__WIN32__)
	#include <windows.h>
#else
	#define _REENTRANT // needed for pthread_kill
	#include <pthread.h>
	#include <signal.h> // for SIGINT
#endif

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "thread.h"

/* C library definitions */

typedef struct Thread {
	lua_State *Lthread;
	int state;
#if defined(_WIN32) || defined(__WIN32__)
	DWORD tid;
	HANDLE thandle;
#else
	pthread_t tid;
#endif
} Thread;


// Gets called in the new thread
#if defined(_WIN32) || defined(__WIN32__)
DWORD WINAPI thread_run(LPVOID data){
#else
void *thread_run(void *data){
#endif
	lua_State *Lthread = (lua_State*)data;
	
	if(lua_pcall(Lthread, lua_gettop(Lthread)-1, LUA_MULTRET, 0) != LUA_OK){
		fprintf(stderr, "[Thread %p] %s\n", Lthread, lua_tostring(Lthread, -1));
		return 0;
	}
	
#if defined(_WIN32) || defined(__WIN32__)
	return 0;
#else
	pthread_exit(NULL);
#endif
}

/* Lua API definitions */

/*** Create a new thread.
 * @function new
 * @tparam function fn the function to be called in the new thread
 * @param[opt] ... any arguments which will be passed to `fn`
 * @treturn Thread a wrapper around the newly created Lua thread
 */
int thread_new(lua_State *L){
	luaL_argcheck(L, lua_isfunction(L, 1), 1, "expected function");
	
	/* Create Thread struct / userdata */
	Thread *t = lua_newuserdata(L, sizeof(Thread)); // stack: {t, (args?), fn}
	t->state = 1; // Active
	
	/* Create new Lua thread */
	t->Lthread = lua_newthread(L); // stack: {Lthread, t, (args?), fn}
	lua_pop(L, 1); // stack: {t, (args?), fn}
	
	/* Transfer its function and arguments */
	lua_rotate(L, 1, 1); // stack: {(args?), fn, t}
	lua_xmove(L, t->Lthread, lua_gettop(L) - 1); // stack: {t}
	
	/* Create hardware thread */
#if defined(_WIN32) || defined(__WIN32__)
	t->thandle = CreateThread(NULL, 0, thread_run, t->Lthread, 0, &t->tid);
#else
	pthread_create(&t->tid, NULL, thread_run, t->Lthread);
#endif
	
	luaL_setmetatable(L, "Thread");
	return 1;
}

/// @type Thread

/*** Wait for a thread to complete.
 * @function wait
 * @tparam Thread t the thread as returned from @{new}
 * @return the values returned from the thread function
 */
int thread_wait(lua_State *L){
	/* Get Lua thread */
	Thread *t = luaL_checkudata(L, 1, "Thread"); // stack: {t}
	if(t->state == 0) return 0; // Don't wait for a thread that has already stopped
	
	/* Wait for thread and get its return values */
#if defined(_WIN32) || defined(__WIN32__)
	WaitForSingleObject(t->thandle, INFINITE);
	CloseHandle(t->thandle);
#else
	pthread_join(t->tid, NULL);
#endif
	int n_return_values = lua_gettop(t->Lthread);
	lua_xmove(t->Lthread, L, n_return_values);
	t->state = 0; // Inactive
	
	return n_return_values;
}

/*** Immediately stop a thread.
 * @function kill
 * @tparam Thread t the thread as returned from @{new}
 */
int thread_kill(lua_State *L){
	/* Get Lua thread */
	Thread *t = luaL_checkudata(L, 1, "Thread"); // stack: {t}
	if(t->state == 0) return 0; // Don't wait for a thread that has already stopped
	
	/* Send SIGINT to thread */
#if defined(_WIN32) || defined(__WIN32__)
	WaitForSingleObject(t->thandle, 0);
	CloseHandle(t->thandle);
#else
	pthread_kill(t->tid, SIGINT);
#endif
	t->state = 0; // Inactive
	
	return 0;
}

static const struct luaL_Reg thread_f[] = {
	{"new", thread_new},
	{"wait", thread_wait},
	{"kill", thread_kill},
	{NULL, NULL}
};

LUAMOD_API int luaopen_thread(lua_State *L){
	lua_newtable(L); // stack: {table}
	luaL_setfuncs(L, thread_f, 0);
	
	/* Create Thread metatable */
	if(!luaL_newmetatable(L, "Thread")){ // stack: {mt, table, ...}
		luaL_error(L, "couldn't create Thread metatable");
	}
	
	// For object-oriented access
	lua_pushvalue(L, -2); // stack: {table, mt, table}
	lua_setfield(L, -2, "__index"); // stack: {mt, table}
	
	// To ensure the threads stop when they go out of scope (e.g. when the program stops)
	lua_pushcfunction(L, thread_kill); // stack: {thread_kill, mt, table}
	lua_setfield(L, -2, "__gc"); // stack: {mt, table}
	lua_pop(L, 1); // stack: {table}
	
	return 1;
}
