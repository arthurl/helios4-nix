let pkgsRev = "5b534244153d1d8aa134c57d58e27f3c74110ead";
    pkgsSHA256 = "1px2zdvc60ljyi9ln6ypplphrmsmhii0hk0rah3dxzp9ycd8ralq";
in builtins.fetchTarball {
  url = "https://github.com/expipiplus1/nixpkgs/archive/${pkgsRev}.tar.gz";
  sha256 = pkgsSHA256;
}
