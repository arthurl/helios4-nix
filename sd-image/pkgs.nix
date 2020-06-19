let pkgsRev = "f4fc6f7dcf468a910ca4ea490555b0555e216d93";
    pkgsSHA256 = "0qfwy6x82sbg3zycg2jyx1s3xf2nrv1k38jhw9i3v20r5gbcm9hc";
in builtins.fetchTarball {
  url = "https://github.com/expipiplus1/nixpkgs/archive/${pkgsRev}.tar.gz";
  sha256 = pkgsSHA256;
}
