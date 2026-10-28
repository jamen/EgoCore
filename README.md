# EgoCore - Asset Bank Editor for Fable

EgoCore is the culmination of over twenty years of obsession with the inner workings of Fable. What began as programming-related curiosity has evolved into an intensive development journey to provide the community with a modern, robust, and versatile modding framework.

I believe the tools to keep this game alive should be accessible to everyone. That is why EgoCore is, and will always be, Free and Open Source.

## ✨ Key Features

* **Full Bank Editing & Recompilation:** Deep dive into Fable's archive formats (`.big`, `.lut`, `.lug`). **EACH parsed bank can be fully edited and recompiled from the ground up.**
* **3D Mesh & GLTF Pipeline:** Integrated mesh rendering and full bidirectional GLTF import/export support. Bring modern 3D models into Fable or extract vanilla assets flawlessly.
* **Definition Editor & Compiler:** A powerful built-in workspace for viewing, editing, and compiling game definitions, featuring automatic lookup dictionary generation.
* **Fable Script Extender (FSE) Support:** A dedicated environment bridging raw `.lua` scripts with the internal Fable API, complete with smart autosuggest.
* **Advanced Audio Tooling:** Built-in LUG and MET parsing for exploring, extracting, and modifying Fable's complex audio banks.
* **Mod Manager & Creator:** Package your custom modifications cleanly, manage your load order, and safely deploy them without permanently destroying vanilla files.
* **WAD Decompiler:** Fully automated extraction of `FinalAlbion.wad` into its raw `.lev` and `.tng` components.

## 🚀 Getting Started

1. **Extract the Archive:** Unpack the EgoCore folder anywhere on your PC. 
2. **Launch:** Run `EgoCore.exe`.
3. **Setup:** On your first launch, EgoCore will ask for your Fable installation directory (the folder containing `Fable.exe` and the `Data` folder).
4. **Decompile FinalAlbion (Recommended):** If prompted, allow EgoCore to decompile the master WAD file. This is crucial for seamless map editing.
5. **Fix modding environment and install FableScriptExtender (Recommended):** If prompted, allow EgoCore to fix your modding environment and install FableScriptExtender into your game. This will enable definition editing and compilation and also quest script editing.

*Fun fact: You can change the EgoCore font, by replacing the Font.ttf file with a .ttf true type font file of your own.

## ⚙️ Requirements

* A clean installation of Fable: The Lost Chapters.
* Windows 10 / 11 (64-bit).

## 🛠️ Building

### Windows / Visual Studio

Open `EgoCore.sln` in Visual Studio 2022 and build the `x64` `Release` or `Debug` configuration. The solution includes both the EgoCore application and the `StaticTerrainBankCompiler` project; `stb_compiler.exe` can also be built with the batch scripts in `StaticTerrainBankCompiler/`.

### Linux → Windows cross-build with Nix

The repository includes a Nix flake that cross-compiles the Windows executables from Linux using clang-cl, lld-link, and a pinned Windows SDK downloaded through `xwin`:

```sh
nix build .#egocore        # builds EgoCore.exe and stb_compiler.exe
nix build .#stb-compiler   # exposes only stb_compiler.exe
nix build .#windows-sdk    # the xwin SDK used by the build
nix build .#fable-defs     # the native Rust def compiler
```

`nix build .#egocore` produces `result/bin/EgoCore.exe`; `nix build .#stb-compiler` produces `result/bin/stb_compiler.exe`.

For interactive development, use the dev shell:

```sh
nix develop
# or, with direnv:
direnv allow
```

The dev shell provides the Rust toolchain, clang-cl, lld, the LLVM resource/bin tools, and `xwin`. `XWIN_DIR` points at the Nix-provided Windows SDK. This cross-builds Windows binaries on Linux; it does not produce a native Linux build of EgoCore.

The Visual Studio projects remain the canonical Windows build. The Nix build is an alternate, reproducible cross-compilation path.

## 🤝 Community & Support

Developing a tool of this scale involves hundreds of hours of reverse engineering, debugging, and refinement. I don't believe in paywalling progress, so I rely entirely on the generosity of the community to keep this project sustainable. 

If EgoCore has saved you time or helped you bring a new vision to life, please consider supporting the project or joining the community:

* 💬 **Join the Conversation:** [Fable Modding Discord](https://discord.gg/Rw4as5ar3S)
*   **Fable Definition Compiler source code:** (https://github.com/jamen/fable-defs)
* 
## 📄 License

This software is provided as-is, free and open-source. Please see the `LICENSE` file for more details. 

*Fable is a registered trademark of Microsoft Corporation. EgoCore is an unofficial, community-driven project and is not affiliated with or endorsed by Microsoft or Lionhead Studios.*
