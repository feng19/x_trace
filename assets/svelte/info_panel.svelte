<script>
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { Maximize2 } from "lucide-svelte/icons";
  import InfoHover from "$lib/components/info_hover.svelte";
  import DetailDialog from "$lib/components/detail_dialog.svelte";
  import SettingsDisplay from "$lib/components/settings_display.svelte";
  import NodeSwitcher from "./node_switcher.svelte";

  export let live;
  export let node_info;
  export let trace_settings;
  let tspecsDialogOpen = false;
</script>

<div class="p-2 space-y-2">
  {#if node_info.node_list.length > 1}
    <NodeSwitcher {live} nodeList={node_info.node_list} selectedNode={node_info.connected_node} />
  {/if}

  <div class="grid grid-cols-[auto_1fr] gap-x-2 gap-y-1 items-center">
    <div class="font-bold whitespace-nowrap">Local Node</div>
    <div>
      <Badge variant="outline">
        {node_info.local_node}
      </Badge>
    </div>

    <div class="font-bold whitespace-nowrap">Connected Node</div>
    <div>
      <Badge variant="outline">
        {node_info.connected_node}
      </Badge>
    </div>

    <div class="font-bold whitespace-nowrap">Self Node</div>
    <div>
      <Badge variant="outline">
        {node_info.is_self ? "Yes" : "No"}
      </Badge>
    </div>

    <div class="font-bold flex items-center gap-1 whitespace-nowrap">
      <span>Code mode</span>
      <InfoHover>
        <pre
          class="text-wrap">The runtime system can be started in either embedded or interactive mode.</pre>
        <br />
        <pre
          class="text-wrap">In embedded mode, all code is loaded during system start-up according to the boot script.</pre>
        <br />
        <pre
          class="text-wrap">In interactive mode, code is dynamically loaded when first referenced.</pre>
      </InfoHover>
    </div>
    <div>
      <Badge variant="outline">
        {node_info.code_mode}
      </Badge>
    </div>
  </div>

  <div class="relative">
    <div class="absolute top-0 right-0 z-10">
      <button
        class="rounded p-0.5 text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
        on:click={() => { tspecsDialogOpen = true; }}
        title="Expand Settings"
      >
        <Maximize2 class="size-3.5" />
      </button>
    </div>
    <SettingsDisplay
      tSpecs={trace_settings.t_specs}
      max={trace_settings.max}
      options={trace_settings.options}
      cli={trace_settings.cli}
      compact
    />
  </div>

</div>

<DetailDialog
  bind:open={tspecsDialogOpen}
  title="Trace Settings"
  tSpecs={trace_settings.t_specs}
  max={trace_settings.max}
  options={trace_settings.options}
  cli={trace_settings.cli}
/>
