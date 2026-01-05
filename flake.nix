{
  description = "Emacs versions for CI";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };

    "emacs-28-2" = {
      url = "https://ftp.gnu.org/gnu/emacs/emacs-28.2.tar.xz";
      flake = false;
    };
    "emacs-29-4" = {
      url = "https://ftp.gnu.org/gnu/emacs/emacs-29.4.tar.xz";
      flake = false;
    };
    "emacs-30-2" = {
      url = "https://ftp.gnu.org/gnu/emacs/emacs-30.2.tar.xz";
      flake = false;
    };
    emacs-snapshot = {
      url = "github:emacs-mirror/emacs";
      flake = false;
    };
    snapshot-commercial = {
      url = "github:commercial-emacs/commercial-emacs";
      flake = false;
    };
  };

  nixConfig = {
    extra-substituters = "https://emacs-ci.cachix.org";
    extra-trusted-public-keys = "emacs-ci.cachix.org-1:B5FVOrxhXXrOL0S+tQ7USrhjMT5iOPH+QN9q0NItom4=";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    {
      packages =
        nixpkgs.lib.genAttrs
          [
            "aarch64-darwin"
            "aarch64-linux"
            "x86_64-darwin"
            "x86_64-linux"
          ]
          (
            system:
            let
              inherit (nixpkgs) lib;
              pkgs = nixpkgs.legacyPackages.${system};
              versions = {
                emacs-28-2-nativecomp = "28.2";
                emacs-29-4-nativecomp = "29.4";
                emacs-30-2 = "30.2";
                emacs-snapshot = "31.0.50";
                snapshot-commercial = "31.0.50";
              };
            in
            builtins.mapAttrs (
              name: version:
              let
                hasNativeCompSuffix = lib.strings.hasSuffix "-nativecomp" name;
                sourceInputName = if hasNativeCompSuffix
                  then lib.strings.removeSuffix "-nativecomp" name
                  else name;
                enableNativeComp = hasNativeCompSuffix || lib.versionAtLeast version "30";
              in
              pkgs.callPackage ./emacs.nix {
                inherit name version;
                inherit (pkgs.darwin) sigtool;
                src = inputs.${sourceInputName};
                latestPackageKeyring = inputs.emacs-snapshot + "/etc/package-keyring.gpg";
                srcRepo = lib.strings.hasInfix "snapshot" version;
                withNativeCompilation = enableNativeComp;
              }
            ) versions
          );

      checks = builtins.mapAttrs (
        system:
        builtins.mapAttrs (
          _name: ciEmacs:
          nixpkgs.legacyPackages.${system}.callPackage ./tests {
            inherit ciEmacs;
          }
        )
      ) self.packages;

      githubActions =
        let
          inherit (builtins)
            attrValues
            mapAttrs
            attrNames
            map
            concatLists
            intersectAttrs
            ;
          platforms = {
            "x86_64-linux" = "ubuntu-latest";
            #"x86_64-darwin" = "macos-latest";
            "aarch64-darwin" = "macos-latest";
          };
        in
        rec {
          checks = intersectAttrs platforms self.checks;
          matrix.include = concatLists (
            attrValues (
              mapAttrs (
                system: pkgs:
                map (pkg: {
                  inherit system;
                  attr = pkg;
                  os = platforms.${system};
                }) (attrNames pkgs)
              ) checks
            )
          );
        };
    };
}
