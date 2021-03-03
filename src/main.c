/***
 * @script moonbox
 * @usage
 * Usage: moonbox [options] [file [args]]
 * Execute FILE, or the default boot file
 * 
 * Options:
 *   -v, --version      print version
 *   -h, --help         print this help message
 *   -m, --module name  require library 'name'. Pass '*' to load all available
 *   -e chunk           execute 'chunk'
 *   -                  stop handling options and execute stdin
 */

#include <unistd.h> // For chdir
#include <string.h> // for strcmp
#include <stdlib.h> // for exit
#include <time.h>   // for clock_gettime, compile with -std=gnu99

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "event.h"

#define VERSION "0.3.0"

#ifndef BASE_PATH
	#define BASE_PATH "/"
#endif

#if defined(_WIN32)
	#define SO_EXT "dll"
#else
	#define SO_EXT "so"
#endif

static struct timespec lua_os_clock_base;

void print_usage(){
	printf("Usage: moonbox [options] [file [args]]\n");
	printf("Execute 'file', or the default boot file\n\n");
	printf("Options:\n" );
	printf("  -v, --version\t\tprint version\n");
	printf("  -h, --help\t\tprint this help message\n");
	printf("  -m, --module name\trequire library 'name'. Pass '*' to load all available\n");
	printf("  -e chunk\t\texecute 'chunk'\n");
	printf("  -\t\t\tstop handling options and execute stdin\n");
}

int lua_error_handler(lua_State *L){
	luaL_traceback(L, L, lua_tostring(L, -1), 2);
	fprintf(stderr, "%s\n", lua_tostring(L, -1));
	lua_pop(L, 1);
	return 1;
}

int lua_os_clock(lua_State *L){
	struct timespec t;
	clock_gettime(CLOCK_MONOTONIC, &t);
	time_t diff_sec = t.tv_sec - lua_os_clock_base.tv_sec;
	time_t diff_nsec = (t.tv_nsec - lua_os_clock_base.tv_nsec);
	lua_pushnumber(L, diff_sec + (double)diff_nsec*1e-9);
	return 1;
}

void init_lua(lua_State *L){
	luaL_openlibs(L); // Open standard libraries (math, string, table, ...)
	
	/* Set cpath and path */
	if(luaL_dostring(L, "package.cpath = package.cpath..';" BASE_PATH "bin/?." SO_EXT "'")){
		fprintf(stderr, "[C] Could not set package.cpath:\n%s\n", lua_tostring(L, -1));
	}
	if(luaL_dostring(L, "package.path = package.path..';" BASE_PATH "res/lib/?.lua;" BASE_PATH "res/lib/?/init.lua'")){
		fprintf(stderr, "[C] Could not set package.path:\n%s\n", lua_tostring(L, -1));
	}
	
	/* Push MoonBox version */
	lua_pushstring(L, "MoonBox " VERSION);
	lua_setglobal(L, "_MB_VERSION");
	
	/* Push new os.clock */
	lua_getglobal(L, "os");
	lua_pushcfunction(L, lua_os_clock);
	lua_setfield(L, -2, "clock");
	lua_pop(L, 1);
	
	/* Push Lua error handler */
	lua_pushcfunction(L, lua_error_handler);
	
	/* Set clock start time */
	clock_gettime(CLOCK_MONOTONIC, &lua_os_clock_base);
}

void parse_cmdline_args(int argc, char *argv[], char **file, int *lua_arg_start, lua_State *L){
	int stop = 0;
	for(int i = 1; i < argc; i++){
		if(strcmp(argv[i], "-v") == 0 || strcmp(argv[i], "--version") == 0){
			/* Print version and return */
			printf("MoonBox " VERSION "\n");
			stop = 1;
		}else if(strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0){
			/* Print usage and return */
			print_usage();
			stop = 1;
		}else if(strcmp(argv[i], "-m") == 0 || strcmp(argv[i], "--module") == 0){
			/* Load module */
			if(i >= argc){
				fprintf(stderr, "Option --module expects an argument");
				exit(EXIT_FAILURE);
			}
			char *module = argv[++i];
			lua_getglobal(L, "require");
			lua_pushstring(L, module);
			if(lua_pcall(L, 1, 1, 0) != LUA_OK){
				fprintf(stderr, "[C] Could not load module %s:\n%s\n", module, lua_tostring(L, -1));
				exit(EXIT_FAILURE);
			}
			lua_setglobal(L, module); // TODO: Set better name for submodules
		}else if(strcmp(argv[i], "-e") == 0){
			/* Execute command-line argument */
			if(i >= argc){
				fprintf(stderr, "Option -e expects an argument");
				exit(EXIT_FAILURE);
			}
			char *code = argv[++i];
			if(luaL_loadstring(L, code) == LUA_OK){
				lua_pcall(L, 0, 0, 1);
				stop = 1;
			}else{
				fprintf(stderr, "[C] Could not load Lua code: %s\n", lua_tostring(L, -1));
				exit(EXIT_FAILURE);
			}
		}else if(strcmp(argv[i], "-") == 0){
			/* Execute stdin */
			*file = NULL;
			return;
		}else if(argv[i][0] == '-'){
			/* Unrecognised command line option */
			fprintf(stderr, "Unrecognised option: %s\n", argv[i]);
			print_usage();
			exit(EXIT_FAILURE);
		}else{
			/* Execute file */
			*file = argv[i];
			*lua_arg_start = i+1;
			return;
		}
	}
	
	if(stop){
		lua_close(L);
		exit(EXIT_SUCCESS);
	}
}

int main(int argc, char *argv[]){
	/* Init Lua */
	lua_State *L = luaL_newstate();
	init_lua(L);
	
	/* Run init file */
	if(luaL_loadfile(L, BASE_PATH "res/init.lua") == LUA_OK){
		if(lua_pcall(L, 0, 0, 1) != LUA_OK) return -1;
	}else{
		fprintf(stderr, "%s\n", lua_tostring(L, -1));
		return -1;
	}
	
	/* Parse command-line arguments */
	char *file = BASE_PATH "res/main.lua";
	int lua_arg_start = argc;
	parse_cmdline_args(argc, argv, &file, &lua_arg_start, L);
	
	/* Load main file */
	if(luaL_loadfile(L, file) == LUA_OK){
		/* Push lua args */
		for(int i = lua_arg_start; i < argc; i++){
			lua_pushstring(L, argv[i]);
		}
		if(lua_pcall(L, argc-lua_arg_start, 1, 1) == LUA_OK){
			// Immediately stop execution when main chunk returns false
			if(lua_isboolean(L, -1) && lua_toboolean(L, -1) == 0){
				lua_close(L);
				return 0;
			}
		}else{
			// Error message was already printed by lua_error_handler
			return -1;
		}
	}else{
		fprintf(stderr, "[C] Could not load Lua code: %s\n", lua_tostring(L, -1));
		return -1;
	}
	
	/* Main loop */
	int quit = 0;
	while(!quit){
		quit = event_loop(L);
	}
	
	/* Exit */
	lua_close(L);
	return 0;
}