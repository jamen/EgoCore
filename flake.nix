{
  description = "EgoCore — Windows builds via Visual Studio, plus a Nix cross-build from Linux";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Keep this in sync with FableDefs in the repository.
    fable-defs = {
      url = "git+https://github.com/jamen/fable-defs?rev=fc6598ad442c60857ecb8735c97b1d1160ceec4a";
      flake = false;
    };
  };

  outputs =
    { self, nixpkgs, rust-overlay, fable-defs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ (import rust-overlay) ];
      };
      lib = pkgs.lib;
      llvm = pkgs.llvmPackages;
      rust = pkgs.rust-bin.stable.latest.minimal.override {
        targets = [ "x86_64-pc-windows-msvc" ];
      };

      # xwin downloads and repacks the MSVC CRT and Windows SDK. Fixed output
      # keeps the SDK reproducible and lets Nix substitute it from the cache.
      windowsSdk = pkgs.stdenvNoCC.mkDerivation {
        pname = "xwin-windows-sdk";
        version = "latest";
        nativeBuildInputs = [ pkgs.xwin pkgs.cacert ];
        dontUnpack = true;
        dontFixup = true;
        buildPhase = ''
          export HOME="$TMPDIR"
          export SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
          # xwin moves files from its temp directory into the output. Keep both
          # on the same filesystem, then copy the completed splat into $out.
          xwin --accept-license --temp --arch x86_64 --http-retry 5 --timeout 300 splat --output "$TMPDIR/sdk"
          mkdir -p "$out"
          cp -a "$TMPDIR/sdk/." "$out/"
        '';
        outputHashMode = "recursive";
        outputHashAlgo = "sha256";
        outputHash = "sha256-UFQjsFVBwcF/9e9tVFoG0Z1JySxyTnFqoaRwr/tUWzA=";
      };

      fableDefs = pkgs.stdenv.mkDerivation {
        pname = "fable-defs-native";
        version = "fc6598a";
        src = fable-defs;
        nativeBuildInputs = [ rust pkgs.rustPlatform.cargoSetupHook ];
        cargoDeps = pkgs.rustPlatform.importCargoLock {
          lockFile = "${fable-defs}/Cargo.lock";
        };
        dontConfigure = true;
        buildPhase = ''
          export CARGO_BUILD_TARGET=x86_64-pc-windows-msvc
          export CARGO_TARGET_DIR=target
          cargo build --offline --locked --release --package def-compiler-sys
        '';
        installPhase = ''
          mkdir -p "$out/lib" "$out/include"
          cp target/x86_64-pc-windows-msvc/release/def_compiler_sys.lib "$out/lib/"
          cp -r packages/def-compiler-sys/include/. "$out/include/"
        '';
        dontStrip = true;
      };

      egocore = pkgs.stdenv.mkDerivation {
        pname = "egocore";
        version = "unstable-${self.shortRev or "dirty"}";
        src = self;
        nativeBuildInputs = [
          llvm.clang-unwrapped
          llvm.lld
          llvm.bintools-unwrapped
        ];
        outputs = [ "out" "stb" ];
        dontConfigure = true;
        dontStrip = true;
        buildPhase = ''
          export XWIN_DIR=${windowsSdk}
          export FABLE_DEFS_INCLUDE=${fableDefs}/include
          export FABLE_DEFS_LIB=${fableDefs}/lib/def_compiler_sys.lib
          export OUT="$PWD/out"
          bash nix/build.sh
        '';
        installPhase = ''
          mkdir -p "$out/bin" "$stb/bin"
          cp out/EgoCore.exe "$out/bin/"
          cp out/stb_compiler.exe "$stb/bin/"
        '';
        meta.mainProgram = "EgoCore.exe";
      };

      stbCompiler = pkgs.runCommand "egocore-stb-${self.shortRev or "dirty"}" {
        meta.mainProgram = "stb_compiler.exe";
      } ''
        mkdir -p "$out/bin"
        cp ${egocore.stb}/bin/stb_compiler.exe "$out/bin/"
      '';
    in
    {
      packages.${system} = {
        default = egocore;
        egocore = egocore;
        stb-compiler = stbCompiler;
        windows-sdk = windowsSdk;
        fable-defs = fableDefs;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          rust
          pkgs.xwin
          llvm.clang-unwrapped
          llvm.lld
          llvm.bintools-unwrapped
          pkgs.cacert
        ];
        shellHook = ''
          export XWIN_DIR="''${XWIN_DIR:-${windowsSdk}}"
        '';
      };
    };
}
