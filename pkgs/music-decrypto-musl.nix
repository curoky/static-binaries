{ lib
, buildDotnetModule
, fetchFromGitHub
, dotnetCorePackages
, clang
, zlib
, icu
, apple-sdk
, fetchurl
, stdenv
, swiftPackages
, darwin
, pkgs
}:
let 
  pkgsMusl = import <nixpkgs> {
    crossSystem = (import <nixpkgs> {}).lib.systems.examples.musl64;
  };

  dotnet_sdk_8_0 = dotnetCorePackages.sdk_8_0.overrideAttrs (oldAttrs: {
    src = fetchurl {
      url = "https://builds.dotnet.microsoft.com/dotnet/Sdk/8.0.416/dotnet-sdk-8.0.416-linux-musl-x64.tar.gz";
      hash = "sha512-gaMRpRt9bBN5hXEcUBsdkJ9xkZMZtTCqey2kkQJJtN9jHRlvW3t6NwEdEv8XlsJW/sRiJmWOlE1LFTwk8pk3zQ==";
    };
    sourceRoot = ".";
    #dontFixup = true;
  });
in
buildDotnetModule rec {
  pname = "music-decrypto";
  version = "2.4.2";

  src = fetchFromGitHub {
    owner = "davidxuang";
    repo = "MusicDecrypto";
    rev = "v${version}";
    hash = "sha256-dSstNJdHIuZydg83iwL03KVf1rNBOwdoq4+OEsl9RTo=";
  };
  projectFile = "MusicDecrypto.Commandline/MusicDecrypto.Commandline.csproj";


  executables = [ "musicdecrypto" ];

  dotnetFlags = [
    "-p:PublishAot=true"
    "-p:PublishTrimmed=true"
    #"-p:TrimMode=partial"
    #"-p:PublishSingleFile=true"
    "-p:InvariantGlobalization=true"
    "-p:Configuration=Release"
    #"-p:RuntimeIdentifier=osx-arm64"

    "-p:StaticExecutable=true"
    "-p:RuntimeIdentifier=linux-musl-x64"
  ];

  makeWrapperArgs = [
    #"--set DOTNET_SYSTEM_GLOBALIZATION_INVARIANT 1"
  ];

  nugetDeps = ./music-decrypto/nuget-deps-glibc.json;

  #dotnet-sdk = dotnet_sdk_8_0;
  dotnet-sdk = pkgsMusl.dotnetCorePackages.sdk_8_0;
  dotnet-runtime = pkgsMusl.dotnetCorePackages.runtime_8_0;
  usePackageSource = true;
  selfContainedBuild = true;

  nativeBuildInputs = [
    clang
    #stdenv.cc
    #apple-sdk
    #pkgs.pkgsMusl.stdenv.cc
  ];

  preBuild = ''
    #export NIX_LDFLAGS="-L${pkgs.pkgsMusl.stdenv.cc.libc}/lib -L${pkgs.pkgsMusl.zlib.static}/lib"
    #export NIX_CFLAGS_COMPILE="-I${pkgs.pkgsMusl.stdenv.cc.libc}/include"
  '';

  buildInputs = [
    #zlib.static
    pkgs.pkgsMusl.zlib.static
    #icu
    #openssl
  ] ++ lib.optionals stdenv.hostPlatform.isDarwin ( [
    darwin.ICU
  ]);

  postInstall = ''
  '';

  # passthru.updateScript = ./update.sh;
  dontDotnetFixup = true;
  meta = {
    description = "MusicDecrypto";
  };
}
