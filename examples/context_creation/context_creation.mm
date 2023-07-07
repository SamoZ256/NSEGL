#import <Cocoa/Cocoa.h>

#include <EGL/egl.h>

#import <OpenGL/gl3.h>

const EGLint egl_config_attribs[] = {
    EGL_COLOR_BUFFER_TYPE,     EGL_RGB_BUFFER,
    EGL_BUFFER_SIZE,           32,
    EGL_RED_SIZE,              8,
    EGL_GREEN_SIZE,            8,
    EGL_BLUE_SIZE,             8,
    EGL_ALPHA_SIZE,            8,

    EGL_DEPTH_SIZE,            24,
    EGL_STENCIL_SIZE,          8,

    EGL_SAMPLE_BUFFERS,        0,
    EGL_SAMPLES,               0,

    EGL_SURFACE_TYPE,          EGL_WINDOW_BIT,
    EGL_RENDERABLE_TYPE,       EGL_OPENGL_ES2_BIT,

    EGL_NONE,
};

const EGLint egl_context_attribs[] = {
    EGL_CONTEXT_CLIENT_VERSION, 2,
    EGL_NONE,
};

const EGLint egl_surface_attribs[] = {
    EGL_RENDER_BUFFER, EGL_BACK_BUFFER,
    EGL_NONE,
};

void createEGLContext(EGLint api, EGLNativeDisplayType native_display, EGLNativeWindowType native_window, EGLDisplay* out_display, EGLConfig* out_config, EGLContext* out_context, EGLSurface* out_window_surface) {
    EGLint ignore;
    EGLBoolean ok;

    ok = eglBindAPI(api);
    if (!ok)
        fprintf(stderr, "eglBindAPI(0x%x) failed\n", api);

    EGLDisplay display = eglGetDisplay(native_display);
    if (display == EGL_NO_DISPLAY)
        fprintf(stderr, "eglGetDisplay() failed\n");

    ok = eglInitialize(display, &ignore, &ignore);
    if (!ok)
        fprintf(stderr, "eglInitialize() failed\n");

    EGLint configs_size = 256;
    EGLConfig* configs = new EGLConfig[configs_size];
    EGLint num_configs;
    ok = eglChooseConfig(
        display,
        egl_config_attribs,
        configs,
        configs_size, // num requested configs
        &num_configs); // num returned configs
    if (!ok)
        fprintf(stderr, "eglChooseConfig() failed\n");
    if (num_configs == 0)
        fprintf(stderr, "failed to find suitable EGLConfig\n");
    EGLConfig config = configs[0];
    delete [] configs;

    EGLContext context = eglCreateContext(
        display,
        config,
        EGL_NO_CONTEXT,
        egl_context_attribs);
    if (!context)
        fprintf(stderr, "eglCreateContext() failed\n");

    EGLSurface surface = eglCreateWindowSurface(
        display,
        config,
        native_window,
        egl_surface_attribs);
    if (!surface)
        fprintf(stderr, "eglCreateWindowSurface() failed\n");

    ok = eglMakeCurrent(display, surface, surface, context);
    if (!ok)
        fprintf(stderr, "eglMakeCurrent() failed\n");

    // Check if surface is double buffered.
    EGLint render_buffer;
    ok = eglQueryContext(
        display,
        context,
        EGL_RENDER_BUFFER,
        &render_buffer);
    if (!ok)
        fprintf(stderr, "eglQueyContext(EGL_RENDER_BUFFER) failed\n");
    if (render_buffer == EGL_SINGLE_BUFFER)
        printf("warn: EGL surface is single buffered\n");

    *out_display = display;
    *out_config = config;
    *out_context = context;
    *out_window_surface = surface;
}

EGLDisplay g_display;
EGLSurface g_surface;

@interface View : NSView {
    
}

@end

@implementation View

- (void)drawRect:(NSRect)rect {
    glClearColor(1.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    EGLBoolean ok = eglSwapBuffers(g_display, g_surface);
    if (ok == EGL_FALSE) {
        printf("eglSwapBuffers failed: %d\n", eglGetError());
        exit(EXIT_FAILURE);
    }
    NSLog(@"Swap");
}

@end

int main(void) {
    @autoreleasepool {

    [NSApplication sharedApplication];

    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp activateIgnoringOtherApps:YES];
    });

    NSWindow* window = [[NSWindow alloc] autorelease];
    [window
        initWithContentRect:NSMakeRect(0, 0, 960, 540)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered
        defer:NO];
    
    [window center];
    
    NSView* view = [[View alloc] init];
    if (view == nil) {
        fprintf(stderr, "Failed to create NS view\n");
    }

    [window setContentView:view];
    [window makeFirstResponder:view];
    //[window setDelegate:windowDelegate];
    //[window setAcceptsMouseMovedEvents:YES];
    //[window setRestorable:NO];

    [NSApp activateIgnoringOtherApps:YES];
    [window makeKeyAndOrderFront:view];

    EGLConfig egl_config;
    EGLContext egl_context;
    createEGLContext(EGL_OPENGL_API,
              0,
              window,
              &g_display,
              &egl_config,
              &egl_context,
              &g_surface);

    [NSApp run];

    }

    return 0;
}
