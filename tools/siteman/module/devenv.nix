{ pkgs, lib, config, ... }:

# The importable siteman module.
#
# A consuming repo wires this up in devenv.yaml:
#
#   inputs:
#     siteman:
#       url: github:bullish-design/siteman
#       flake: false
#   imports:
#     - siteman/module
#
# It contributes a pinned Hugo (extended), the supporting toolchain, and the
# siteman-* scripts. Everything else in a consuming repo is plain files.

let
  # Resolved to this directory's store path; scripts/templates ship alongside.
  sitemanRoot = ./.;

  mkScript = name: ''
    export SITEMAN_ROOT="${sitemanRoot}"
    exec ${pkgs.bash}/bin/bash "${sitemanRoot}/scripts/${name}.sh" "$@"
  '';
in
{
  # Pinned, reproducible toolchain for every consumer.
  packages = [
    pkgs.hugo # NOTE: must be the *extended* build (Sass/WebP). Verify with `hugo env`.
    pkgs.go # required by Hugo's module system (theme fetching)
    pkgs.git
    pkgs.htmltest # broken-link checking for siteman-check
    pkgs.markdownlint-cli2 # markdown linting for siteman-check
    pkgs.vale # prose linting for siteman-check
    pkgs.actionlint # GitHub Actions workflow validation
  ];

  scripts.siteman-init.exec = mkScript "siteman-init";
  scripts.siteman-new.exec = mkScript "siteman-new";
  scripts.siteman-serve.exec = mkScript "siteman-serve";
  scripts.siteman-build.exec = mkScript "siteman-build";
  scripts.siteman-sync.exec = mkScript "siteman-sync";
  scripts.siteman-clean.exec = mkScript "siteman-clean";
  scripts.siteman-check.exec = mkScript "siteman-check";

  enterShell = ''
    if [ ! -d ".siteman" ]; then
      echo "siteman: no .siteman/ found — run 'siteman-init' to scaffold a site."
    fi
  '';
}
