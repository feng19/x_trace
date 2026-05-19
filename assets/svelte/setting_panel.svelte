<script>
  import { onMount, onDestroy } from "svelte";
  import { dashboardStore } from "./d_store.js";
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Trash2, FileUp, FileDown } from "@lucide/svelte/icons";
  import NodeSettings from "./settings/node.svelte";
  import SpecsSettings from "./settings/specs.svelte";
  import MaxRateSettings from "./settings/max_rate.svelte";
  import OptionsSettings from "./settings/options.svelte";
  import LocalSettings from "./settings/local.svelte";
  import InfoHover from "$lib/components/info_hover.svelte";

  let { live, node_info, trace_settings, rate_limiting, options_settings, op_status } = $props();

  /** Shared card class tokens */
  const card = "rounded-xl border bg-card text-card-foreground shadow-sm transition-shadow hover:shadow-md";
  const cardHeader = "flex items-center justify-between gap-2 px-4 pt-4 pb-2";
  const cardBody = "px-4 pb-4 pt-2";
  const spanFull = "md:col-span-2 lg:col-span-3";

  function handleKeydown(e) {
    if (e.key === "Escape") {
      dashboardStore.setSettingMode(false);
    }
  }

  onMount(() => {
    window.addEventListener("keydown", handleKeydown);
  });

  onDestroy(() => {
    window.removeEventListener("keydown", handleKeydown);
  });

  function clearAllTSpecs() {
    live.pushEvent("clear-tspecs", {});
  }

  function importSettings() {
    document.getElementById("upload-setting-input").click();
  }

  function downloadSettings() {
    if (window.__TAURI__) {
      settingsLocalStorage.tauri_download();
    } else {
      settingsLocalStorage.download();
    }
  }
</script>

<div class="grid auto-rows-min grid-cols-1 gap-4 p-2 sm:p-4 md:grid-cols-2 lg:grid-cols-3">
  <!-- Card: Node Settings -->
  <div class="{card} card-stagger" style="--stagger:0">
    <div class={cardHeader}>
      <h3 class="text-lg font-semibold">Node Settings</h3>
    </div>
    <div class={cardBody}>
      <NodeSettings {node_info} />
    </div>
  </div>

  <!-- Card: Rate-Limiting -->
  <div class="{card} card-stagger" style="--stagger:1">
    <div class={cardHeader}>
      <h3 class="text-lg font-semibold flex items-center gap-2">
        Rate-Limiting
        <InfoHover>
          <div class="space-y-2 text-sm leading-relaxed">
            <p>Be aware that extremely broad patterns with lax rate-limiting (or very high absolute limits) may impact your node's stability in ways X-Trace cannot easily help you with.</p>
            <p>In doubt, start with the most restrictive tracing possible, with low limits, and progressively increase your scope.</p>
          </div>
        </InfoHover>
      </h3>
    </div>
    <div class={cardBody}>
      <MaxRateSettings {rate_limiting} />
    </div>
  </div>

  <!-- Card: Options -->
  <div class="{card} card-stagger" style="--stagger:2">
    <div class={cardHeader}>
      <h3 class="text-lg font-semibold">Options</h3>
    </div>
    <div class={cardBody}>
      <OptionsSettings {live} {...options_settings} />
    </div>
  </div>

  <!-- Card: Matching Patterns (full width) -->
  <div class="{card} {spanFull} card-stagger" style="--stagger:3">
    <div class={cardHeader}>
      <h3 class="text-lg font-semibold flex items-center gap-1">
        Matching Patterns
        <InfoHover class="w-96">
          <div class="space-y-2 text-sm">
            <p>A <a href="https://www.erlang.org/doc/apps/erts/match_spec.html#grammar" target="_blank" rel="noopener noreferrer" class="underline text-blue-500 hover:text-blue-700">match specification</a> used in tracing.</p>
            <div>
              <p><strong>return_trace</strong> — Causes a <code class="text-xs bg-muted px-1 rounded">return_from</code> trace message to be sent upon return from the current function. Can only be used in the MatchBody part when tracing. If the process trace flag <code class="text-xs bg-muted px-1 rounded">silent</code> is active, the message is inhibited.</p>
              <p class="mt-1 text-yellow-600 dark:text-yellow-400 text-xs">⚠️ If the traced function is tail-recursive, this destroys that property. On a perpetual server process, it can only be active for a limited period of time, or the emulator will eventually use all memory and crash.</p>
            </div>
            <div>
              <p><strong>exception_trace</strong> — Works as <code class="text-xs bg-muted px-1 rounded">return_trace</code> plus: if the traced function exits because of an exception, an <code class="text-xs bg-muted px-1 rounded">exception_from</code> trace message is generated, regardless of whether the exception is caught or not.</p>
            </div>
          </div>
        </InfoHover>
      </h3>
      {#if trace_settings.t_specs.length > 1}
        <Button
          variant="ghost"
          size="sm"
          class="h-7 px-2 text-destructive hover:text-destructive"
          onclick={clearAllTSpecs}
        >
          <Trash2 class="size-3.5 mr-1" /> Clear All
        </Button>
      {/if}
    </div>
    <div class={cardBody}>
      <SpecsSettings {live} t_specs={trace_settings.t_specs} {op_status} />
    </div>
  </div>

  <!-- Card: Local Storage (full width) -->
  <div class="{card} {spanFull} card-stagger" style="--stagger:4">
    <div class={cardHeader}>
      <h3 class="text-lg font-semibold">Local Storage</h3>
      <div class="flex items-center gap-1">
        {#if op_status.import_settings !== "hidden"}
          <Button onclick={importSettings} variant="ghost" size="sm" class="h-7 px-2 text-xs">
            <FileUp class="size-3.5 mr-1" aria-hidden="true" />
            Import
          </Button>
        {/if}
        {#if op_status.download_settings !== "hidden"}
          <Button onclick={downloadSettings} variant="ghost" size="sm" class="h-7 px-2 text-xs">
            <FileDown class="size-3.5 mr-1" aria-hidden="true" />
            Download
          </Button>
        {/if}
      </div>
    </div>
    <div class={cardBody}>
      <LocalSettings {live} />
    </div>
  </div>
</div>

<style>
  @keyframes card-enter {
    from {
      opacity: 0;
      transform: translateY(16px) scale(0.97);
    }
    to {
      opacity: 1;
      transform: translateY(0) scale(1);
    }
  }

  .card-stagger {
    animation: card-enter 0.32s cubic-bezier(0.22, 1, 0.36, 1) both;
    animation-delay: calc(var(--stagger, 0) * 60ms + 80ms);
  }
</style>
