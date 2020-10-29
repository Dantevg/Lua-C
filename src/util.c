#include <SDL2/SDL.h>

void checkSDL(void *data, char *errstr){
	if(data == NULL){
		printf(errstr, SDL_GetError());
		exit(-1);
	}
}

void lower(const char *str, char *out, int length){
	for(int i = 0; i < length; i++){
		out[i] = tolower(str[i]);
	}
}