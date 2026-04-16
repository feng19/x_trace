<script>
  import { dashboardStore } from "./d_store.js";
  import FilterPanel from "./filter_panel.svelte";
  import {
    Eraser,
    Download,
    FileUp,
    FileText,
    FileJson,
    Play,
    SquareX,
    ChevronDown,
    ChevronsDownUp,
    ChevronsUpDown,
  } from "lucide-svelte/icons";
  import { Input } from "$lib/components/ui/input";
  import { Button } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import * as Popover from "$lib/components/ui/popover/index.js";

  export let live;
  export let isTracing = false;
  export let op_status;

  $: startTraceItem = {
    show: op_status.start_trace !== "hidden",
    disabled: !op_status.start_trace,
  };
  $: stopTraceItem = {
    show: op_status.stop_trace !== "hidden",
    disabled: !op_status.stop_trace,
  };

  let downloadOpen = false;
  let clearConfirmOpen = false;

  const isMac = typeof navigator !== "undefined" && /Mac|iPhone|iPad|iPod/.test(navigator.platform);

  $: hasLogs = $dashboardStore.log_count > 0;
  $: expandAll = $dashboardStore.expand_all;
  $: hasAnyExpanded = $dashboardStore.expanded_count > 0;

  function doClearLogs() {
    clearConfirmOpen = false;
    window.dispatchEvent(new CustomEvent("x:clear-logs"));
  }

  function downloadLogs(format) {
    downloadOpen = false;
    window.dispatchEvent(new CustomEvent("x:download-logs", { detail: { format } }));
  }

  function importLogs() {
    document.getElementById("upload-log-input").click();
  }
</script>

{#if isTracing && stopTraceItem.show}
  <Tooltip.Root openDelay={0}>
    <Tooltip.Trigger asChild let:builder>
      <Button
        on:click={() => live.pushEvent("stop-trace", {})}
        builders={[builder]}
        variant="ghost"
        size="icon"
        class="size-9 text-red-600 shrink-0"
        disabled={stopTraceItem.disabled}
      >
        <SquareX class="size-4" aria-hidden="true" />
        <span class="sr-only">Stop Trace</span>
      </Button>
    </Tooltip.Trigger>
    <Tooltip.Content side="bottom" class="flex items-center gap-4">
      Stop Trace
    </Tooltip.Content>
  </Tooltip.Root>
{:else if !isTracing && startTraceItem.show}
  <Tooltip.Root openDelay={0}>
    <Tooltip.Trigger asChild let:builder>
      <Button
        on:click={() => live.pushEvent("start-trace", {})}
        builders={[builder]}
        variant="ghost"
        size="icon"
        class="size-9 text-red-600 shrink-0"
        disabled={startTraceItem.disabled}
      >
        <Play class="size-4" aria-hidden="true" />
        <span class="sr-only">Start Trace</span>
      </Button>
    </Tooltip.Trigger>
    <Tooltip.Content side="bottom" class="flex items-center gap-4">
      Start Trace
    </Tooltip.Content>
  </Tooltip.Root>
{/if}

<div class="flex-1">
  <Input id="searchInput" name="search" />
</div>

<FilterPanel />

{#if hasLogs && !expandAll}
  <Tooltip.Root openDelay={0}>
    <Tooltip.Trigger asChild let:builder>
      <Button
        on:click={() => window.dispatchEvent(new CustomEvent("x:expand-all-logs"))}
        builders={[builder]}
        variant="ghost"
        size="icon"
        class="size-9 shrink-0"
      >
        <ChevronsUpDown class="size-4" aria-hidden="true" />
        <span class="sr-only">Expand All</span>
      </Button>
    </Tooltip.Trigger>
    <Tooltip.Content side="bottom" class="flex items-center gap-4">
      Expand All
    </Tooltip.Content>
  </Tooltip.Root>
{/if}

{#if hasAnyExpanded}
  <Tooltip.Root openDelay={0}>
    <Tooltip.Trigger asChild let:builder>
      <Button
        on:click={() => window.dispatchEvent(new CustomEvent("x:collapse-all-logs"))}
        builders={[builder]}
        variant="ghost"
        size="icon"
        class="size-9 shrink-0"
      >
        <ChevronsDownUp class="size-4" aria-hidden="true" />
        <span class="sr-only">Collapse All</span>
      </Button>
    </Tooltip.Trigger>
    <Tooltip.Content side="bottom" class="flex items-center gap-4">
      Collapse All
    </Tooltip.Content>
  </Tooltip.Root>
{/if}

{#if hasLogs}
  <Popover.Root bind:open={clearConfirmOpen}>
    <Popover.Trigger asChild let:builder>
      <Tooltip.Root openDelay={0}>
        <Tooltip.Trigger asChild let:builder={tooltipBuilder}>
          <Button
            builders={[builder, tooltipBuilder]}
            variant="ghost"
            size="icon"
            class="size-9 shrink-0"
          >
            <Eraser class="size-4" aria-hidden="true" />
            <span class="sr-only">Clear All</span>
          </Button>
        </Tooltip.Trigger>
        <Tooltip.Content side="bottom" class="flex items-center gap-4">
          Clear All
          <kbd class="pointer-events-none ml-1 inline-flex h-5 select-none items-center gap-0.5 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground">
            {isMac ? "⌘⇧K" : "Ctrl+Shift+K"}
          </kbd>
        </Tooltip.Content>
      </Tooltip.Root>
    </Popover.Trigger>
    <Popover.Content class="w-56 p-3" align="end">
      <p class="text-sm text-muted-foreground mb-3">Are you sure you want to clear all logs?</p>
      <div class="flex justify-end gap-2">
        <Button variant="outline" size="sm" on:click={() => (clearConfirmOpen = false)}>
          Cancel
        </Button>
        <Button variant="destructive" size="sm" on:click={doClearLogs}>
          Clear
        </Button>
      </div>
    </Popover.Content>
  </Popover.Root>
{/if}

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
