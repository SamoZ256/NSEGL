#ifndef NSEGL_COMMON_H
#define NSEGL_COMMON_H

#include <stdio.h>

#define _NSEGL_MSG(type, msg) fprintf(stderr, "[NSEGL:" type "]::%s: %s\n", __FUNCTION__, msg)

#define NSEGL_ERROR(msg) _NSEGL_MSG("error", msg)

#define NSEGL_WARN(msg) _NSEGL_MSG("warning", msg)

#define NSEGL_WARN_UNSUPPORTED NSEGL_WARN("This function is unsupported")

#endif
