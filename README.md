## About The Project

When EGL was released, it was meant to be a solution for all platforms for creating an OpenGL context. But other APIs, like GLX and NSOpenGL, already existed, and therefore the success of EGL was limited. This project aims to provide EGL support for MacOS by translating EGL to NSOpenGL.



## Getting Started

All the necessary EGL include files are inside the include directory.

### Installation

1. Clone the repo
   `sh git clone https://github.com/SamoZ256/NSEGL.git`
2. Enter the directory
   `cd NSEGL`
3. Create a build directory
   `mkdir build`
4. Enter the build directory
   `cd build`
5. Initialize CMake
   `cmake ..`
5. `make`



## Usage

There are a few notable things. First, the argument `display_id` in function `eglGetDisplay` must be 0. Currently, it isn't used for anything, but that may change in the future. Second, the type of `EGLNativeWindowType` is `NSWindow*`. Pass the `NSWindow*` you created as a parameter to the `eglCreateWindowSurface` function.



## License

Distributed under the APACHE 2.0 License. See `LICENSE.txt` for more information.
