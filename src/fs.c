/***
 * The `fs` module provides access to MoonBox's filesystem
 * @module fs
 */

#include <stdlib.h>
#include <string.h>

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#include "fs.h"

/* C library definitions */

void fs_mount(lua_State *L, const char *path, FS *fs){
	lua_getfield(L, LUA_REGISTRYINDEX, "fs_filesystems");
	lua_pushlightuserdata(L, fs);
	lua_setfield(L, -2, path);
	lua_pop(L, 1);
}

char *copy_str(lua_State *L, int idx){
	size_t length;
	const char *str = lua_tolstring(L, idx, &length);
	if(str == NULL) return NULL;
	char *str_ = (char*)malloc((length+1) * sizeof(char));
	return strncpy(str_, str, length+1);
}

int fs_match_base(const char *a, const char *b){
	
	return 1;
}

/* Lua API definitions */

int fs_mount_l(lua_State *L){
	char *path = copy_str(L, 1);
	if(lua_isuserdata(L, 2)){
		fs_mount(L, path, lua_touserdata(L, 2));
	}else{
		// FS *fs = malloc(sizeof(FS));
	}
	return 0;
}

int fs_open(lua_State *L){
	const char *path = luaL_checkstring(L, 1);
	const char *mode = luaL_optstring(L, 2, "r");
	lua_getfield(L, LUA_REGISTRYINDEX, "fs_filesystems");
	int t = lua_gettop(L);
	lua_pushnil(L);
	while(lua_next(L, t) != 0){
		if(fs_match_base(path, lua_tostring(L, -2))){
			FS *fs = lua_touserdata(L, -1);
			FS_File *file = lua_newuserdata(L, sizeof(FS_File));
			file->fs = fs;
			file->fd = fs->open(path, mode);
			luaL_setmetatable(L, "File");
			return 1;
		}
		lua_pop(L, 1);
	}
	return 0;
}

int fs_close(lua_State *L){
	FS_File *file = luaL_checkudata(L, 1, "File");
	file->fs->close(file->fd);
	return 0;
}

int fs_flush(lua_State *L){
	return 0;
}

int fs_read(lua_State *L){
	FS_File *file = luaL_checkudata(L, 1, "File");
	int n = luaL_checkinteger(L, 2);
	char *buffer = malloc(n * sizeof(char));
	int n_read = file->fs->read(file->fd, buffer, n);
	if(n_read > 0){
		lua_pushlstring(L, buffer, n_read);
	}else{
		lua_pushnil(L);
	}
	free(buffer);
	return 1;
}

int fs_getc(lua_State *L){
	return 0;
}

int fs_seek(lua_State *L){
	return 0;
}

int fs_setvbuf(lua_State *L){
	return 0;
}

int fs_write(lua_State *L){
	return 0;
}

static const struct luaL_Reg fs_f[] = {
	{"mount", fs_mount_l},
	{"open", fs_open},
	{NULL, NULL}
};

static const struct luaL_Reg fs_m[] = {
	{"close", fs_close},
	{"flush", fs_flush},
	{"read", fs_read},
	{"getc", fs_getc},
	{"seek", fs_seek},
	{"setvbuf", fs_setvbuf},
	{"write", fs_write},
	{NULL, NULL}
};

LUAMOD_API int luaopen_fs(lua_State *L){
	luaL_newlib(L, fs_f);
	
	luaL_newmetatable(L, "File");
	luaL_newlib(L, fs_m);
	lua_setfield(L, -2, "__index");
	lua_pop(L, 1);
	
	lua_newtable(L);
	lua_setfield(L, LUA_REGISTRYINDEX, "fs_filesystems");
	
	return 1;
}