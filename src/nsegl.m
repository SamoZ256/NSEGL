#include <EGL/egl.h>

#include "common.h"

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

CFBundleRef framework = nil;

struct NSEGLContext;

EGLint lastError = EGL_SUCCESS;
struct NSEGLContext* currentContext = NULL;

inline long logEGLError(const char* msg, EGLint errorCode) {
    NSEGL_ERROR(msg);
    lastError = errorCode;

    return 0;
}

//Config
#define MAX_CONFIG_ATTRIBUTES 256

struct NSEGLConfig {
    NSOpenGLPixelFormatAttribute attributes[MAX_CONFIG_ATTRIBUTES];
    uint32_t attribCount;
};

#define CAST_TO_NSEGL_CONFIG(eglConfig) struct NSEGLConfig* nsegl_##eglConfig = (struct NSEGLConfig*)eglConfig;

//Display
struct NSEGLDisplay {
    struct NSEGLContext* context;
};

#define CAST_TO_NSEGL_DISPLAY(eglDisplay) struct NSEGLDisplay* nsegl_##eglDisplay = (struct NSEGLDisplay*)eglDisplay;

//Context
struct NSEGLContext {
    NSOpenGLPixelFormat* pixelFormat;
    NSOpenGLContext* context;
};

#define CAST_TO_NSEGL_CONTEXT(eglContext) struct NSEGLContext* nsegl_##eglContext = (struct NSEGLContext*)eglContext;

//Surface
struct NSEGLSurface {
    NSWindow* window;
};

#define CAST_TO_NSEGL_SURFACE(eglSurface) struct NSEGLSurface* nsegl_##eglSurface = (struct NSEGLSurface*)eglSurface;

//Attributes
#define BAD_ATTRIBUTE(msg) \
logEGLError(msg, EGL_BAD_ATTRIBUTE); \
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
    if (config_size == 0)
        logEGLError("'config_size' must not be 0", EGL_BAD_PARAMETER);
    
    //TODO: return more than 1 config
    struct NSEGLConfig* config = malloc(sizeof(struct NSEGLConfig));
    config->attribCount = 0;

#define ADD_ATTRIBUTE(attrib) config->attributes[config->attribCount++] = attrib;
#define SET_ATTRIBUTE(attrib, value) ADD_ATTRIBUTE(attrib); ADD_ATTRIBUTE(value);

    uint32_t i = 0;
    bool colorSkipped = false;
    while (true) {
        EGLint attrib = attrib_list[i++];
        if (attrib == EGL_NONE)
            break;
        EGLint value = attrib_list[i++];

        bool skip;
        int nsAttrib = getNSAttribFromEGL(attrib, value, colorSkipped, &skip, &colorSkipped);
        if (skip)
            continue;
        SET_ATTRIBUTE(nsAttrib, value);
    }

    ADD_ATTRIBUTE(NSOpenGLPFAAccelerated);
    ADD_ATTRIBUTE(NSOpenGLPFAClosestPolicy);
    ADD_ATTRIBUTE(NSOpenGLPFADoubleBuffer);

    //TODO: set this accorsding to attributes
    SET_ATTRIBUTE(NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core);

    ADD_ATTRIBUTE(0);

    configs[0] = config;
    *num_config = 1;

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglCopyBuffers(EGLDisplay dpy, EGLSurface surface, EGLNativePixmapType target) {

}

EGLAPI EGLContext EGLAPIENTRY eglCreateContext(EGLDisplay dpy, EGLConfig config, EGLContext share_context, const EGLint *attrib_list) {
    //Cast
    CAST_TO_NSEGL_CONTEXT(share_context);
    CAST_TO_NSEGL_CONFIG(config);

    struct NSEGLContext* context = malloc(sizeof(struct NSEGLContext));

    context->pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:nsegl_config->attributes];
    if (context->pixelFormat == nil)
        return (void*)logEGLError("Failed to create NS OpenGL pixel format", EGL_NOT_INITIALIZED);

    context->context = [[NSOpenGLContext alloc] initWithFormat:context->pixelFormat shareContext: (share_context ? nsegl_share_context->context : nil)];

    if (context->context == nil)
        return (void*)logEGLError("Failed to create NS OpenGL context", EGL_NOT_INITIALIZED);

    return context;
}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePbufferSurface(EGLDisplay dpy, EGLConfig config, const EGLint *attrib_list) {

}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePixmapSurface(EGLDisplay dpy, EGLConfig config, EGLNativePixmapType pixmap, const EGLint *attrib_list) {

}

EGLAPI EGLSurface EGLAPIENTRY eglCreateWindowSurface(EGLDisplay dpy, EGLConfig config, EGLNativeWindowType win, const EGLint *attrib_list) {
    struct NSEGLSurface* surface = malloc(sizeof(struct NSEGLSurface));

    surface->window = win;

    return surface;
}

