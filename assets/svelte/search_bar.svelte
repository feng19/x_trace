<script>
  import { dashboardStore } from "./d_store.js";
  import NavBar from "$lib/components/nav_bar.svelte";
  import {
    Eraser,
    Download,
    FileUp,
    FileText,
    FileJson,
    SquareX,
    ChevronDown,
  } from "lucide-svelte/icons";
  import { Input } from "$lib/components/ui/input";
  import { Button } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import * as Popover from "$lib/components/ui/popover/index.js";

  export let live;
  export let isTracing = false;

  let downloadOpen = false;

  $: hasLogs = $dashboardStore.log_count > 0;

  $: items = [
    {
      title: "Clear All",
      icon: Eraser,
      event: { type: "window", name: "clear-logs" },
      variant: "ghost",
      show: hasLogs,
      disabled: !hasLogs,
    },
  ];

  function downloadLogs(format) {
    downloadOpen = false;
    window.dispatchEvent(new CustomEvent("x:download-logs", { detail: { format } }));
  }

  function importLogs() {
    document.getElementById("upload-log-input").click();
  }
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

{#if hasLogs}
  <Popover.Root bind:open={downloadOpen}>
    <Popover.Trigger asChild let:builder>
      <Tooltip.Root openDelay={0}>
        <Tooltip.Trigger asChild let:builder={tooltipBuilder}>
          <Button
            builders={[builder, tooltipBuilder]}
            variant="ghost"
            size="icon"
            class="size-9 shrink-0"
          >
            <Download class="size-4" aria-hidden="true" />
            <span class="sr-only">Download logs</span>
          </Button>
        </Tooltip.Trigger>
        <Tooltip.Content side="bottom" class="flex items-center gap-4">
          Download logs
        </Tooltip.Content>
      </Tooltip.Root>
    </Popover.Trigger>
    <Popover.Content class="w-48 p-1" align="end">
      <button
        class="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-sm hover:bg-accent hover:text-accent-foreground"
        on:click={() => downloadLogs("text")}
      >
        <FileText class="size-4" />
        Plaintext (.log)
      </button>
      <button
        class="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-sm hover:bg-accent hover:text-accent-foreground"
        on:click={() => downloadLogs("json")}
      >
        <FileJson class="size-4" />
        JSON (.json)
      </button>
    </Popover.Content>
  </Popover.Root>
{/if}

<Tooltip.Root openDelay={0}>
  <Tooltip.Trigger asChild let:builder>
    <Button
      on:click={importLogs}
      builders={[builder]}
      variant="ghost"
      size="icon"
      class="size-9 shrink-0"
    >
      <FileUp class="size-4" aria-hidden="true" />
      <span class="sr-only">Import JSON logs</span>
    </Button>
  </Tooltip.Trigger>
  <Tooltip.Content side="bottom" class="flex items-center gap-4">
    Import JSON logs
  </Tooltip.Content>
</Tooltip.Root>
