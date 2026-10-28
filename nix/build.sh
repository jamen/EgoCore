#!/usr/bin/env bash
# Cross-compile EgoCore and stb_compiler for Windows x64 using clang-cl + lld-link
# against an xwin-splatted Windows SDK. This is the Nix build path; the Visual
# Studio projects remain the canonical Windows build.
set -euo pipefail

SRC="${SRC:-$(pwd)}"
OUT="${OUT:-$SRC/out}"
: "${XWIN_DIR:?XWIN_DIR must point at an xwin splat directory}"
: "${FABLE_DEFS_INCLUDE:?FABLE_DEFS_INCLUDE must point at fable-defs include}"
: "${FABLE_DEFS_LIB:?FABLE_DEFS_LIB must point at def_compiler_sys.lib}"

CLANG_CL="${CLANG_CL:-clang-cl}"
LLD_LINK="${LLD_LINK:-lld-link}"
LLVM_RC="${LLVM_RC:-llvm-rc}"
LLVM_LIB="${LLVM_LIB:-llvm-lib}"

OBJ="$OUT/obj"
mkdir -p "$OBJ/stb" "$OBJ/tools" "$OBJ/app" "$OUT"

SDK_INCLUDES=(
  "/imsvc$XWIN_DIR/crt/include"
  "/imsvc$XWIN_DIR/sdk/include/ucrt"
  "/imsvc$XWIN_DIR/sdk/include/um"
  "/imsvc$XWIN_DIR/sdk/include/shared"
  "/imsvc$XWIN_DIR/sdk/include/winrt"
)
SDK_LIBPATHS=(
  "$XWIN_DIR/crt/lib/x86_64"
  "$XWIN_DIR/sdk/lib/um/x86_64"
  "$XWIN_DIR/sdk/lib/ucrt/x86_64"
)

COMMON=(
  --target=x86_64-pc-windows-msvc
  /nologo
  /DWIN32 /D_WINDOWS
  /O2 /Ob2 /DNDEBUG
  -MD -Z7
  /permissive- /W3
)
CXX_FLAGS=(/EHsc /sdl /bigobj -std:c++20)

