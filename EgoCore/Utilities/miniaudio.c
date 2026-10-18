// miniaudio's implementation, in its own translation unit so it neither slows
// down nor gets rebuilt with main.cpp.
#define MA_COINIT_VALUE 2 /* COINIT_APARTMENTTHREADED */
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
