# .doom.d
my doom emacs config

## mdrepl — send markdown code blocks to a live REPL

`lisp/mdrepl.el` brings Quarto/RMarkdown-style chunk execution to plain
markdown, mirroring my nvim config (`medewitt/nvim`, `lua/mdrepl.lua`). Put
point in a ` ```python `, ` ```r `, or ` ```julia ` fenced block and send it to
that language's own persistent REPL in a terminal split below. Each language
keeps its own REPL and state; sends are queued until the REPL shows its first
prompt, so a cold `uv run` dependency resolve loses nothing.

On [ideeep](https://github.com/medewitt/ideeep) content pages the REPL is
launched with `uv run --script scripts/repl_blocks.py <page> [--lang r|julia]
--none` — an IPython/R/julia prompt in the same environment the site's output
injector uses (numpy, scipy, torch, jax, …), one REPL per page per language.
Outside such a project it falls back to `python3`, `radian`-or-`R`, and
`julia`; a `pyproject.toml`/`uv.lock` upward makes python use `uv run python`.

### Keys (markdown/gfm)

| Keys | Action |
|---|---|
| `SPC RET` (normal/visual) | Send the block at point (advances to the next same-language block), or the region |
| `SPC m r r` | Send block or region |
| `SPC m r RET` | Send block only |
| `SPC m r a` | Run same-language blocks 1..point through the live REPL |
| `SPC m r A` | Fresh REPL preloaded with page state (`--through N` on ideeep pages) |
| `SPC m r o` | Toggle the REPL window (the REPL keeps running) |
| `SPC m r q` | Quit: kill the REPL and close its pane |

### Config

```elisp
(setq mdrepl-height 12               ; REPL split height, in lines
      mdrepl-advance t               ; move to the next block after a send
      mdrepl-bracketed-paste t)      ; nil for classic line-based REPLs

;; Override the command per language (buffer-local or global):
(setq-local mdrepl-cmd '("python3" "-m" "IPython"))
;; mdrepl-cmd-r / mdrepl-cmd-julia likewise.
```

### Tests

```bash
emacs -Q --batch -L lisp -l tests/test-mdrepl.el
# set MDREPL_TEST_IDEEEP_PAGE=/path/to/ideeep/content/math/foo.md
# to also exercise ideeep command resolution
```
