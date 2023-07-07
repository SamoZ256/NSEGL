#ifndef NSEGL_COMMON_H
#define NSEGL_COMMON_H

#include <stdio.h>

#define _NSEGL_MSG(type, msg) fprintf(stderr, "[NSEGL:" type "]::%s: %s\n", __FUNCTION__, msg)

#define NSEGL_ERROR(msg) _NSEGL_MSG("error", msg)

#define NSEGL_WARN(msg) _NSEGL_MSG("warning", msg)

#define NSEGL_WARN_UNSUPPORTED NSEGL_WARN("This function is unsupported")

#define NSEGL_EGL_ERROR(msg, errorCode) \
{ \
NSEGL_ERROR(msg); \
lastError = errorCode; \
}

#define NSEGL_EGL_ERROR_AND_RETURN(msg, errorCode) \
{ \
NSEGL_EGL_ERROR(msg, errorCode); \
return EGL_FALSE; \
}

#define NSEGL_WARN_UNSUPPORTED_AND_RETURN \
{ \
NSEGL_WARN_UNSUPPORTED; \
return EGL_FALSE; \
}

#endif
