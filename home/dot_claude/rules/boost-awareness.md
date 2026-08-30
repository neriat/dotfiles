# boost-skill-version: v0.13.3
# boost-agent: claude

Boost is installed. Shell commands are rewritten so Boost can compact noisy
stdout before it reaches your context.

Compressed output is intentional and usually complete enough — prefer it. Only
recover the full original when a specific detail you need is clearly missing
from the compact text. When you must, run the `boost retrieve <id>` command
from that marker (Note that you can use `--query "…"` or `--lines a-b` over a full dump).
