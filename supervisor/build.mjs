import * as esbuild from "esbuild";

const common = {
  bundle: true,
  platform: "node",
  target: "es2022",
  format: "cjs",
  sourcemap: true,
  external: ["electron", "node-pty"],
};

// Main process
await esbuild.build({
  ...common,
  entryPoints: ["src/main/index.ts"],
  outfile: "dist/main/index.js",
});

// Preload
await esbuild.build({
  ...common,
  entryPoints: ["src/main/preload.ts"],
  outfile: "dist/main/preload.js",
});

console.log("Build complete.");