STB_INCLUDES=(-I"$SRC/StaticTerrainBankCompiler/include")
APP_INCLUDES=(
  -I"$SRC/StaticTerrainBankCompiler/include"
  -I"$SRC/EgoCore"
  -I"$SRC/EgoCore/Utilities"
  -I"$SRC/EgoCore/Utilities/ImGUI"
  "/imsvc$FABLE_DEFS_INCLUDE"
)
for d in "$SRC"/EgoCore/*/; do
  APP_INCLUDES+=("-I${d%/}")
done

STB_SOURCES=(
  background_tree.cpp
  bank_resolver.cpp
  bbb_archive.cpp
  clutter.cpp
  dxt1_baker.cpp
  heightmap.cpp
  lev_reader.cpp
  local_detail_builder.cpp
  local_detail_manager.cpp
  lzo1x.cpp
  mesh_builder.cpp
  range_compressor.cpp
  sea_generator.cpp
  stb_compiler.cpp
  stripifier.cpp
  theme_manager.cpp
)
TOOL_SOURCES=(
  tools/compiler_main.cpp
  tools/gui.cpp
  tools/imgui/imgui.cpp
  tools/imgui/imgui_demo.cpp
  tools/imgui/imgui_draw.cpp
  tools/imgui/imgui_impl_dx11.cpp
  tools/imgui/imgui_impl_win32.cpp
  tools/imgui/imgui_tables.cpp
  tools/imgui/imgui_widgets.cpp
)
APP_SOURCES=(
  main.cpp
  TextEditor/TextEditor.cpp
  Utilities/ImGUI/imgui.cpp
  Utilities/ImGUI/imgui_demo.cpp
  Utilities/ImGUI/imgui_draw.cpp
  Utilities/ImGUI/imgui_impl_dx11.cpp
  Utilities/ImGUI/imgui_impl_win32.cpp
  Utilities/ImGUI/imgui_tables.cpp
  Utilities/ImGUI/imgui_widgets.cpp
  Utilities/minilzo.c
)

compile_cpp() {
  local src="$1" obj="$2"
  shift 2
  "$CLANG_CL" "${COMMON[@]}" "${CXX_FLAGS[@]}" "$@" -Fo"$obj" -c "$src"
}

compile_c() {
  local src="$1" obj="$2"
  shift 2
  "$CLANG_CL" "${COMMON[@]}" "$@" -Fo"$obj" -c "$src"
}

STB_OBJS=()
for f in "${STB_SOURCES[@]}"; do
  obj="$OBJ/stb/${f%.cpp}.obj"
  mkdir -p "$(dirname "$obj")"
  compile_cpp "$SRC/StaticTerrainBankCompiler/src/$f" "$obj" "${SDK_INCLUDES[@]}" "${STB_INCLUDES[@]}"
  STB_OBJS+=("$obj")
done

LIB_RSP="$OUT/staticterrainbank.rsp"
{
  echo "/OUT:\"$OUT/StaticTerrainBank.lib\""
  for o in "${STB_OBJS[@]}"; do echo "\"$o\""; done
} > "$LIB_RSP"
"$LLVM_LIB" @"$LIB_RSP"

TOOL_OBJS=()
for f in "${TOOL_SOURCES[@]}"; do
  obj="$OBJ/tools/${f%.cpp}.obj"
  mkdir -p "$(dirname "$obj")"
  compile_cpp "$SRC/StaticTerrainBankCompiler/$f" "$obj" "${SDK_INCLUDES[@]}" "${STB_INCLUDES[@]}" -I"$SRC/StaticTerrainBankCompiler/tools/imgui"
  TOOL_OBJS+=("$obj")
done

write_link_rsp() {
  local out="$1" subsystem="$2" entry_kind="$3" manifest_uac="$4"
  shift 4
  {
    echo "/nologo"
    echo "/OUT:\"$out\""
    echo "/MACHINE:X64"
    echo "/INCREMENTAL:NO"
    echo "/SUBSYSTEM:$subsystem"
    echo "/DEBUG"
    echo "/OPT:REF"
    echo "/OPT:ICF"
    if [[ "$manifest_uac" == "admin" ]]; then
      echo "/MANIFESTUAC:level='requireAdministrator'"
    fi
    for p in "${SDK_LIBPATHS[@]}"; do echo "/libpath:\"$p\""; done
    for a in "$@"; do echo "\"$a\""; done
    echo "d3d11.lib"
    echo "d3dcompiler.lib"
    echo "dxgi.lib"
    echo "shell32.lib"
    echo "ole32.lib"
    echo "user32.lib"
    echo "gdi32.lib"
    echo "comdlg32.lib"
    echo "advapi32.lib"
    echo "dwmapi.lib"
    echo "imm32.lib"
    if [[ "$entry_kind" == "app" ]]; then
      echo "\"$FABLE_DEFS_LIB\""
      echo "ntdll.lib"
      echo "userenv.lib"
      echo "ws2_32.lib"
      echo "dbghelp.lib"
    fi
    echo "kernel32.lib"
    echo "user32.lib"
    echo "gdi32.lib"
    echo "winspool.lib"
    echo "shell32.lib"
    echo "ole32.lib"
    echo "oleaut32.lib"
    echo "uuid.lib"
    echo "comdlg32.lib"
    echo "advapi32.lib"
  } > "$OUT/link-$entry_kind.rsp"
}

write_link_rsp "$OUT/stb_compiler.exe" CONSOLE tools none "$OUT/StaticTerrainBank.lib" "${TOOL_OBJS[@]}"
"$LLD_LINK" @"$OUT/link-tools.rsp"

APP_OBJS=()
for f in "${APP_SOURCES[@]}"; do
  obj="$OBJ/app/${f%.*}.obj"
  mkdir -p "$(dirname "$obj")"
  if [[ "$f" == *.c ]]; then
    compile_c "$SRC/EgoCore/$f" "$obj" "${SDK_INCLUDES[@]}" "${APP_INCLUDES[@]}"
  else
    compile_cpp "$SRC/EgoCore/$f" "$obj" "${SDK_INCLUDES[@]}" "${APP_INCLUDES[@]}"
  fi
  APP_OBJS+=("$obj")
done

RC_FLAGS=()
for d in "$XWIN_DIR/crt/include" "$XWIN_DIR/sdk/include/ucrt" "$XWIN_DIR/sdk/include/um" "$XWIN_DIR/sdk/include/shared" "$XWIN_DIR/sdk/include/winrt"; do
  RC_FLAGS+=(/I "$d")
done
RC_FLAGS+=(/I "$SRC/EgoCore" /D UNICODE /D _UNICODE)
"$LLVM_RC" /nologo /FO "$OBJ/app/EgoCore.res" "${RC_FLAGS[@]}" "$SRC/EgoCore/EgoCore.rc"
APP_OBJS+=("$OBJ/app/EgoCore.res")

write_link_rsp "$OUT/EgoCore.exe" WINDOWS app admin "$OUT/StaticTerrainBank.lib" "${APP_OBJS[@]}"
"$LLD_LINK" @"$OUT/link-app.rsp"

echo "Built:"
ls -lh "$OUT/EgoCore.exe" "$OUT/stb_compiler.exe"
