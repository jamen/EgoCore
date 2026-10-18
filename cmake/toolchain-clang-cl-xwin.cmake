# Cross-compile for Windows x64 from Linux (or macOS) with clang-cl + lld-link
# against a Windows SDK/CRT fetched by xwin (https://github.com/Jake-Shadle/xwin).
#
#   xwin --accept-license --temp splat --output "$XWIN_DIR"   # once, ~1 GB
#   cmake -G Ninja -DCMAKE_TOOLCHAIN_FILE=cmake/toolchain-clang-cl-xwin.cmake ...
#
# XWIN_DIR may be given as a CMake variable or an environment variable. It is
# baked into the compiler and linker flags on the first configure, so to point
# an existing build directory at a different SDK, reconfigure with --fresh.
# Needs on PATH: clang-cl, lld-link, llvm-rc, llvm-mt (all from LLVM).
# The project must select the release CRT (/MD) before project(): xwin ships no
# debug CRT, so CMake's compiler checks would otherwise fail to link.

if(NOT XWIN_DIR AND DEFINED ENV{XWIN_DIR})
  set(XWIN_DIR "$ENV{XWIN_DIR}")
endif()
if(NOT XWIN_DIR OR NOT EXISTS "${XWIN_DIR}/crt/include")
  message(FATAL_ERROR
    "XWIN_DIR must point at an `xwin splat` output directory "
    "(containing crt/ and sdk/). Got: '${XWIN_DIR}'")
endif()
set(XWIN_DIR "${XWIN_DIR}" CACHE PATH "xwin splat directory")
# CMake re-reads this file for its compiler checks in a fresh scope; without
# this, a -DXWIN_DIR given only on the command line is lost there.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES XWIN_DIR)

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR AMD64)

set(_triple x86_64-pc-windows-msvc)
set(CMAKE_C_COMPILER_TARGET ${_triple})
set(CMAKE_CXX_COMPILER_TARGET ${_triple})
set(CMAKE_C_COMPILER clang-cl)
set(CMAKE_CXX_COMPILER clang-cl)
set(CMAKE_LINKER lld-link)
set(CMAKE_RC_COMPILER llvm-rc)
set(CMAKE_MT llvm-mt)

set(_inc
  "${XWIN_DIR}/crt/include"
  "${XWIN_DIR}/sdk/include/ucrt"
  "${XWIN_DIR}/sdk/include/um"
  "${XWIN_DIR}/sdk/include/shared"
  "${XWIN_DIR}/sdk/include/winrt")  # <wrl/client.h>
set(_imsvc "")
set(_rc_inc "")
foreach(d IN LISTS _inc)
  string(APPEND _imsvc " /imsvc \"${d}\"")
  string(APPEND _rc_inc " /I \"${d}\"")
endforeach()

set(CMAKE_C_FLAGS_INIT "${_imsvc}")
set(CMAKE_CXX_FLAGS_INIT "${_imsvc}")
set(CMAKE_RC_FLAGS_INIT "${_rc_inc}")

set(_libs
  "/libpath:\"${XWIN_DIR}/crt/lib/x86_64\""
  "/libpath:\"${XWIN_DIR}/sdk/lib/um/x86_64\""
  "/libpath:\"${XWIN_DIR}/sdk/lib/ucrt/x86_64\"")
list(JOIN _libs " " _libflags)
set(CMAKE_EXE_LINKER_FLAGS_INIT "${_libflags}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_libflags}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_libflags}")
