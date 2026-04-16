<script>
  import { dashboardStore } from "./d_store.js";
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Trash2, FileUp, FileDown } from "lucide-svelte/icons";
  import NodeSettings from "./settings/node.svelte";
  import SpecsSettings from "./settings/specs.svelte";
  import MaxRateSettings from "./settings/max_rate.svelte";
  import OptionsSettings from "./settings/options.svelte";
  import LocalSettings from "./settings/local.svelte";
  import InfoHover from "$lib/components/info_hover.svelte";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";

  export let live;
  export let node_info;
  export let trace_settings;
  export let rate_limiting;
  export let options_settings;
  export let op_status;

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

<div class="p-2 sm:p-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-3 sm:gap-4">
  <!-- Card: Node Settings -->
  <div class="rounded-xl border bg-card text-card-foreground shadow-sm">
    <div class="px-4 pt-4 pb-2 text-lg font-semibold">Node Settings</div>
    <div class="p-4 pt-2">
      <NodeSettings {node_info} />
    </div>
  </div>

  <!-- Card: Rate-Limiting -->
  <div class="rounded-xl border bg-card text-card-foreground shadow-sm">
    <div class="px-4 pt-4 pb-2">
      <div class="text-lg font-semibold flex items-center gap-2">
        Rate-Limiting
        <InfoHover>
          <pre class="text-wrap">Be aware that extremely broad patterns with lax rate-limiting (or very high absolute limits) may impact your node's stability in ways X-Trace cannot easily help you with.
          </pre>

          <pre class="text-wrap">In doubt, start with the most restrictive tracing possible, with low limits, and progressively increase your scope.</pre>
        </InfoHover>
      </div>
    </div>
    <div class="p-4 pt-2">
      <MaxRateSettings {rate_limiting} />
    </div>
  </div>

  <!-- Card: Options (same row as Rate-Limiting) -->
  <div class="rounded-xl border bg-card text-card-foreground shadow-sm">
    <div class="px-4 pt-4 pb-2 text-lg font-semibold">Options</div>
    <div class="p-4 pt-2">
      <OptionsSettings {live} {...options_settings} />
    </div>
  </div>

  <!-- Card: Matching Patterns (full width) -->
  <div class="rounded-xl border bg-card text-card-foreground shadow-sm md:col-span-2 lg:col-span-3">
    <div class="px-4 pt-4 pb-2 flex items-center justify-between">
      <div class="text-lg font-semibold">Matching Patterns</div>
      {#if trace_settings.t_specs.length > 1}
        <Button
          variant="ghost"
          size="sm"
          class="h-7 px-2 text-destructive hover:text-destructive"
          on:click={clearAllTSpecs}
        >
          <Trash2 class="size-3.5 mr-1" /> Clear All
        </Button>
      {/if}
    </div>
    <div class="p-4 pt-2">
      <SpecsSettings {live} t_specs={trace_settings.t_specs} {op_status} />
    </div>
  </div>

  <!-- Card: Local Storage (full width) -->
  <div class="rounded-xl border bg-card text-card-foreground shadow-sm md:col-span-2 lg:col-span-3">
    <div class="px-4 pt-4 pb-2 flex items-center justify-between">
      <div class="text-lg font-semibold">Local Storage</div>
      <div class="flex items-center gap-1">
        {#if op_status.import_settings !== "hidden"}
          <Tooltip.Root openDelay={0}>
            <Tooltip.Trigger asChild let:builder>
              <Button
                on:click={importSettings}
                builders={[builder]}
                variant="ghost"
                size="icon"
                class="size-8"
              >
                <FileUp class="size-4" aria-hidden="true" />
                <span class="sr-only">Import Settings</span>
              </Button>
            </Tooltip.Trigger>
            <Tooltip.Content side="bottom" class="flex items-center gap-4">
              Import Settings
            </Tooltip.Content>
          </Tooltip.Root>
        {/if}
        {#if op_status.download_settings !== "hidden"}
          <Tooltip.Root openDelay={0}>
            <Tooltip.Trigger asChild let:builder>
              <Button
                on:click={downloadSettings}
                builders={[builder]}
                variant="ghost"
                size="icon"
                class="size-8"
              >
                <FileDown class="size-4" aria-hidden="true" />
                <span class="sr-only">Download Settings</span>
              </Button>
            </Tooltip.Trigger>
            <Tooltip.Content side="bottom" class="flex items-center gap-4">
              Download Settings
            </Tooltip.Content>
          </Tooltip.Root>
        {/if}
      </div>
    </div>
    <div class="p-4 pt-2">
      <LocalSettings {live} />
    </div>
  </div>
</div>