EGLAPI EGLBoolean EGLAPIENTRY eglDestroyContext(EGLDisplay dpy, EGLContext ctx) {
    //Cast
    CAST_TO_NSEGL_CONTEXT(ctx);
    
    //TODO: deallocate the framework
    //[framework release];
    [nsegl_ctx->pixelFormat release];
    [nsegl_ctx->context release];

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglDestroySurface(EGLDisplay dpy, EGLSurface surface) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglGetConfigAttrib(EGLDisplay dpy, EGLConfig config, EGLint attribute, EGLint *value) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglGetConfigs(EGLDisplay dpy, EGLConfig *configs, EGLint config_size, EGLint *num_config) {

}

EGLAPI EGLDisplay EGLAPIENTRY eglGetCurrentDisplay(void) {

}

EGLAPI EGLSurface EGLAPIENTRY eglGetCurrentSurface(EGLint readdraw) {

}

EGLAPI EGLDisplay EGLAPIENTRY eglGetDisplay(EGLNativeDisplayType display_id) {
    struct NSEGLDisplay* display = malloc(sizeof(struct NSEGLDisplay));

    if (display_id != 0)
        return (void*)logEGLError("'display_id' must be 0", EGL_BAD_PARAMETER);

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
        return logEGLError("Failed to create NS OpenGL framework", EGL_NOT_INITIALIZED);

    //TODO: set this to something else?
    *major = 0;
    *minor = 0;

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglMakeCurrent(EGLDisplay dpy, EGLSurface draw, EGLSurface read, EGLContext ctx) {
    //Cast
    CAST_TO_NSEGL_DISPLAY(dpy);
    CAST_TO_NSEGL_SURFACE(draw);
    CAST_TO_NSEGL_CONTEXT(ctx);

    if (draw != read)
        return logEGLError("Cannot draw and read from different surfaces", EGL_NOT_INITIALIZED);

    NSView* view = [nsegl_draw->window contentView];

    [view setWantsBestResolutionOpenGLSurface:true]; //TODO: set this to true only if the screen is retina
    [nsegl_ctx->context setView:view];

    [nsegl_ctx->context makeCurrentContext];

    nsegl_dpy->context = nsegl_ctx; //HACK: this needs to be done for the swap buffers

    currentContext = nsegl_ctx;

    return EGL_TRUE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglQueryContext(EGLDisplay dpy, EGLContext ctx, EGLint attribute, EGLint *value) {

}

EGLAPI const char *EGLAPIENTRY eglQueryString(EGLDisplay dpy, EGLint name) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglQuerySurface(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint *value) {

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
    NSEGL_WARN_UNSUPPORTED;

    return EGL_FALSE;
}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitNative(EGLint engine) {
    NSEGL_WARN_UNSUPPORTED;

    return EGL_FALSE;
}

//------------------------ EGL_VERSION_1_1 ------------------------
EGLAPI EGLBoolean EGLAPIENTRY eglBindTexImage(EGLDisplay dpy, EGLSurface surface, EGLint buffer) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglReleaseTexImage(EGLDisplay dpy, EGLSurface surface, EGLint buffer) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglSurfaceAttrib(EGLDisplay dpy, EGLSurface surface, EGLint attribute, EGLint value) {

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
        return logEGLError("API must be 'EGL_OPENGL_API'", EGL_BAD_PARAMETER);

    return EGL_TRUE;
}

EGLAPI EGLenum EGLAPIENTRY eglQueryAPI(void) {
    return EGL_OPENGL_API;
}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePbufferFromClientBuffer(EGLDisplay dpy, EGLenum buftype, EGLClientBuffer buffer, EGLConfig config, const EGLint *attrib_list) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglReleaseThread(void) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitClient(void) {

}

//------------------------ EGL_VERSION_1_3 ------------------------

//------------------------ EGL_VERSION_1_4 ------------------------
EGLAPI EGLContext EGLAPIENTRY eglGetCurrentContext(void) {
    return currentContext;
}

//------------------------ EGL_VERSION_1_5 ------------------------
EGLAPI EGLSync EGLAPIENTRY eglCreateSync(EGLDisplay dpy, EGLenum type, const EGLAttrib *attrib_list) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglDestroySync(EGLDisplay dpy, EGLSync sync) {

}

EGLAPI EGLint EGLAPIENTRY eglClientWaitSync(EGLDisplay dpy, EGLSync sync, EGLint flags, EGLTime timeout) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglGetSyncAttrib(EGLDisplay dpy, EGLSync sync, EGLint attribute, EGLAttrib *value) {

}

EGLAPI EGLImage EGLAPIENTRY eglCreateImage(EGLDisplay dpy, EGLContext ctx, EGLenum target, EGLClientBuffer buffer, const EGLAttrib *attrib_list) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglDestroyImage(EGLDisplay dpy, EGLImage image) {

}

EGLAPI EGLDisplay EGLAPIENTRY eglGetPlatformDisplay(EGLenum platform, void *native_display, const EGLAttrib *attrib_list) {

}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePlatformWindowSurface(EGLDisplay dpy, EGLConfig config, void *native_window, const EGLAttrib *attrib_list) {
    return eglCreateWindowSurface(dpy, config, native_window, (EGLint*)attrib_list);
}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePlatformPixmapSurface(EGLDisplay dpy, EGLConfig config, void *native_pixmap, const EGLAttrib *attrib_list) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitSync(EGLDisplay dpy, EGLSync sync, EGLint flags) {

}
