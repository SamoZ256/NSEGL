#include <EGL/egl.h>

#include "common.h"

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

#define NSEGL_EGL_ENUM_MIN 0x3000

CFBundleRef framework = nil;

struct NSEGLContext;

EGLint lastError = EGL_SUCCESS;
struct NSEGLContext* currentContext = NULL;

#define TEMPLATE_CAST_TO(objType, objName, errorCode, errorIfInvalid) \
if (errorIfInvalid && !objName) \
    NSEGL_EGL_ERROR_AND_RETURN("'" #objName "' must be a valid pointer", errorCode); \
struct objType* nsegl_##objName = (struct objType*)objName;

//Config
#define MAX_CONFIG_ATTRIBUTES 256

struct NSEGLConfig {
    int attributes[MAX_CONFIG_ATTRIBUTES];
};

#define CAST_TO_NSEGL_CONFIG(eglConfig) TEMPLATE_CAST_TO(NSEGLConfig, eglConfig, EGL_BAD_CONFIG, true)

//Display
struct NSEGLDisplay {
    struct NSEGLContext* context;
};

#define CAST_TO_NSEGL_DISPLAY(eglDisplay) TEMPLATE_CAST_TO(NSEGLDisplay, eglDisplay, EGL_BAD_DISPLAY, true)

//Context
struct NSEGLContext {
    NSOpenGLPixelFormat* pixelFormat;
    NSOpenGLContext* context;
    struct NSEGLConfig* config;
};

#define CAST_TO_NSEGL_CONTEXT(eglContext, errorIfInvalid) TEMPLATE_CAST_TO(NSEGLContext, eglContext, EGL_BAD_CONTEXT, errorIfInvalid)

//Surface
struct NSEGLSurface {
    NSWindow* window;
};

#define CAST_TO_NSEGL_SURFACE(eglSurface) TEMPLATE_CAST_TO(NSEGLSurface, eglSurface, EGL_BAD_SURFACE, true)

//Attributes
#define BAD_ATTRIBUTE(msg) \
NSEGL_EGL_ERROR(msg, EGL_BAD_ATTRIBUTE); \
*outSkip = true; \
return -1;

int getNSAttribFromEGL(EGLint attrib, EGLint value, bool skipColor, bool* outSkip, bool* outColorSkipped) {
    *outSkip = false;

    switch (attrib) {
    case EGL_ALPHA_SIZE:
        return NSOpenGLPFAAlphaSize;
    case EGL_DEPTH_SIZE:
        return NSOpenGLPFADepthSize;
    case EGL_STENCIL_SIZE:
        return NSOpenGLPFAStencilSize;
    case EGL_SAMPLE_BUFFERS:
        return NSOpenGLPFASampleBuffers;
    case EGL_SAMPLES:
        return NSOpenGLPFASamples;

    //Color
    case EGL_RED_SIZE:
    case EGL_GREEN_SIZE:
    case EGL_BLUE_SIZE:
        if (skipColor) {
            *outSkip = true;
            return -1;
        } else {
            *outColorSkipped = true;
            return NSOpenGLPFAColorSize;
        }

    //Special
    //case EGL_SURFACE_TYPE:
    //    switch (value) {
    //    case EGL_WINDOW_BIT:
    //        *outUseValue = false;
    //        return NSOpenGLPFAWindow;
    //    default:
    //        BAD_ATTRIBUTE("Unknown surface type");
    //    }
    
    //Unsupported
    case EGL_COLOR_BUFFER_TYPE:
    case EGL_BUFFER_SIZE:
    case EGL_RENDERABLE_TYPE:
    case EGL_SURFACE_TYPE:
        *outSkip = true;
        return -1;

    //Skipped
    default:
        BAD_ATTRIBUTE("Unknown attribute");
    }
}

#undef BAD_ATTRIBUTE

//------------------------ EGL_VERSION_1_0 ------------------------
EGLAPI EGLBoolean EGLAPIENTRY eglChooseConfig(EGLDisplay dpy, const EGLint *attrib_list, EGLConfig *configs, EGLint config_size, EGLint *num_config) {
    //Cast
    CAST_TO_NSEGL_DISPLAY(dpy);

    if (config_size == 0)
        NSEGL_EGL_ERROR_AND_RETURN("'config_size' must not be 0", EGL_BAD_PARAMETER);
    
    //TODO: return more than 1 config
    struct NSEGLConfig* config = malloc(sizeof(struct NSEGLConfig));
    for (uint32_t i = 0; i < MAX_CONFIG_ATTRIBUTES; i++)
        config->attributes[i] = -2;

#define ADD_ATTRIBUTE(attrib) config->attributes[attrib - NSEGL_EGL_ENUM_MIN] = -1;
#define SET_ATTRIBUTE(attrib, value) config->attributes[attrib - NSEGL_EGL_ENUM_MIN] = value;

    uint32_t i = 0;
    while (true) {
        EGLint attrib = attrib_list[i++];
        if (attrib == EGL_NONE)
            break;
        EGLint value = attrib_list[i++];

        //bool skip;
        //int nsAttrib = getNSAttribFromEGL(attrib, value, colorSkipped, &skip, &colorSkipped);
        //if (skip)
        //    continue;
        SET_ATTRIBUTE(attrib, value);
    }

#undef SET_ATTRIBUTE
#undef ADD_ATTRIBUTE

    configs[0] = config;
    *num_config = 1;

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglCopyBuffers(EGLDisplay dpy, EGLSurface surface, EGLNativePixmapType target) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLContext EGLAPIENTRY eglCreateContext(EGLDisplay dpy, EGLConfig config, EGLContext share_context, const EGLint *attrib_list) {
    //Cast
    CAST_TO_NSEGL_CONTEXT(share_context, false);
    CAST_TO_NSEGL_CONFIG(config);

    struct NSEGLContext* context = malloc(sizeof(struct NSEGLContext));
    context->config = nsegl_config;

#define ADD_ATTRIBUTE(attrib) attributes[attribCount++] = attrib;
#define SET_ATTRIBUTE(attrib, value) ADD_ATTRIBUTE(attrib); ADD_ATTRIBUTE(value);

    NSOpenGLPixelFormatAttribute attributes[MAX_CONFIG_ATTRIBUTES * 2];
    bool colorSkipped = false;
    uint32_t attribCount = 0;
    for (uint32_t attrib = 0; attrib < MAX_CONFIG_ATTRIBUTES; attrib++) {
        int value = nsegl_config->attributes[attrib];
        if (value != -2) {
            bool skip;
            int nsAttrib = getNSAttribFromEGL(attrib + NSEGL_EGL_ENUM_MIN, value, colorSkipped, &skip, &colorSkipped);
            if (skip)
                continue;
            attributes[attribCount++] = nsAttrib;
            if (value != -1)
                attributes[attribCount++] = value;
        }
    }

    ADD_ATTRIBUTE(NSOpenGLPFAAccelerated);
    ADD_ATTRIBUTE(NSOpenGLPFAClosestPolicy);
    ADD_ATTRIBUTE(NSOpenGLPFADoubleBuffer);

    //TODO: set this accorsding to attributes
    SET_ATTRIBUTE(NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core);

    ADD_ATTRIBUTE(0);

#undef SET_ATTRIBUTE
#undef ADD_ATTRIBUTE

    context->pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    if (context->pixelFormat == nil)
        NSEGL_EGL_ERROR_AND_RETURN("Failed to create NS OpenGL pixel format", EGL_NOT_INITIALIZED);

    context->context = [[NSOpenGLContext alloc] initWithFormat:context->pixelFormat shareContext: (share_context ? nsegl_share_context->context : nil)];

    if (context->context == nil)
        NSEGL_EGL_ERROR_AND_RETURN("Failed to create NS OpenGL context", EGL_NOT_INITIALIZED);

    return context;
}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePbufferSurface(EGLDisplay dpy, EGLConfig config, const EGLint *attrib_list) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePixmapSurface(EGLDisplay dpy, EGLConfig config, EGLNativePixmapType pixmap, const EGLint *attrib_list) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLSurface EGLAPIENTRY eglCreateWindowSurface(EGLDisplay dpy, EGLConfig config, EGLNativeWindowType win, const EGLint *attrib_list) {
    struct NSEGLSurface* surface = malloc(sizeof(struct NSEGLSurface));

    surface->window = win;

    return surface;
}

EGLAPI EGLBoolean EGLAPIENTRY eglDestroyContext(EGLDisplay dpy, EGLContext ctx) {
    //Cast
    CAST_TO_NSEGL_CONTEXT(ctx, true);
    
    //TODO: deallocate the framework
    //[framework release];
    [nsegl_ctx->pixelFormat release];
    [nsegl_ctx->context release];

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglDestroySurface(EGLDisplay dpy, EGLSurface surface) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglGetConfigAttrib(EGLDisplay dpy, EGLConfig config, EGLint attribute, EGLint *value) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglGetConfigs(EGLDisplay dpy, EGLConfig *configs, EGLint config_size, EGLint *num_config) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLDisplay EGLAPIENTRY eglGetCurrentDisplay(void) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLSurface EGLAPIENTRY eglGetCurrentSurface(EGLint readdraw) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLDisplay EGLAPIENTRY eglGetDisplay(EGLNativeDisplayType display_id) {
    struct NSEGLDisplay* display = malloc(sizeof(struct NSEGLDisplay));

    if (display_id != 0)
        NSEGL_EGL_ERROR_AND_RETURN("'display_id' must be 0", EGL_BAD_PARAMETER);

    return display;
}

EGLAPI EGLint EGLAPIENTRY eglGetError(void) {
    EGLint crntError = lastError;
    lastError = EGL_SUCCESS;

    return crntError;
}

EGLAPI __eglMustCastToProperFunctionPointerType EGLAPIENTRY eglGetProcAddress(const char *procname) {
    CFStringRef symbolName = CFStringCreateWithCString(kCFAllocatorDefault, procname, kCFStringEncodingASCII);

    __eglMustCastToProperFunctionPointerType symbol = CFBundleGetFunctionPointerForName(framework, symbolName);

    CFRelease(symbolName);

    return symbol;
}

EGLAPI EGLBoolean EGLAPIENTRY eglInitialize(EGLDisplay dpy, EGLint *major, EGLint *minor) {
    framework = CFBundleGetBundleWithIdentifier(CFSTR("com.apple.opengl"));
    if (framework == nil)
        NSEGL_EGL_ERROR_AND_RETURN("Failed to create NS OpenGL framework", EGL_NOT_INITIALIZED);

    //TODO: set this to something else?
    *major = 0;
    *minor = 0;

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglMakeCurrent(EGLDisplay dpy, EGLSurface draw, EGLSurface read, EGLContext ctx) {
    //Cast
    CAST_TO_NSEGL_DISPLAY(dpy);
    CAST_TO_NSEGL_SURFACE(draw);
    CAST_TO_NSEGL_CONTEXT(ctx, true);

    if (draw != read)
        NSEGL_EGL_ERROR_AND_RETURN("Cannot draw and read from different surfaces", EGL_NOT_INITIALIZED);

    NSView* view = [nsegl_draw->window contentView];

    [view setWantsBestResolutionOpenGLSurface:true]; //TODO: set this to true only if the screen is retina
    [nsegl_ctx->context setView:view];

    [nsegl_ctx->context makeCurrentContext];

    nsegl_dpy->context = nsegl_ctx; //HACK: this needs to be done for the swap buffers

    currentContext = nsegl_ctx;

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglQueryContext(EGLDisplay dpy, EGLContext ctx, EGLint attribute, EGLint *value) {
    //Cast
    CAST_TO_NSEGL_DISPLAY(dpy);
    CAST_TO_NSEGL_CONTEXT(ctx, true);

    *value = nsegl_ctx->config->attributes[attribute - NSEGL_EGL_ENUM_MIN];

    return EGL_TRUE;
}

EGLAPI const char *EGLAPIENTRY eglQueryString(EGLDisplay dpy, EGLint name) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglQuerySurface(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint *value) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglSwapBuffers(EGLDisplay dpy, EGLSurface surface) {
    //Cast
    CAST_TO_NSEGL_DISPLAY(dpy);

    //TODO: wait if it's occluded?
    [nsegl_dpy->context->context flushBuffer];

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglTerminate(EGLDisplay dpy) {
    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitGL(void) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitNative(EGLint engine) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

//------------------------ EGL_VERSION_1_1 ------------------------
EGLAPI EGLBoolean EGLAPIENTRY eglBindTexImage(EGLDisplay dpy, EGLSurface surface, EGLint buffer) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglReleaseTexImage(EGLDisplay dpy, EGLSurface surface, EGLint buffer) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglSurfaceAttrib(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint value) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglSwapInterval(EGLDisplay dpy, EGLint interval) {
    //Cast
    CAST_TO_NSEGL_DISPLAY(dpy);

    [nsegl_dpy->context->context setValues:&interval
                              forParameter:NSOpenGLContextParameterSwapInterval];
    
    return EGL_TRUE;
}


//------------------------ EGL_VERSION_1_2 ------------------------
EGLAPI EGLBoolean EGLAPIENTRY eglBindAPI(EGLenum api) {
    if (api != EGL_OPENGL_API)
        NSEGL_EGL_ERROR_AND_RETURN("API must be 'EGL_OPENGL_API'", EGL_BAD_PARAMETER);

    return EGL_TRUE;
}

EGLAPI EGLenum EGLAPIENTRY eglQueryAPI(void) {
    return EGL_OPENGL_API;
}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePbufferFromClientBuffer(EGLDisplay dpy, EGLenum buftype, EGLClientBuffer buffer, EGLConfig config, const EGLint *attrib_list) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglReleaseThread(void) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitClient(void) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

//------------------------ EGL_VERSION_1_3 ------------------------

//------------------------ EGL_VERSION_1_4 ------------------------
EGLAPI EGLContext EGLAPIENTRY eglGetCurrentContext(void) {
    return currentContext;
}

//------------------------ EGL_VERSION_1_5 ------------------------
EGLAPI EGLSync EGLAPIENTRY eglCreateSync(EGLDisplay dpy, EGLenum type, const EGLAttrib *attrib_list) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglDestroySync(EGLDisplay dpy, EGLSync sync) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLint EGLAPIENTRY eglClientWaitSync(EGLDisplay dpy, EGLSync sync, EGLint flags, EGLTime timeout) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglGetSyncAttrib(EGLDisplay dpy, EGLSync sync, EGLint attribute, EGLAttrib *value) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLImage EGLAPIENTRY eglCreateImage(EGLDisplay dpy, EGLContext ctx, EGLenum target, EGLClientBuffer buffer, const EGLAttrib *attrib_list) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglDestroyImage(EGLDisplay dpy, EGLImage image) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLDisplay EGLAPIENTRY eglGetPlatformDisplay(EGLenum platform, void *native_display, const EGLAttrib *attrib_list) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePlatformWindowSurface(EGLDisplay dpy, EGLConfig config, void *native_window, const EGLAttrib *attrib_list) {
    return eglCreateWindowSurface(dpy, config, native_window, (EGLint*)attrib_list);
}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePlatformPixmapSurface(EGLDisplay dpy, EGLConfig config, void *native_pixmap, const EGLAttrib *attrib_list) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitSync(EGLDisplay dpy, EGLSync sync, EGLint flags) {
    NSEGL_WARN_UNSUPPORTED_AND_RETURN;
}
