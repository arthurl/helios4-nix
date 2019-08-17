let pkgsRev = "4a08e95238996b1e7afc4a1491ac3f0a5181f597";
    pkgsSHA256 = "062n0hqfmnmn39zakmbb4lbx4h5yk7nbzh7l75j6rggpmq7130hf";
in builtins.fetchTarball {
  url = "https://github.com/NixOS/nixpkgs/archive/${pkgsRev}.tar.gz";
  sha256 = pkgsSHA256;
}
