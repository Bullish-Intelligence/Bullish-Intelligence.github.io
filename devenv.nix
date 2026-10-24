# Development environment of bullish-intelligence.github.io.
{ ... }:
{
  # Testee runs the standard tasks (check:*, test:*).
  # Every task declares `input.testee`, so Testee can reuse a verdict when a commit
  # changes none of its inputs. Run `testee doctor` after any edit to this table.
  # devman's `base` group calls `base:check` and `base:test`.
  # The required site check builds through siteman with pinned theme modules.
  tasks = {
    "check:lint" = {
      exec = ''
        set -eu
        cd "$DEVENV_ROOT"
        test -s README.md || { echo "README.md is missing or empty"; exit 1; }
        test -s AGENTS.md || { echo "AGENTS.md is missing or empty"; exit 1; }
      '';
      input.testee.reads = [ "README.md" "AGENTS.md" ];
    };

    "check:format" = {
      exec = ''
        set -eu
        cd "$DEVENV_ROOT"
        # Every tracked file is text (grep -I rejects a binary file).
        bad=0
        for f in $(git ls-files); do
          if [ -f "$f" ] && [ -s "$f" ] && ! grep -Iq . "$f"; then
            echo "not text: $f"
            bad=1
          fi
        done
        exit "$bad"
      '';
      input.testee.ignores = [ ".gitignore" ];
    };

    "check:types" = {
      exec = ''
        set -eu
        cd "$DEVENV_ROOT"
        siteman-build --destination "$TESTEE_RUN_DIR/public"
      '';
      input.testee.reads = [ ".siteman/hugo.toml" ".siteman/themes/siteman-default/**" "content/**" "go.mod" "go.sum" "_vendor/**" "tools/siteman/module/**" ];
    };

    "test:quick" = {
      exec = ''
        echo "n/a: no quick test subset"
        exit 0
      '';
      input.testee.ignores = [ "**" ];
    };

    "test:full" = {
      exec = ''
        set -eu
        cd "$DEVENV_ROOT"
        siteman-check
      '';
      input.testee.reads = [ ".siteman/**" ".github/workflows/**" "content/**" "devenv.lock" "go.mod" "go.sum" "_vendor/**" "tools/siteman/module/**" ];
    };

    "base:check" = {
      after = [ "check:lint" "check:format" "check:types" ];
      input.testee.ignores = [ "**" ];
    };
    "base:test" = {
      after = [ "test:full" ];
      input.testee.ignores = [ "**" ];
    };
  };
}
