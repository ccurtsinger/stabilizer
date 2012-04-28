#include "version.h"
#include "platformspecific.h"

#ifndef DIEHARD_DIEFAST
#define DIEHARD_DIEFAST 0 // NB: This is correct for DieHarder.
#endif

#define DIEHARD_DLL_NAME "C:\\Windows\\System32\\diehard-system.dll"
#define MADCHOOK_DLL_NAME "C:\\Windows\\System32\\madCHook.dll"
#define DIEHARD_GUID "D5DCD74D-EDBB-4e96-B9F1-DECF65E5BF92"
#define DIEHARD_FILENAME "C:\\Program Files\\University of Massachusetts Amherst\\DieHard\\diehard-token-"##DIEHARD_GUID
