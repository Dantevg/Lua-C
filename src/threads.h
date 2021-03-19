#pragma once

#if defined(_WIN32) || defined(__WIN32__)
	// These are probably wrong and might not even be needed, I don't know
	#include <windows.h>
	#define THREAD HANDLE
	#define MUTEX HANDLE
	#define create_mutex(m) *(m) = CreateMutexA(NULL, FALSE, NULL)
	#define destroy_mutex(m) CloseHandle(m)
	#define lock_mutex(m) (WaitForSingleObject(m, INFINITE) == 0 ? 1 : GetLastError())
	#define unlock_mutex(m) (ReleaseMutex(m) == 0 ? 1 : GetLastError())
	#define create_thread(thread, fn, arg) *(thread) = CreateThread(NULL, 0, (fn), (arg), 0, NULL)
	#define join_thread(thread) WaitForSingleObject((thread), INFINITE); CloseHandle(thread)
	#define kill_thread(thread) WaitForSingleObject((thread), 0); CloseHandle(thread)
#else
	#include <pthread.h>
	#define THREAD pthread_t
	#define MUTEX pthread_mutex_t
	#define create_mutex(m) pthread_mutex_init(m, NULL)
	#define destroy_mutex(m) pthread_mutex_destroy(m)
	#define lock_mutex(m) pthread_mutex_lock(m)
	#define unlock_mutex(m) pthread_mutex_unlock(m)
	#define create_thread(thread, fn, arg) pthread_create((thread), NULL, (fn), (arg))
	#define join_thread(thread) pthread_join((thread), NULL)
	#define kill_thread(thread) pthread_kill((thread), SIGINT)
#endif
