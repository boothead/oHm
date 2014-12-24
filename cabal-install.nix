{ cabal, Cabal, extensibleExceptions, filepath, HTTP, HUnit, mtl
, network, networkUri, QuickCheck, random, regexPosix, stm
, testFramework, testFrameworkHunit, testFrameworkQuickcheck2, time
, zlib
}:

cabal.mkDerivation (self: {
  pname = "cabal-install";
  version = "1.22.0.0";
  src = ./cabal-install;
  isLibrary = false;
  isExecutable = true;
  buildDepends = [
    Cabal filepath HTTP mtl network networkUri random stm time zlib
  ];
  testDepends = [
    Cabal extensibleExceptions filepath HTTP HUnit mtl network
    networkUri QuickCheck regexPosix stm testFramework
    testFrameworkHunit testFrameworkQuickcheck2 time zlib
  ];
  postInstall = ''
    mkdir $out/etc
    mv bash-completion $out/etc/bash_completion.d
  '';
  meta = {
    homepage = "http://www.haskell.org/cabal/";
    description = "The command-line interface for Cabal and Hackage";
    license = self.stdenv.lib.licenses.bsd3;
    platforms = self.ghc.meta.platforms;
  };
})
