{
  lib,
  aws-sdk-cpp,
  boehmgc,
  callPackage,
  fetchFromGitHub,
  Security,

  storeDir ? "/nix/store",
  stateDir ? "/nix/var",
  confDir ? "/etc",
}:
let
  boehmgc-nix_2_3 = boehmgc.override { enableLargeConfig = true; };

  boehmgc-nix = boehmgc-nix_2_3.overrideAttrs (drv: {
    patches = (drv.patches or [ ]) ++ [
      # Part of the GC solution in https://github.com/NixOS/nix/pull/4944
      ../nix/patches/boehmgc-coroutine-sp-fallback.patch
    ];
  });

  aws-sdk-cpp-nix =
    (aws-sdk-cpp.override {
      apis = [
        "s3"
        "transfer"
      ];
      customMemoryManagement = false;
    }).overrideAttrs
      {
        # only a stripped down version is build which takes a lot less resources to build
        requiredSystemFeatures = [ ];
      };

  # Since Lix 2.91 does not use boost coroutines, it does not need boehmgc patches either.
  needsBoehmgcPatches = version: lib.versionOlder version "2.91";

  common =
    args:
    callPackage (import ./common.nix ({ inherit lib fetchFromGitHub; } // args)) {
      inherit
        Security
        storeDir
        stateDir
        confDir
        ;
      boehmgc = if needsBoehmgcPatches args.version then boehmgc-nix else boehmgc-nix_2_3;
      aws-sdk-cpp = aws-sdk-cpp-nix;
    };
in
lib.makeExtensible (self: {
  buildLix = common;

  lix_2_90 = (
    common {
      version = "2.90.0";
      hash = "sha256-f8k+BezKdJfmE+k7zgBJiohtS3VkkriycdXYsKOm3sc=";
      docCargoHash = "sha256-vSf9MyD2XzofZlbzsmh6NP69G+LiX72GX4Um9UJp3dc=";
    }
  );

  lix_2_91 = (
    common {
      version = "2.91.0";
      hash = "sha256-Rosl9iA9MybF5Bud4BTAQ9adbY81aGmPfV8dDBGl34s=";
      docCargoHash = "sha256-KOn1fXF7k7c/0e5ZCNZwt3YZmjL1oi5A2mhwxQWKaUo=";
    }
  );

  latest = self.lix_2_91;
  stable = self.lix_2_91;
})
