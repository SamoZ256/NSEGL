cmake_minimum_required(VERSION 3.10)

set(CMAKE_BUILD_TYPE Release)

project(NSEGL)

add_compile_options(-Wno-deprecated-declarations)

include_directories(include)

find_library(COCOA_LIBRARY NAMES Cocoa)
find_library(OPENGL_LIBRARY NAMES OpenGL)

link_libraries(${COCOA_LIBRARY} ${OPENGL_LIBRARY})

add_subdirectory(src)
add_subdirectory(examples)
