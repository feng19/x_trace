# X-Trace

A web-based GUI for [Extrace](https://hex.pm/packages/extrace) / [recon_trace](http://ferd.github.io/recon/recon_trace.html) — making BEAM tracing easy, visual, and interactive.

## ✨ Features

- **Real-time trace streaming** — Trace messages rendered live in the browser via Phoenix LiveView + Svelte
- **Local & remote tracing** — Trace the local node or any connected remote BEAM node
- **Node management** — Setup Erlang distribution, connect/disconnect nodes, auto-reconnect on failure
- **Flexible trace specs** — Supports `{Mod, :fun, args}` tuples, `&Mod.fun/arity` capture syntax, and match specs
- **Rate limiting** — Configurable max traces per time window to prevent overwhelming production systems
- **Scope & PID filtering** — Trace `:local` or `:global` scope, filter by `:all`, `:new`, `:existing`, or specific PIDs
- **Settings persistence** — Save, load, import, and export trace configurations
- **Dark mode** — Toggle between light and dark themes
- **Cross-platform CLI** — Single-binary distribution for macOS (x86_64 / aarch64), Linux (x86_64 / aarch64), and Windows via [Burrito](https://hex.pm/packages/burrito)
- **Desktop app** — Also available as a native desktop application

## 🚀 Quick Start

### Option 1: Download Pre-built Binary

Download the CLI binary for your platform from [Releases](https://github.com/feng19/x_trace/releases):

```bash
# Run the binary (example for macOS ARM)
./xtrace_macos_aarch64
```

Then visit [http://localhost:4000](http://localhost:4000) in your browser.

### Option 2: Desktop Application

Download the desktop app from [x_trace_desktop Releases](https://github.com/feng19/x_trace_desktop/releases).

## ⌨️ CLI Options

| Flag | Alias | Type | Default | Description |
|------|-------|------|---------|-------------|
| `--ip` | | string | `127.0.0.1` (dev) / `::` (prod) | IP address to bind the HTTP server |
| `--port` | `-p` | integer | `4000` | HTTP port |
| `--node` | `-n` | string | | Remote node to connect to (e.g. `myapp@hostname`) |
| `--cookie` | | string | | Erlang cookie for distributed connections |
| `--sname` | | string | | Short name for Erlang distribution |
| `--name` | | string | | Fully qualified name for Erlang distribution |
| `--open` | | boolean | `false` | Open the browser automatically on start |

### Examples

```bash
# Start on a custom port
./xtrace_macos_aarch64 -p 8080

# Start with Erlang distribution and connect to a running node
./xtrace_macos_aarch64 --sname xtrace --cookie mycookie --node myapp@localhost

# Bind to all interfaces (accessible from other machines)
./xtrace_macos_aarch64 --ip 0.0.0.0 -p 4000

# Auto-open browser
./xtrace_macos_aarch64 --open
```

## 📖 Usage Guide

### 1. Setting Up Erlang Distribution

Before connecting to remote nodes, you need to start Erlang distribution:

1. Open the **Node Settings** panel
2. Enter a **node name** (e.g. `xtrace`)
3. Choose **short names** (`--sname`) or **long names** (`--name`)
4. Optionally set a **cookie**
5. Click **Setup**

### 2. Connecting to a Remote Node

1. Enter the target node name (e.g. `myapp@localhost`)
2. Enter the cookie (if different from the default)
3. Click **Connect**
4. Use the **Node Switcher** to switch between connected nodes

### 3. Adding Trace Specs

Trace specs define which function calls to trace. Supported formats:

```elixir
# Tuple format: {Module, :function, match_spec_or_arity}
{Enum, :map, :return_trace}
{Enum, :map, 2}
{MyApp.Repo, :all, :_}

# Capture syntax (auto-generates match spec with return_trace)
&Enum.map/2

# List of specs
[{Enum, :map, :return_trace}, {Enum, :reduce, :return_trace}]

# Erlang modules
{:ets, :lookup, :return_trace}
```

> **Banned modules**: `recon_trace`, `io`, `lists` are blocked to prevent tracing feedback loops.

### 4. Rate Limiting

Configure safe trace rates to protect production systems:

- **Max**: Number of traces allowed per window (1–1000)
- **Milliseconds**: Time window in milliseconds (100–10,000), leave empty for total count mode

### 5. Scope & PID Options

- **Scope**: `:local` (default) or `:global`
- **PID filter**: `:all`, `:new`, `:existing`, or specific PIDs (e.g. `0.123.0`)

### 6. Starting & Stopping Traces

1. Add at least one trace spec
2. Click **Start Trace** (▶)
3. Watch trace messages stream in real-time
4. Click **Stop Trace** (⏹) to end the session

The generated `Extrace.calls(...)` command is displayed for reference — you can copy it for use in IEx.

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Backend** | [Elixir](https://elixir-lang.org/) + [Phoenix 1.7](https://www.phoenixframework.org/) + [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) |
| **Frontend** | [Svelte 4](https://svelte.dev/) via [live_svelte](https://hex.pm/packages/live_svelte), [shadcn-svelte](https://www.shadcn-svelte.com/) UI components |
| **Styling** | [Tailwind CSS](https://tailwindcss.com/) |
| **State sync** | [LiveJSON](https://hex.pm/packages/live_json) for efficient JSON patch diffs |
| **Tracing** | [Extrace](https://hex.pm/packages/extrace) (enhanced recon_trace) |
| **HTTP server** | [Bandit](https://hex.pm/packages/bandit) |
| **Packaging** | [Burrito](https://hex.pm/packages/burrito) — self-extracting BEAM binaries |
| **Build tools** | esbuild, TypeScript, esbuild-svelte |

## 🔧 Development

### Prerequisites

- **Erlang/OTP** ≥ 25
- **Elixir** ≥ 1.14
- **Node.js** (for asset compilation)

### Setup

```bash
# Clone the repository
git clone https://github.com/feng19/x_trace.git
cd x_trace

# Install dependencies and build assets
mix setup

# Start the dev server
mix phx.server

# Or with IEx
iex -S mix phx.server
```

The dev server runs at [http://localhost:4000](http://localhost:4000) with:
- Live code reloading
- Asset watchers (esbuild + Tailwind)
- Phoenix LiveDashboard at [/dev/dashboard](http://localhost:4000/dev/dashboard)

### Asset Commands

```bash
# Install frontend dependencies
mix assets.setup

# Build assets (development)
mix assets.build

# Build assets (production, minified + digested)
mix assets.deploy
```

## 📦 Build & Release

### Prerequisites for Building

- **Erlang/OTP** — `erl`
- **Elixir** — `mix`
- **Zig** (0.15.2) — required by Burrito for cross-compilation
- **XZ** — `xz`
- **7z** — for Windows targets

### Building Binaries

```bash
# Build for all targets
mix assets.deploy
mix release --force --overwrite

# Build for a specific target
BURRITO_TARGET=macos_aarch64 mix release --force --overwrite
```

### Available Targets

| Target | OS | Architecture |
|--------|----|-------------|
| `macos` | macOS | x86_64 |
| `macos_aarch64` | macOS | aarch64 (Apple Silicon) |
| `linux` | Linux | x86_64 |
| `linux_aarch64` | Linux | aarch64 |
| `windows` | Windows | x86_64 |

Built binaries are output to the `burrito_out/` directory.

## 📄 License

See [LICENSE](LICENSE) for details.
