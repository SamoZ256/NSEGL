#include <EGL/egl.h>

#include "common.h"

#import <Cocoa/Cocoa.h>
#import <OpenGL/OpenGL.h>

CFBundleRef framework = nil;
EGLint lastError = EGL_SUCCESS;

inline EGLBoolean logEGLError(const char* msg, EGLint errorCode) {
    NSEGL_ERROR(msg);
    lastError = errorCode;

    return EGL_FALSE;
}

struct NSEGLContext;

struct NSEGLDisplay {
    struct NSEGLContext* context;
};

#define CAST_TO_NSEGL_DISPLAY(eglDisplay) struct NSEGLDisplay* nsegl_##eglDisplay = (struct NSEGLDisplay*)eglDisplay;

struct NSEGLContext {
    NSOpenGLPixelFormat* pixelFormat;
    NSOpenGLContext* context;
};

#define CAST_TO_NSEGL_CONTEXT(eglContext) struct NSEGLContext* nsegl_##eglContext = (struct NSEGLContext*)eglContext;

struct NSEGLSurface {
    NSWindow* window;
};

#define CAST_TO_NSEGL_SURFACE(eglSurface) struct NSEGLSurface* nsegl_##eglSurface = (struct NSEGLSurface*)eglSurface;

//------------------------ EGL_VERSION_1_0 ------------------------
EGLAPI EGLBoolean EGLAPIENTRY eglChooseConfig(EGLDisplay dpy, const EGLint *attrib_list, EGLConfig *configs, EGLint config_size, EGLint *num_config) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglCopyBuffers(EGLDisplay dpy, EGLSurface surface, EGLNativePixmapType target) {

}

EGLAPI EGLContext EGLAPIENTRY eglCreateContext(EGLDisplay dpy, EGLConfig config, EGLContext share_context, const EGLint *attrib_list) {
    //Cast
    CAST_TO_NSEGL_CONTEXT(share_context);

    struct NSEGLContext* context = malloc(sizeof(struct NSEGLContext));

    NSOpenGLPixelFormatAttribute attributes[32];
    uint16_t attribIndex = 0;

#define ADD_ATTRIBUTE(attrib) attributes[attribIndex++] = attrib;
#define SET_ATTRIBUTE(attrib1, attrib2) ADD_ATTRIBUTE(attrib1); ADD_ATTRIBUTE(attrib2);

    ADD_ATTRIBUTE(NSOpenGLPFAAccelerated);
    ADD_ATTRIBUTE(NSOpenGLPFAClosestPolicy);

    //TODO: set these according to attributes
    SET_ATTRIBUTE(NSOpenGLPFAOpenGLProfile, NSOpenGLProfileVersion4_1Core);
    SET_ATTRIBUTE(NSOpenGLPFAColorSize, 8);
    SET_ATTRIBUTE(NSOpenGLPFAAlphaSize, 16);
    SET_ATTRIBUTE(NSOpenGLPFADepthSize, 32);
    SET_ATTRIBUTE(NSOpenGLPFAStencilSize, 8);
    ADD_ATTRIBUTE(NSOpenGLPFADoubleBuffer);
    SET_ATTRIBUTE(NSOpenGLPFASampleBuffers, 0);

    //TODO: find out why should I do this
    ADD_ATTRIBUTE(0);

    context->pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
    if (context->pixelFormat == nil)
        return logEGLError("Failed to create NS OpenGL pixel format", EGL_NOT_INITIALIZED);

    context->context = [[NSOpenGLContext alloc] initWithFormat:context->pixelFormat shareContext: (share_context ? nsegl_share_context->context : nil)];

    if (context->context == nil)
        return logEGLError("Failed to create NS OpenGL context", EGL_NOT_INITIALIZED);

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

    [framework release];
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

    return display;
}

EGLAPI EGLint EGLAPIENTRY eglGetError(void) {
    EGLint crntError = lastError;
    lastError = EGL_SUCCESS;

    return crntError;
}

EGLAPI __eglMustCastToProperFunctionPointerType EGLAPIENTRY eglGetProcAddress(const char *procname) {

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

}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitGL(void) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitNative(EGLint engine) {

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
        return logEGLError("API must be 'EGL_OPENGL_API'", EGL_NOT_INITIALIZED);

    return EGL_TRUE;
}

EGLAPI EGLenum EGLAPIENTRY eglQueryAPI(void) {

}

EGLAPI EGLSurface EGLAPIENTRY eglCreatePbufferFromClientBuffer(EGLDisplay dpy, EGLenum buftype, EGLClientBuffer buffer, EGLConfig config, const EGLint *attrib_list) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglReleaseThread(void) {

}

EGLAPI EGLBoolean EGLAPIENTRY eglWaitClient(void) {

}

//------------------------ EGL_VERSION_1_3 ------------------------

//------------------------ EGL_VERSION_1_4 ------------------------

//------------------------ EGL_VERSION_1_5 ------------------------
