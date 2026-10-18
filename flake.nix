{
  description = "EgoCore — Windows build environment (cross-compiles from Linux)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rust-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };
      # Only a static library is built from Rust, so the MSVC target's std is
      # enough; the host std is for build scripts and proc macros.
      rust = pkgs.rust-bin.stable.latest.minimal.override {
        targets = [ "x86_64-pc-windows-msvc" ];
      };
      # Unwrapped LLVM tools: the nix cc-wrapper around `clang-cl` injects
      # Linux flags (-fPIC, hardening) that break cross-compiling and llvm-rc.
      llvm = pkgs.llvmPackages;
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          rust
          pkgs.cmake
          pkgs.ninja
          pkgs.xwin
          llvm.clang-unwrapped
          llvm.lld
          llvm.bintools-unwrapped
        ];
        shellHook = ''
          # Windows SDK + CRT, fetched once by `xwin` (see README, "Building").
          # Kept outside the repo so deleting build/ doesn't throw it away.
          export XWIN_DIR="''${XWIN_DIR:-''${XDG_CACHE_HOME:-$HOME/.cache}/egocore/xwin}"
        '';
      };
    };
}
