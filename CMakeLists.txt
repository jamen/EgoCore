cmake_minimum_required(VERSION 3.25)

# EgoCore build. Works with MSVC/clang-cl on Windows (including Visual Studio's
# "Open Folder" CMake support) and cross-compiles from Linux with clang-cl +
# lld-link against an xwin-provided Windows SDK:
#
#   cmake --preset linux-cross-release && cmake --build --preset linux-cross-release
#
# See README.md ("Building") and cmake/toolchain-clang-cl-xwin.cmake.

# /MD in every configuration: the Rust static library links the release CRT, and
# mixing it with /MDd produces CRT conflicts. Set before project() so CMake's
# compiler checks link with it too (xwin ships no debug CRT).
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreadedDLL")
# /Z7 keeps debug info in the objects; the linker writes the PDB. This avoids
# compilers contending for one shared .pdb under Ninja.
set(CMAKE_MSVC_DEBUG_INFORMATION_FORMAT "Embedded")

project(EgoCore LANGUAGES C CXX RC)

if(NOT WIN32)
  message(FATAL_ERROR
    "EgoCore targets Windows. To build from Linux, cross-compile with "
    "-DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-clang-cl-xwin.cmake (or use a "
    "'linux-cross-*' preset).")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(EGOCORE_REQUIRE_ADMIN "Embed a requireAdministrator manifest in Release builds" ON)

include(cmake/FableDefs.cmake)

set(SRC ${CMAKE_CURRENT_SOURCE_DIR}/EgoCore)
set(STB ${CMAKE_CURRENT_SOURCE_DIR}/StaticTerrainBankCompiler)

# StaticTerrainBank: the .stb/.ism compiler library. It is standard C++ only;
# the Win32/D3D dependencies below belong to the optional GUI tool.
add_library(StaticTerrainBank STATIC
  ${STB}/src/background_tree.cpp
  ${STB}/src/bank_resolver.cpp
  ${STB}/src/bbb_archive.cpp
  ${STB}/src/clutter.cpp
  ${STB}/src/dxt1_baker.cpp
  ${STB}/src/heightmap.cpp
  ${STB}/src/lev_reader.cpp
  ${STB}/src/local_detail_builder.cpp
  ${STB}/src/local_detail_manager.cpp
  ${STB}/src/lzo1x.cpp
  ${STB}/src/mesh_builder.cpp
  ${STB}/src/range_compressor.cpp
  ${STB}/src/sea_generator.cpp
  ${STB}/src/stb_compiler.cpp
  ${STB}/src/stripifier.cpp
  ${STB}/src/theme_manager.cpp
)
target_include_directories(StaticTerrainBank PUBLIC ${STB}/include)
target_compile_features(StaticTerrainBank PUBLIC cxx_std_20)
target_compile_options(StaticTerrainBank PRIVATE /permissive- /W3)
set_property(TARGET StaticTerrainBank PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)

# Standalone STB compiler (CLI + ImGui/D3D11 GUI).
add_executable(stb_compiler
  ${STB}/tools/compiler_main.cpp
  ${STB}/tools/gui.cpp
  ${STB}/tools/imgui/imgui.cpp
  ${STB}/tools/imgui/imgui_demo.cpp
  ${STB}/tools/imgui/imgui_draw.cpp
  ${STB}/tools/imgui/imgui_impl_dx11.cpp
  ${STB}/tools/imgui/imgui_impl_win32.cpp
  ${STB}/tools/imgui/imgui_tables.cpp
  ${STB}/tools/imgui/imgui_widgets.cpp
)
target_include_directories(stb_compiler PRIVATE ${STB}/tools/imgui)
target_compile_features(stb_compiler PRIVATE cxx_std_20)
target_compile_options(stb_compiler PRIVATE /permissive- /W3)
target_link_libraries(stb_compiler PRIVATE
  StaticTerrainBank
  d3d11 d3dcompiler dxgi shell32 ole32 user32 gdi32 comdlg32 advapi32 dwmapi imm32)

add_executable(EgoCore WIN32
  ${SRC}/main.cpp
  ${SRC}/TextEditor/TextEditor.cpp
  ${SRC}/Utilities/ImGUI/imgui.cpp
  ${SRC}/Utilities/ImGUI/imgui_demo.cpp
  ${SRC}/Utilities/ImGUI/imgui_draw.cpp
  ${SRC}/Utilities/ImGUI/imgui_impl_dx11.cpp
  ${SRC}/Utilities/ImGUI/imgui_impl_win32.cpp
  ${SRC}/Utilities/ImGUI/imgui_tables.cpp
  ${SRC}/Utilities/ImGUI/imgui_widgets.cpp
  ${SRC}/Utilities/miniaudio.c
  ${SRC}/Utilities/minilzo.c
  ${SRC}/EgoCore.rc
)

# The headers include each other by bare file name across feature directories.
file(GLOB feature_dirs LIST_DIRECTORIES true CONFIGURE_DEPENDS ${SRC}/*)
foreach(d IN LISTS feature_dirs)
  if(IS_DIRECTORY ${d})
    target_include_directories(EgoCore PRIVATE ${d})
  endif()
endforeach()
target_include_directories(EgoCore PRIVATE ${SRC} ${SRC}/Utilities ${SRC}/Utilities/ImGUI ${STB}/include)

# _DEBUG is deliberately not defined: with /MD it makes the STL headers request
# the debug CRT import libraries (msvcprtd.lib), which the Rust lib can't share.
target_compile_definitions(EgoCore PRIVATE UNICODE _UNICODE)
# clang-cl and cl both accept these.
target_compile_options(EgoCore PRIVATE /permissive- /W3 /sdl /bigobj)
# Vendored third-party C; its warnings are not ours to fix.
set_source_files_properties(${SRC}/Utilities/minilzo.c PROPERTIES COMPILE_OPTIONS /w)
set_property(TARGET EgoCore PROPERTY INTERPROCEDURAL_OPTIMIZATION_RELEASE ON)
# Release gets a PDB too, for debugging crashes in shipped builds. /DEBUG turns
# off unreferenced-code removal and folding by default, so ask for them back.
target_link_options(EgoCore PRIVATE "$<$<CONFIG:Release>:/DEBUG;/OPT:REF;/OPT:ICF>")

# Sources use #pragma comment(lib, ...) for most of these; listing them keeps
# the link line explicit.
target_link_libraries(EgoCore PRIVATE
  StaticTerrainBank
  d3d11 d3dcompiler dxgi shell32 ole32 user32 gdi32 comdlg32 advapi32 dwmapi
  fable_defs_native)

if(EGOCORE_REQUIRE_ADMIN)
  target_link_options(EgoCore PRIVATE "$<$<CONFIG:Release>:/MANIFESTUAC:level='requireAdministrator'>")
endif()

install(TARGETS EgoCore stb_compiler RUNTIME DESTINATION .)
install(FILES ${SRC}/imgui.ini DESTINATION .)
