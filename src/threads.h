#pragma once

#if defined(_WIN32) || defined(__WIN32__)
	#include <windows.h>
	#define THREAD HANDLE
	#define MUTEX CRITICAL_SECTION // Use more lightweight critical section as mutex
	#define CONDITION CONDITION_VARIABLE
	
	#define create_thread(thread, fn, arg) (thread) = CreateThread(NULL, 0, (fn), (arg), 0, NULL)
	#define join_thread(thread) WaitForSingleObject((thread), INFINITE); CloseHandle(thread)
	#define kill_thread(thread) TerminateThread((thread), 0); CloseHandle(thread)
	#define self_thread() GetCurrentThread()
	#define exit_thread() ExitThread(0)
	
	#define create_mutex(m) InitializeCriticalSection(&(m))
	#define destroy_mutex(m) DeleteCriticalSection(&(m))
	#define lock_mutex(m) EnterCriticalSection(&(m))
	#define unlock_mutex(m) LeaveCriticalSection(&(m))
	
	#define create_cond(c) InitializeConditionVariable(&(c))
	#define destroy_cond(c) (void)(c)
	#define wait_cond(c, m) SleepConditionVariableCS(&(c), &(m), INFINITE)
	#define signal_cond(c) WakeConditionVariable(&(c))
#else
	#include <pthread.h>
	#define THREAD pthread_t
	#define MUTEX pthread_mutex_t
	#define CONDITION pthread_cond_t
	
	#define create_thread(thread, fn, arg) pthread_create(&(thread), NULL, (fn), (arg))
	#define join_thread(thread) pthread_join((thread), NULL)
	#define kill_thread(thread) pthread_cancel(thread)
	#define self_thread() pthread_self()
	#define exit_thread() pthread_exit(NULL)
	
	#define create_mutex(m) pthread_mutex_init(&(m), NULL)
	#define destroy_mutex(m) pthread_mutex_destroy(&(m))
	#define lock_mutex(m) pthread_mutex_lock(&(m))
	#define unlock_mutex(m) pthread_mutex_unlock(&(m))
	
	#define create_cond(c) pthread_cond_init(&(c), NULL)
	#define destroy_cond(c) pthread_cond_destroy(&(c))
	#define wait_cond(c, m) pthread_cond_wait(&(c), &(m))
	#define signal_cond(c) pthread_cond_signal(&(c))
#endif
