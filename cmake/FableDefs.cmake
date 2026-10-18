# Builds the native def compiler (extern/fable-defs, a Rust crate exposing a C
# API) as a static library and exposes it as the imported target
# `fable_defs_native`. It is linked statically, so there is no DLL to ship and
# no prebuilt binary in this repository.
#
# Override the source tree with -DFABLE_DEFS_DIR=/path/to/fable-defs.

set(FABLE_DEFS_DIR "${PROJECT_SOURCE_DIR}/extern/fable-defs" CACHE PATH "fable-defs checkout")

# A clone made without --recursive lacks the submodule; fetch it rather than
# making everyone learn the git command.
if(NOT EXISTS "${FABLE_DEFS_DIR}/Cargo.toml")
  find_package(Git QUIET)
  if(GIT_FOUND)
    message(STATUS "Initializing the extern/fable-defs submodule")
    execute_process(
      COMMAND "${GIT_EXECUTABLE}" submodule update --init --recursive -- extern/fable-defs
      WORKING_DIRECTORY "${PROJECT_SOURCE_DIR}")
  endif()
endif()
if(NOT EXISTS "${FABLE_DEFS_DIR}/Cargo.toml")
  message(FATAL_ERROR
    "fable-defs sources not found at ${FABLE_DEFS_DIR}.\n"
    "Run: git submodule update --init --recursive")
endif()

find_program(CARGO cargo)
if(NOT CARGO)
  message(FATAL_ERROR
    "cargo was not found. The def compiler is built from source: install a "
    "Rust toolchain from https://rustup.rs (1.88 or newer), then reopen your "
    "shell or Visual Studio and reconfigure.")
endif()

# EgoCore is 64-bit only.
if(NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
  message(FATAL_ERROR "EgoCore must be built for x64 (got a ${CMAKE_SIZEOF_VOID_P}-byte pointer target).")
endif()
set(FABLE_DEFS_RUST_TARGET x86_64-pc-windows-msvc)

set(_target_dir "${CMAKE_BINARY_DIR}/fable-defs-target")
set(_lib "${_target_dir}/${FABLE_DEFS_RUST_TARGET}/release/def_compiler_sys.lib")

# Always release: a debug Rust build is far slower and opaque to the debugger.
# Cargo does its own up-to-date check, so this target runs every build and is
# a no-op when nothing changed. Only a static library is produced, so no Rust
# linker is needed even when cross-compiling.
add_custom_target(fable_defs_cargo
  COMMAND ${CARGO} build --locked --release --package def-compiler-sys
          --target ${FABLE_DEFS_RUST_TARGET} --target-dir "${_target_dir}"
  WORKING_DIRECTORY "${FABLE_DEFS_DIR}"
  BYPRODUCTS "${_lib}"
  COMMENT "Building native def compiler (${FABLE_DEFS_RUST_TARGET})"
  USES_TERMINAL)

add_library(fable_defs_native STATIC IMPORTED GLOBAL)
set_target_properties(fable_defs_native PROPERTIES
  IMPORTED_LOCATION "${_lib}"
  INTERFACE_INCLUDE_DIRECTORIES "${FABLE_DEFS_DIR}/packages/def-compiler-sys/include"
  # What the Rust standard library needs (cargo's native-static-libs).
  INTERFACE_LINK_LIBRARIES "ntdll;userenv;ws2_32;dbghelp")
add_dependencies(fable_defs_native fable_defs_cargo)
