let pkgsRev = "444f22ca892a873f76acd88d5d55bdc24ed08757";
    pkgsSHA256 = "0v99nrlrb9ljnajf5y78gil6whpgjjacrfzslk0xfs85gn91zxvf";
in builtins.fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/${pkgsRev}.tar.gz";
  sha256 = pkgsSHA256;
}
