# Third-party notices

This file records third-party code that GRobot reuses, adapts or redistributes outside the normal package
manager manifests (`uv.lock`, `pnpm-lock.yaml`).

## React Flow / xyflow (MIT)

The workflow editor (`apps/web/src/components/workflows/flow-canvas.tsx`) uses `@xyflow/react` 12.12.0 and
its `@xyflow/system` dependency, unmodified, installed from npm. The editor shows the small "React Flow"
credit the authors ask non-subscribers to keep; do not hide it without a React Flow Pro subscription.

```
MIT License

Copyright (c) 2019-2025 webkid GmbH

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## GRobot MCP (M12)

Machine-readable register: `docs/third-party-inventory-mcp.json`.

**No third-party MCP source is copied or adapted.** The MCP client and server are written for GRobot; the
register below records the dependencies they use.

| Item | Version | License | Form | GRobot location |
|---|---|---|---|---|
| `mcp` (Model Context Protocol Python SDK, github.com/modelcontextprotocol/python-sdk) | 1.30.0 | MIT | runtime dependency, unmodified | `packages/core` (`grobot_core.mcp`) |
| `httpx-sse` | 0.4.3 | MIT | transitive of `mcp` | — |
| `sse-starlette` | 3.5.0 | BSD-3-Clause | transitive of `mcp` | — |
| `uvicorn` | 0.54.0 | BSD-3-Clause | dependency of `services/mcp` | `services/mcp` |
| `python-multipart` | 0.0.32 | Apache-2.0 | dependency of `services/mcp` (OAuth form bodies) | `services/mcp` |

MIT License (Model Context Protocol Python SDK) — Copyright (c) 2024 Anthropic, PBC. Permission is hereby
granted, free of charge, to any person obtaining a copy of this software and associated documentation files,
to deal in the software without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies, subject to inclusion of this notice and the
standard MIT warranty disclaimer. The full license text ships in the package's `licenses` metadata.
