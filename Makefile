# Set compiler flags per OS
OS = $(shell uname)
ifeq ($(OS),Darwin) # MacOS
	INCLUDE_DIR = /usr/local/include
	INCLUDE_LUA = -I$(INCLUDE_DIR)/lua -llua5.3
	INCLUDE_SDL = -I$(INCLUDE_DIR)/sdl2 -lsdl2
else ifeq ($(OS),Linux)
	INCLUDE_DIR = /usr/include
	INCLUDE_LUA = -I$(INCLUDE_DIR)/lua5.3 -llua5.3
	INCLUDE_SDL = -I$(INCLUDE_DIR)/SDL2 -lSDL2
endif

main: src/main.c src/screen.c
	cc src/main.c -o bin/main $(INCLUDE_LUA) $(INCLUDE_SDL)
	cc src/screen.c -o bin/screen.so $(INCLUDE_LUA) $(INCLUDE_SDL) -shared -fPIC