# boost-skill-version: v0.16.11
# boost-agent: claude

Boost is installed. Shell commands are rewritten so Boost can compact noisy
stdout before it reaches your context.

Compressed output is intentional and usually complete enough — prefer it. Only
recover the full original when a specific detail you need is clearly missing
from the compact text. When you must, run the `boost retrieve <id>` command
from that marker (Note that you can use `--query "…"` or `--lines a-b` over a full dump).

The Read tool rejects Office files (.docx, .xlsx, .pptx, and similar) as
binary before hooks can rewrite the path. Use `boost read <path>` for those.
Boost also rewrites `.ipynb` reads to Markdown (truncated outputs); use
`boost retrieve <id>` when a marker is present or `boost read` if you need
the rendered notebook outside Read.

For public web pages (http/https), prefer the agent's **WebFetch** tool over
Shell `curl` when available — Boost converts HTML to article Markdown and
structured fetch metadata compresses best. If you use Shell `curl`, run the
URL alone (`curl -sL 'https://…'`) with network access; do not pipe through
`wc`, `head`, or similar — that hides HTML from conversion. With Boost hooks
enabled, Cursor/Claude/Codex rewrite eligible `curl`/`wget` commands to pipe
through `boost` automatically.
