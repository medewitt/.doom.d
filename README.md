# .doom.d
my doom emacs config

## mdrepl — send markdown code blocks to a live REPL

`lisp/mdrepl.el` brings Quarto/RMarkdown-style chunk execution to plain
markdown, mirroring my nvim config (`medewitt/nvim`, `lua/mdrepl.lua`). Put
point in a ` ```python `, ` ```r `, or ` ```julia ` fenced block and send it to
that language's own persistent REPL in a split below. Each language keeps its
own REPL and state; sends are queued until the REPL shows its first prompt, so
a cold `uv run` dependency resolve loses nothing.

The REPL runs in [vterm](https://github.com/akermu/emacs-libvterm) (the same
libvterm terminal nvim's `:terminal` uses), so IPython renders correctly and
bracketed paste round-trips cleanly. vterm's native module compiles on first
use; `cmake` and `libvterm` must be installed (`brew install cmake libvterm`).

On [ideeep](https://github.com/medewitt/ideeep) content pages the REPL is
launched with `uv run --script scripts/repl_blocks.py <page> [--lang r|julia]
--none` — an IPython/R/julia prompt in the same environment the site's output
injector uses (numpy, scipy, torch, jax, …), one REPL per page per language.
Outside such a project it falls back to `python3`, `radian`-or-`R`, and
`julia`; a `pyproject.toml`/`uv.lock` upward makes python use `uv run python`.

### Running a chunk

1. Open the markdown file and put point inside a ` ```python ` block.
2. Press `SPC RET` (or `SPC m r r`).

A REPL window opens at the bottom. The first send cold-starts uv, so give it a
few seconds; after that it is instant and reuses the same REPL for the page.

After editing `config.el`, `packages.el`, or `lisp/mdrepl.el`, reload with
`SPC h r r` (`M-x doom/reload`) — the keybindings and code only change on
reload.

### Keys

The bindings are active in the markdown host modes and, because
[polymode](https://polymode.github.io/) switches the buffer to the chunk's own
major mode inside a fence (the modeline shows e.g. `foo.md[python]`), in the
inner `python-mode` and the polymode minor-mode map too. Without the inner
maps, `SPC m r` is *undefined* while point is inside a ` ```python ` block.

| Keys | Action |
|---|---|
| `SPC RET` (normal/visual) | Send the block at point (advances to the next same-language block), or the region |
| `SPC m r r` | Send block or region |
| `SPC m r RET` | Send block only |
| `SPC m r a` | Run same-language blocks 1..point through the live REPL |
| `SPC m r A` | Fresh REPL preloaded with page state (`--through N` on ideeep pages) |
| `SPC m r o` | Toggle the REPL window (the REPL keeps running) |
| `SPC m r q` | Quit: kill the REPL and close its pane |

### Python vs R / Julia

Python is the primary target: `repl_blocks.py` opens a real interactive IPython
REPL in the page's uv environment, which is what mdrepl drives. R and Julia get
only batch-style execution from `repl_blocks.py` (R shells out to `Rscript`),
so for interactive R and Julia work prefer their native tooling — ESS (`M-x R`)
for R and `julia-repl` for Julia — rather than mdrepl.

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

## Python editing

`anaconda-mode` and `company-anaconda` (Doom's non-LSP python backend) are
disabled in `packages.el`. Their bundled `jedi` 0.18.1 / `parso` 0.8.4 crash on
Python 3.14 (`InvalidPythonEnvironment` / `EOFError: Ran out of input`), and the
anaconda/conda stack is unwanted. `config.el` points `python-shell-interpreter`
at the Homebrew `python3`, never the macOS `/usr/bin/python3`; project
environments are handled by uv (and by mdrepl for markdown code blocks). For
smart completion, add `(python +lsp)` with `basedpyright` later.

## Snippets: LaTeX and org

`snippets/` holds personal yasnippets.
Doom's `:editor snippets` module loads this directory (`+snippets-dir`) automatically, so no config change is needed.
Type the key and press `TAB`; `SPC i s` lists snippets for the current mode.
`snippets/LaTeX-mode/.yas-parents` makes the `latex-mode` snippets available under AUCTeX's `LaTeX-mode`.
Labels are generated from the text you type where possible, and float placement is always the last tab stop.

### LaTeX (`snippets/latex-mode`)

| Key | Expands to |
|---|---|
| `fig` | `figure` with `\includegraphics`; label `fig:<file base name>` |
| `subfig` | two `subfigure`s (needs `subcaption`), each labeled from its file |
| `tikzfig` | `figure` wrapping a `tikzpicture` |
| `tab` | `table` with booktabs rules |
| `eq` / `eq*` | labeled `equation` (wraps the selection) / `equation*` |
| `ali` / `ali*` | labeled `align` / `align*` |
| `cas` | `cases` |
| `model` | hierarchical model in `align` (likelihood, link, priors) |
| `beg` | generic `\begin{env}...\end{env}` with mirrored name |
| `mm` | inline math `\( \)` |
| `sec` / `sub` | section / subsection with label slugified from the title |
| `cr` | `\cref{}` with a prefix choice (`fig:`, `tab:`, `eq:`, `sec:`, `app:`) |
| `thm` | theorem-like environment (choice) with prefixed label and `proof` |
| `itm` / `enu` | `itemize` / `enumerate` |
| `article` | full article preamble (amsmath, booktabs, subcaption, TikZ, biblatex, cleveref) |

### Org (`snippets/org-mode`)

| Key | Expands to |
|---|---|
| `fig` | `#+caption`, `#+name: fig:<file base name>`, LaTeX/HTML width, file link |
| `tab` | captioned, named booktabs table |
| `eq` / `ali` | labeled LaTeX `equation` / `align` (exports to LaTeX and MathJax) |
| `srcr` | R block (`:session *R*`), choice of `output`/`value`/`graphics file` |
| `srcj` | Julia block (`:session *julia*`) |
| `srcs` | Stan program tangled to `models/<name>.stan` |
| `lhdr` | LaTeX export header (class, packages, options) |
| `tpaper` | manuscript skeleton: export header, org-cite, abstract, IMRaD headings |
| `tanalysis` | analysis notebook: data.table + cmdstanr setup, seed 1834, PPC, `sessionInfo()` |
| `tread` | paper reading note with DOI/citekey properties |
| `tmeet` | meeting notes with a TODO carrying a one-week deadline |
| `tlog` | dated research log entry |

Org snippets use `yas-indent-line 'fixed` so org does not re-indent `#+begin_src` bodies through the language mode.

### Tests

The snippets were checked by expanding each one in batch Emacs with yasnippet 0.14.
In snippet bodies, `\\` produces one backslash and braces inside a field default must be escaped (`${1:\mathcal\{N\}}`).
