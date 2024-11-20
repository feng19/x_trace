<script>
  import SettingPanel from "./setting_panel.svelte";
  import LogDetail from "./log_detail.svelte";
  import ControlNav from "./control_nav.svelte";
  import MapFilter from "$lib/filters/map_filter.svelte";
  import RecordFilter from "$lib/filters/record_filter.svelte";
  import StructFilter from "$lib/filters/struct_filter.svelte";
  import { dashboardStore } from "./d_store.js";
  import { Separator } from "$lib/components/ui/select";
  import { Button, buttonVariants } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import X from "lucide-svelte/icons/x";

  export let live;
  export let op_status;
  export let settings = {};
</script>

{#if $dashboardStore.selected}
  <LogDetail />
{:else if $dashboardStore.right_panel}
  <div class="grid grid-cols-1">
    <div class="sticky top-0 z-49">
      <div class="px-2 bg-white flex h-[52px] items-center justify-end">
        <Tooltip.Root openDelay={0}>
          <Tooltip.Trigger
            class={buttonVariants({ variant: "ghost", size: "icon" })}
          >
            <Button
              variant="link"
              size="icon"
              on:click={() => dashboardStore.setRightPanel(null)}
            >
              <X class="size-4" />
            </Button>
            <span class="sr-only">Close</span>
          </Tooltip.Trigger>
          <Tooltip.Content>Close</Tooltip.Content>
        </Tooltip.Root>
      </div>
      <Separator />
    </div>
    <div class="p-4">
      {#if $dashboardStore.right_panel === "map-filter"}
        <MapFilter {live} />
      {:else if $dashboardStore.right_panel === "record-filter"}
        <RecordFilter {live} />
      {:else if $dashboardStore.right_panel === "struct-filter"}
        <StructFilter {live} struct_list={settings.spec_datalist.struct_list} />
      {/if}
    </div>
  </div>
{:else}
  <div class="sticky top-0 z-49 bg-white">
    <div class="px-2 h-[52px] flex items-center gap-2">
      <ControlNav {live} {op_status} isCollapsed side="bottom" />
    </div>
    <Separator />
  </div>
  <SettingPanel {live} {...settings} />
{/if}
