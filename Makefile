CFLAGS = -Wall -Wextra -Wshadow -Wno-unused-parameter -std=c99
LUA_VERSION = 5.3
INCLUDE = -I/usr/include/lua$(LUA_VERSION) -I/usr/local/include/lua$(LUA_VERSION)
LIBS_MAIN = -llua$(LUA_VERSION)
LIBS_SO = -lSDL2 -llua$(LUA_VERSION)
SO = so

# Parallel compilation is faster
MAKEFLAGS += -j

ifeq ($(OS),Windows_NT)
	CFLAGS += -DLUA_LIB -DLUA_BUILD_AS_DLL
	# TODO: use $HOME or other more generic env var?
	INCLUDE = -I "C:\Users\dante\Documents\mingw\include\lua"
	LIBS_MAIN = -llua
	LIBS_SO = -lmingw32 -lSDL2main -lSDL2 -llua
	SO = dll
endif

.PHONY: all init main libraries clean

all: main libraries
init:
	mkdir -p build bin
	mkdir -p build/image bin/image
main: bin/main
libraries: bin/event.$(SO)\
	bin/SDLWindow.$(SO)\
	bin/image/SDLImage.$(SO)\
	bin/thread.$(SO)\
	bin/sys.$(SO)\
	bin/mouse.$(SO)\
	bin/kb.$(SO)\
	bin/data.$(SO)



# Dependency list

bin/main: build/main.o
build/main.o: src/main.c

build/util.o: src/util.c src/util.h

build/font.o: src/font.c src/font.h

bin/event.$(SO): build/event.o build/util.o
build/event.o: src/event.c src/event.h

bin/SDLWindow.$(SO): build/SDLWindow.o build/font.o build/util.o
build/SDLWindow.o: src/SDLWindow.c src/SDLWindow.h

bin/image/SDLImage.$(SO): build/image/SDLImage.o build/font.o build/util.o
build/image/SDLImage.o: src/image/SDLImage.c src/image/SDLImage.h

bin/thread.$(SO): build/thread.o build/util.o
build/thread.o: src/thread.c src/thread.h

bin/sys.$(SO): build/sys.o
build/sys.o: src/sys.c

bin/mouse.$(SO): build/mouse.o
build/mouse.o: src/mouse.c src/mouse.h

bin/kb.$(SO): build/kb.o
build/kb.o: src/kb.c src/kb.h

bin/data.$(SO): build/data.o
build/data.o: src/data.c src/data.h



# Automatic rules

# For main file
bin/%: build/%.o
	$(CC) -o $@ $^ $(CFLAGS) $(LIBS_MAIN)

# For libraries (.so/.dll files)
bin/%.$(SO): build/%.o
	$(CC) -o $@ $^ $(CFLAGS) $(LIBS_SO) -shared

# For intermediate files (.o files)
build/%.o: src/%.c
	$(CC) -o $@ -c $< $(CFLAGS) $(INCLUDE) -fpic

clean:
	rm -r build
	rm -r bin