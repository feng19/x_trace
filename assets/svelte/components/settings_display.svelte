<script>
  /**
   * Shared settings display component.
   * Renders TSpecs, Rate-Limiting, and Options in a unified style.
   * Each data block has a copy-to-clipboard button at its top-right corner.
   *
   * @prop {string|string[]|number} tSpecs - trace specs
   * @prop {string} max - rate limiting value
   * @prop {string} options - options value
   * @prop {boolean} compact - compact mode for cards (smaller text, tighter spacing)
   */
  import CopyIcon from "@lucide/svelte/icons/copy";
  import CheckIcon from "@lucide/svelte/icons/check";
  import { toast } from "svelte-sonner";

  let {
    tSpecs = [],
    max = "",
    options = "",
    compact = false,
  } = $props();

  let labelClass = $derived(compact
    ? "font-bold text-xs mb-0.5"
    : "font-bold text-sm mb-1");
  let boxClass = $derived(compact
    ? "relative rounded-md border bg-muted/50 p-2"
    : "relative rounded-md border bg-muted/50 p-3");
  let preClass = $derived(compact
    ? "text-xs text-wrap break-all whitespace-pre-wrap pr-6"
    : "text-sm text-wrap break-all whitespace-pre-wrap pr-7");
  let gapClass = $derived(compact ? "space-y-2" : "space-y-4");
  let iconSize = $derived(compact ? "size-3" : "size-3.5");
  let btnClass = $derived(compact
    ? "absolute top-1 right-1 rounded p-0.5 text-muted-foreground hover:text-foreground hover:bg-muted/80 transition-colors"
    : "absolute top-1.5 right-1.5 rounded p-0.5 text-muted-foreground hover:text-foreground hover:bg-muted/80 transition-colors");

  // Track which field was just copied
  let copied = $state("");
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
        onclick={() => copyText("tspecs", tSpecsText(tSpecs))}
      >
        {#if copied === "tspecs"}
          <CheckIcon class={iconSize} />
        {:else}
          <CopyIcon class={iconSize} />
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
        onclick={() => copyText("max", max || "N/A")}
      >
        {#if copied === "max"}
          <CheckIcon class={iconSize} />
        {:else}
          <CopyIcon class={iconSize} />
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
        onclick={() => copyText("options", options || "N/A")}
      >
        {#if copied === "options"}
          <CheckIcon class={iconSize} />
        {:else}
          <CopyIcon class={iconSize} />
        {/if}
      </button>
      <pre class={preClass}>{options || "N/A"}</pre>
    </div>
  </div>

</div>
