<script>
  /**
   * Shared settings display component.
   * Renders TSpecs, Rate-Limiting, Options, and CLI in a unified style.
   * Each data block has a copy-to-clipboard button at its top-right corner.
   *
   * @prop {string|string[]|number} tSpecs - trace specs
   * @prop {string} max - rate limiting value
   * @prop {string} options - options value
   * @prop {string} cli - CLI command string
   * @prop {boolean} compact - compact mode for cards (smaller text, tighter spacing)
   */
  import { Copy, Check } from "lucide-svelte/icons";
  import { toast } from "svelte-sonner";

  export let tSpecs = [];
  export let max = "";
  export let options = "";
  export let cli = "";
  export let compact = false;

  $: labelClass = compact
    ? "font-bold text-xs mb-0.5"
    : "font-bold text-sm mb-1";
  $: boxClass = compact
    ? "relative rounded-md border bg-muted/50 p-2"
    : "relative rounded-md border bg-muted/50 p-3";
  $: preClass = compact
    ? "text-xs text-wrap break-all whitespace-pre-wrap pr-6"
    : "text-sm text-wrap break-all whitespace-pre-wrap pr-7";
  $: gapClass = compact ? "space-y-2" : "space-y-4";
  $: iconSize = compact ? "size-3" : "size-3.5";
  $: btnClass = compact
    ? "absolute top-1 right-1 rounded p-0.5 text-muted-foreground hover:text-foreground hover:bg-muted/80 transition-colors"
    : "absolute top-1.5 right-1.5 rounded p-0.5 text-muted-foreground hover:text-foreground hover:bg-muted/80 transition-colors";

  // Track which field was just copied
  let copied = "";
  let timer;

  function copyText(field, text) {
    navigator.clipboard.writeText(text).then(() => {
      copied = field;
      toast.success("Copied");
      clearTimeout(timer);
      timer = setTimeout(() => { copied = ""; }, 1500);
    });
  }

  function tSpecsText(specs) {
    if (!specs || specs.length === 0 || specs === 0) return "[ ]";
    if (typeof specs === "string") return specs;
    if (specs.length === 1) return `[${specs[0]}]`;
    return `[\n${specs.map((s, i) => `  ${s}${i < specs.length - 1 ? "," : ""}`).join("\n")}\n]`;
  }
</script>

<div class={gapClass}>
  <div>
    <div class={labelClass}>TSpecs:</div>
    <div class={boxClass}>
      <button
        class={btnClass}
        title="Copy TSpecs"
        on:click={() => copyText("tspecs", tSpecsText(tSpecs))}
      >
        {#if copied === "tspecs"}
          <Check class={iconSize} />
        {:else}
          <Copy class={iconSize} />
        {/if}
      </button>
      {#if !tSpecs || tSpecs.length === 0 || tSpecs === 0}
        <pre class="{preClass} text-muted-foreground">[ ]</pre>
      {:else if typeof tSpecs === 'string'}
        <pre class={preClass}>{tSpecs}</pre>
      {:else if tSpecs.length === 1}
        <pre class={preClass}>[{tSpecs[0]}]</pre>
      {:else}
        <pre class={preClass}>[
{#each tSpecs as spec, i}  {spec}{#if i < tSpecs.length - 1},{/if}
{/each}]</pre>
      {/if}
    </div>
  </div>

  <div>
    <div class={labelClass}>Rate-Limiting:</div>
    <div class={boxClass}>
      <button
        class={btnClass}
        title="Copy Rate-Limiting"
        on:click={() => copyText("max", max || "N/A")}
      >
        {#if copied === "max"}
          <Check class={iconSize} />
        {:else}
          <Copy class={iconSize} />
        {/if}
      </button>
      <pre class={preClass}>{max || "N/A"}</pre>
    </div>
  </div>

  <div>
    <div class={labelClass}>Options:</div>
    <div class={boxClass}>
      <button
        class={btnClass}
        title="Copy Options"
        on:click={() => copyText("options", options || "N/A")}
      >
        {#if copied === "options"}
          <Check class={iconSize} />
        {:else}
          <Copy class={iconSize} />
        {/if}
      </button>
      <pre class={preClass}>{options || "N/A"}</pre>
    </div>
  </div>

  {#if cli}
    <div>
      <div class={labelClass}>CLI:</div>
      <div class={boxClass}>
        <button
          class={btnClass}
          title="Copy CLI"
          on:click={() => copyText("cli", cli)}
        >
          {#if copied === "cli"}
            <Check class={iconSize} />
          {:else}
            <Copy class={iconSize} />
          {/if}
        </button>
        <pre class={preClass}>{cli}</pre>
      </div>
    </div>
  {/if}
</div>
