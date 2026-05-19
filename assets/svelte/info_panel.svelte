<script>
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { Maximize2 } from "@lucide/svelte/icons";
  import InfoHover from "$lib/components/info_hover.svelte";
  import DetailDialog from "$lib/components/detail_dialog.svelte";
  import SettingsDisplay from "$lib/components/settings_display.svelte";
  import NodeSwitcher from "./node_switcher.svelte";

  let { live, node_info, trace_settings } = $props();
  let tspecsDialogOpen = $state(false);
</script>

<div class="p-2 space-y-2">
  {#if node_info.node_list.length > 1}
    <NodeSwitcher {live} nodeList={node_info.node_list} selectedNode={node_info.connected_node} />
  {/if}

  <!-- Card: Node Info -->
  <div class="rounded-xl border bg-card text-card-foreground shadow-sm">
    <div class="px-3 pt-3 pb-1.5 text-sm font-semibold">Node Info</div>
    <div class="px-3 pb-3 grid grid-cols-[auto_1fr] gap-x-3 gap-y-1.5 items-center">
      <span class="text-xs text-muted-foreground whitespace-nowrap">Local Node</span>
      <Badge variant="outline" class="justify-self-start text-xs font-mono">
        {node_info.local_node}
      </Badge>

      <span class="text-xs text-muted-foreground whitespace-nowrap">Connected</span>
      <Badge variant="outline" class="justify-self-start text-xs font-mono">
        {node_info.connected_node}
      </Badge>

      <span class="text-xs text-muted-foreground whitespace-nowrap">Self Node</span>
      <Badge variant={node_info.is_self ? "default" : "outline"} class="justify-self-start text-xs">
        {node_info.is_self ? "Yes" : "No"}
      </Badge>

      <span class="text-xs text-muted-foreground whitespace-nowrap flex items-center gap-1">
        Code Mode
        <InfoHover>
          <div class="space-y-2 text-sm">
            <p>The runtime system can be started in either embedded or interactive mode.</p>
            <p><strong>Embedded</strong> — all code is loaded during system start-up according to the boot script.</p>
            <p><strong>Interactive</strong> — code is dynamically loaded when first referenced.</p>
          </div>
        </InfoHover>
      </span>
      <Badge variant="outline" class="justify-self-start text-xs">
        {node_info.code_mode}
      </Badge>
    </div>
  </div>

  <!-- Card: Trace Settings -->
  <div class="rounded-xl border bg-card text-card-foreground shadow-sm">
    <div class="px-3 pt-3 pb-1.5 flex items-center justify-between">
      <span class="text-sm font-semibold">Trace Settings</span>
      <button
        class="rounded p-1 text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
        onclick={() => { tspecsDialogOpen = true; }}
        title="Expand Settings"
      >
        <Maximize2 class="size-3.5" />
      </button>
    </div>
    <div class="px-3 pb-3">
      <SettingsDisplay
        tSpecs={trace_settings.t_specs}
        max={trace_settings.max}
        options={trace_settings.options}
        compact
      />
    </div>
  </div>
</div>

<DetailDialog
  bind:open={tspecsDialogOpen}
  title="Trace Settings"
  tSpecs={trace_settings.t_specs}
  max={trace_settings.max}
  options={trace_settings.options}
/>
