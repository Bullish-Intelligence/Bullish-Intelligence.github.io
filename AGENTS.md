# AGENTS.md

This Hugo site uses the Roxo Flex theme through siteman. Keep site settings in
`.siteman/hugo.toml`. Keep homepage sections in `content/_index.md` and page
content in `content/`.

## Verification

Run `devenv shell -- testee verify` from the repository root. The required checks
build and validate the site with siteman.
After an edit to the Testee task table in `devenv.nix`, run
`devenv shell -- testee doctor`.
Run other commands through devenv: `devenv shell -- <command>`.
Use Gitman to open and close workspaces: `gitman work NAME`, then `gitman done NAME`.
