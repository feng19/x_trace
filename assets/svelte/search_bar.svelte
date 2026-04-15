<script>
  import { dashboardStore } from "./d_store.js";
  import NavBar from "$lib/components/nav_bar.svelte";
  import {
    Eraser,
    Download,
    SquareX,
  } from "lucide-svelte/icons";
  import { Input } from "$lib/components/ui/input";
  import { Button } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";

  export let live;
  export let isTracing = false;

  $: items = [
    {
      title: "Clear All",
      icon: Eraser,
      event: { type: "window", name: "clear-logs" },
      variant: "ghost",
      show: $dashboardStore.log_count !== 0,
      disabled: $dashboardStore.log_count == 0,
    },
    {
      title: "Download logs",
      icon: Download,
      event: { type: "window", name: "download-logs" },
      variant: "ghost",
      show: $dashboardStore.log_count !== 0,
      disabled: $dashboardStore.log_count == 0,
    },
  ];
</script>

{#if isTracing}
  <Tooltip.Root openDelay={0}>
    <Tooltip.Trigger asChild let:builder>
      <Button
        on:click={() => live.pushEvent("stop-trace", {})}
        builders={[builder]}
        variant="ghost"
        size="icon"
        class="size-9 text-red-600 shrink-0"
      >
        <SquareX class="size-4" aria-hidden="true" />
        <span class="sr-only">Stop Trace</span>
      </Button>
    </Tooltip.Trigger>
    <Tooltip.Content side="bottom" class="flex items-center gap-4">
      Stop Trace
    </Tooltip.Content>
  </Tooltip.Root>
{/if}

<div class="flex-1">
  <Input id="searchInput" name="search" />
</div>

<NavBar {live} {items} />
