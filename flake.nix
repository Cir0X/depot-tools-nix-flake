{
  description = "depot_tools nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    depot_tools = {
      url = "git+https://chromium.googlesource.com/chromium/tools/depot_tools.git?ref=main";
      flake = false;
    };
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    ...
  }: let
    supportedSystems = [
      "aarch64-darwin"
      "aarch64-linux"
      "i686-linux"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
      });
    packages = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
        inherit (pkgs) lib;
        deps = [
          "six"
          "schema"
          "httplib2"
          "colorama"
        ];
        py3 = pkgs.python39.withPackages (lib.attrVals deps);
        cipdClient = let
          cipdClientVersion = "git_revision:673f5ee1931bc72a2b3d4ac712a7f7bc541f089b"; # depot_tools/cipd_client_version
          mkCipdUrl = cipdPlatform: "https://chrome-infra-packages.appspot.com/client?platform=${cipdPlatform}&version=${cipdClientVersion}";
          cipds = {
            aarch64-darwin = rec {
              platform = "mac-arm64";
              url = mkCipdUrl platform;
              sha256 = "0h0g5czc8xzd7cgm835r7hra2kmpkdjhyj3qxph6kh0v1p206yh7";
            };
            aarch64-linux = rec {
              platform = "linux-arm64";
              url = mkCipdUrl platform;
              sha256 = "1byrkmr34mycc7r5gzxzjlnqmn626r5zrbh05lgh46h475hijmyk";
            };
            i686-linux = rec {
              platform = "linux-386";
              url = mkCipdUrl platform;
              sha256 = "04yaw6ilrp9sm7w0yq2km77q3v25j0smlrhvc4f18k42d89562cq";
            };
            x86_64-darwin = rec {
              platform = "mac-amd64";
              url = mkCipdUrl platform;
              sha256 = "105kxdbqfawxk0np8l4y5id1v3bzb5n6w1d8zbkdj9xhc7rh4ivj";
            };
            x86_64-linux = rec {
              platform = "linux-amd64";
              url = mkCipdUrl platform;
              sha256 = "0mvj497zzbcj9h86dmgmvcl1s5hcg3j9g84kl79z9s65lg3xkdbf";
            };
          };
        in
          pkgs.fetchurl {
            name = "cipd";
            executable = true;
            inherit (cipds.${system}) url sha256;
          };
      in {
        "gclient" = pkgs.stdenv.mkDerivation {
          pname = "gclient";
          version = inputs.depot_tools.rev;
          src = inputs.depot_tools;
          buildInputs = [pkgs.gcc-unwrapped py3];
          nativeBuildInputs = [pkgs.makeWrapper]; # pkgs.autoPatchelfHook
          patches = [./patches/gclient-no-history.patch];
          installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/src/third_party/
            cp -r . $out/src/
            # chmod -R u+rwX,go+rX,go-w $out/src/
            ln -sf ${cipdClient} $out/src/cipd
            makeWrapper $out/src/gclient $out/bin/gclient \
              --set DEPOT_TOOLS_UPDATE 0 \
              --set DEPOT_TOOLS_METRICS 0 \
              --set GCLIENT_PY3 1 \
              --set VPYTHON_BYPASS 'manually managed python not supported by chrome operations' \
              --prefix PATH : ${lib.makeBinPath [py3]}
          '';
          installCheckPhase = ''
            set -euo pipefail
            $out/bin/gclient --version
            cat $out/src/gclient_scm.py | grep "use_fetch = False"
          '';
          doInstallCheck = true;
        };
        default = self.packages.${system}.gclient;
      }
    );
    formatter = forAllSystems (
      system: nixpkgsFor.${system}.treefmt
    );
  in {
    inherit packages formatter;
  };
}
