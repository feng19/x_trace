const esbuild = require("esbuild")
const path = require("path")
const sveltePlugin = require("esbuild-svelte")
const importGlobPlugin = require("esbuild-plugin-import-glob").default

const args = process.argv.slice(2)
const watch = args.includes("--watch")
const deploy = args.includes("--deploy")

let optsClient = {
    entryPoints: ["js/app.js"],
    bundle: true,
    minify: deploy,
    target: "es2020",
    format: "esm",
    conditions: ["svelte", "browser"],
    outdir: "../priv/static/assets",
    logLevel: "info",
    sourcemap: watch ? "inline" : false,
    tsconfig: "./tsconfig.json",
    nodePaths: [path.resolve(__dirname, "node_modules")],
    // web-tree-sitter conditionally imports Node built-ins that are never
    // executed in browser context – mark them as external to avoid bundling errors.
    external: ["fs/promises", "module", "node:fs/promises", "node:module"],
    plugins: [
        importGlobPlugin(),
        sveltePlugin({
            compilerOptions: {dev: !deploy, css: "injected"},
        }),
    ],
}

let optsServer = {
    entryPoints: ["js/server.js"],
    platform: "node",
    bundle: true,
    minify: false,
    target: "node19.6.1",
    conditions: ["svelte"],
    outdir: "../priv/svelte",
    logLevel: "info",
    sourcemap: watch ? "inline" : false,
    tsconfig: "./tsconfig.json",
    nodePaths: [path.resolve(__dirname, "node_modules")],
    plugins: [
        importGlobPlugin(),
        sveltePlugin({
            compilerOptions: {dev: !deploy, generate: "server"},
        }),
    ],
}

if (watch) {
    Promise.all([
        esbuild.context(optsClient),
        esbuild.context(optsServer),
    ]).then(([clientCtx, serverCtx]) => {
        clientCtx.watch()
        serverCtx.watch()
        process.stdin.on("close", () => process.exit(0))
        process.stdin.resume()
    })
} else {
    Promise.all([
        esbuild.build(optsClient),
        esbuild.build(optsServer),
    ])
}
