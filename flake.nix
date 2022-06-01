{
  description = "A very basic flake";

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
      # "mingW64"
      # "mingw32"
      "x86_64-darwin"
      "x86_64-linux"
    ];
    # _depotToolsPlatforms = [
    #   "aix-ppc64"
    #   "linux-386"
    #   "linux-amd64"
    #   "linux-arm64"
    #   "linux-armv6l"
    #   "linux-mips64"
    #   "linux-mips64le"
    #   "linux-mipsle"
    #   "linux-ppc64"
    #   "linux-ppc64le"
    #   "linux-s390x"
    #   "mac-amd64"
    #   "mac-arm64"
    #   "windows-386"
    #   "windows-amd64"
    # ];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
      });
    packages = forAllSystems (
      system: let
        pkgs = nixpkgsFor.${system};
        # lib = pkgs.lib;
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
              sha256 = "";
            };
            aarch64-linux = rec {
              platform = "linux-arm64";
              url = mkCipdUrl platform;
              sha256 = "";
            };
            i686-linux = rec {
              platform = "linux-386";
              url = mkCipdUrl platform;
              sha256 = "";
            };
            x86_64-darwin = rec {
              platform = "mac-amd64";
              url = mkCipdUrl platform;
              sha256 = "105kxdbqfawxk0np8l4y5id1v3bzb5n6w1d8zbkdj9xhc7rh4ivj";
            };
            x86_64-linux = rec {
              platform = "linux-amd64";
              url = mkCipdUrl platform;
              sha256 = "";
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
          patches = [ ./patches/gclient-no-history.patch ];
          # unwrapPhase = ''
          #   mkdir -p $out/src/
          #   cp -r $src/. $out/src/
          #   chmod -R u+rwX,go+rX,go-w $out/src/
          # '';
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
  in {
    inherit packages;

    # packages.x86_64-linux.hello = nixpkgs.legacyPackages.x86_64-linux.hello;
    # defaultPackage.x86_64-linux = self.packages.x86_64-linux.hello;
  };
}
