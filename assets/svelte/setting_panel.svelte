<script>
  import { dashboardStore } from "./d_store.js";
  import * as Accordion from "$lib/components/ui/accordion/index.js";
  import { Separator } from "$lib/components/ui/select";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Trash2 } from "lucide-svelte/icons";
  import NodeSettings from "./settings/node.svelte";
  import SpecsSettings from "./settings/specs.svelte";
  import MaxRateSettings from "./settings/max_rate.svelte";
  import OptionsSettings from "./settings/options.svelte";
  import LocalSettings from "./settings/local.svelte";
  import InfoHover from "$lib/components/info_hover.svelte";

  export let live;
  export let node_info;
  export let trace_settings;
  export let rate_limiting;
  export let options_settings;

  function clearAllTSpecs() {
    live.pushEvent("clear-tspecs", {});
  }
</script>

<Accordion.Root value={$dashboardStore.setting_tab} onValueChange={dashboardStore.setSettingTab}>
  <Accordion.Item value="node-settings">
    <Accordion.Trigger class="px-4">Node Settings</Accordion.Trigger>
    <Accordion.Content class="p-4 space-y-4">
      <NodeSettings {node_info}/>
    </Accordion.Content>
  </Accordion.Item>

  <Accordion.Item value="trace-settings">
    <Accordion.Trigger class="px-4">Trace Settings</Accordion.Trigger>
    <Accordion.Content class="p-4">
      <div class="space-y-4">
        <div class="flex items-center justify-between">
          <div class="text-lg font-bold">Matching Patterns</div>
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
        <SpecsSettings {live} t_specs={trace_settings.t_specs}/>

        <Separator/>

        <div class="text-lg font-bold flex items-center gap-2">
          Rate-Limiting
          <InfoHover>
            <pre class="text-wrap">Be aware that extremely broad patterns with lax rate-limiting (or very high absolute limits) may impact your node's stability in ways X-Trace cannot easily help you with.
            </pre>

            <pre class="text-wrap">In doubt, start with the most restrictive tracing possible, with low limits, and progressively increase your scope.</pre>
          </InfoHover>
        </div>
        <MaxRateSettings {rate_limiting} />

        <Separator/>

        <div class="text-lg font-bold">Options</div>
        <OptionsSettings {live} {...options_settings}/>
      </div>
    </Accordion.Content>
  </Accordion.Item>

  <Accordion.Item value="local-settings">
    <Accordion.Trigger class="px-4">Local Storage</Accordion.Trigger>
    <Accordion.Content class="p-4">
      <LocalSettings {live}/>
    </Accordion.Content>
  </Accordion.Item>
</Accordion.Root>
