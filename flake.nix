{
  description = "Emacs versions for CI";

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";

    flake-compat = {
      url = "github:edolstra/flake-compat";
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
    emacs-snapshot-commercial = {
      url = "github:commercial-emacs/commercial-emacs";
      flake = false;
    };
  };

  nixConfig = {
    extra-substituters = "https://commercial-emacs-ci.cachix.org";
    extra-trusted-public-keys = "commercial-emacs-ci.cachix.org-1:BRcMczBflGS5k73UHpeYuACGMt+gCPUPT8sO4ezSAFs=";
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
                emacs-29-4 = "29.4";
                emacs-30-2 = "30.2";
                emacs-snapshot = "31.0.50";
                emacs-snapshot-commercial = "31.0.50";
              };
            in
            builtins.mapAttrs (
              name: version:
              pkgs.callPackage ./emacs.nix {
                inherit name version;
                inherit (pkgs.darwin) sigtool;
                src = inputs.${name};
                latestPackageKeyring = inputs.emacs-snapshot + "/etc/package-keyring.gpg";
                srcRepo = lib.strings.hasInfix "snapshot" version;
                withNativeCompilation = true;
              }
            ) versions
          );

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
          packages = intersectAttrs platforms self.packages;
        in
        {
          inherit packages;
          matrix.include = concatLists (
            attrValues (
              mapAttrs (
                system: pkgs:
                map (pkg: {
                  inherit system;
                  attr = pkg;
                  os = platforms.${system};
                }) (attrNames pkgs)
              ) packages
            )
          );
        };
    };
}
