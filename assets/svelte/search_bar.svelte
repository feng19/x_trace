<script>
  import { dashboardStore } from "./d_store.js";
  import { filterStore } from "./filter_store.js";
  import FilterPanel from "./filter_panel.svelte";
  import TypeFilterPanel from "./type_filter_panel.svelte";
  import {
    Eraser,
    Download,
    FileUp,
    FileText,
    FileJson,
    Play,
    SquareX,
    ChevronDown,
    ChevronUp,
    ChevronsDownUp,
    ChevronsUpDown,
    CaseSensitive,
    X,
    Layers,
  } from "lucide-svelte/icons";
  import { Input } from "$lib/components/ui/input";
  import { Checkbox } from "$lib/components/ui/checkbox";
  import { Label } from "$lib/components/ui/label";
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

  // Fold level from filter store
  $: foldLevel = $filterStore.foldLevel;
  $: showDetailsPid = $filterStore.showDetailsPid;
  $: showDetailsTime = $filterStore.showDetailsTime;

  let foldLevelOpen = false;

  function onFoldLevelSlider(e) {
    const val = parseInt(e.target.value, 10);
    if (!isNaN(val)) filterStore.setFoldLevel(val);
  }

  function onFoldLevelInput(e) {
    let val = parseInt(e.target.value, 10);
    if (isNaN(val)) return;
    if (val < 0) val = 0;
    if (val > 10) val = 10;
    filterStore.setFoldLevel(val);
  }

  // Search state from filter store
  $: searchQuery = $filterStore.searchQuery;
  $: searchTotalMatches = $filterStore.searchTotalMatches;
  $: searchCaseSensitive = $filterStore.searchCaseSensitive;
  $: hasSearchQuery = searchQuery.length > 0;

  let searchValue = "";
  let searchDebounceTimer;
  let searchFocused = false;

  function onSearchInput(e) {
    searchValue = e.target.value;
    clearTimeout(searchDebounceTimer);
    searchDebounceTimer = setTimeout(() => {
      // Auto-expand all logs so viewers are registered and searchable
      if (searchValue && hasLogs && !expandAll) {
        window.dispatchEvent(new CustomEvent("x:expand-all-logs"));
      }
      filterStore.searchAll(searchValue);
    }, 150);
  }

  function onSearchFocus() {
    searchFocused = true;
  }

  function onSearchBlur() {
    searchFocused = false;
  }

  function onSearchKeyDown(e) {
    if (e.key === "Enter") {
      e.preventDefault();
      if (e.shiftKey) {
        filterStore.searchPrev();
      } else {
        filterStore.searchNext();
      }
    } else if (e.key === "Escape") {
      e.preventDefault();
      searchValue = "";
      filterStore.clearSearchAll();
      e.target.blur();
    }
  }

  function clearSearch() {
    searchValue = "";
    filterStore.clearSearchAll();
    // Re-focus the input
    const input = document.getElementById("searchInput");
    if (input) input.focus();
  }

  function toggleCaseSensitive() {
    filterStore.toggleCaseSensitive();
  }

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

<div class="flex-1 relative flex items-center">
  <Input
    id="searchInput"
    name="search"
    placeholder="Search… (Enter: next, Shift+Enter: prev)"
    value={searchValue}
    on:input={onSearchInput}
    on:keydown={onSearchKeyDown}
    on:focus={onSearchFocus}
    on:blur={onSearchBlur}
    class="pr-20 transition-all duration-200 {searchFocused ? 'ring-2 ring-blue-500 border-blue-500 shadow-[0_0_0_3px_rgba(59,130,246,0.15)]' : ''} {hasSearchQuery ? 'border-blue-400 bg-blue-50/50 dark:bg-blue-950/20 dark:border-blue-700' : ''}"
  />
  <div class="absolute right-1 flex items-center gap-0.5">
    {#if hasSearchQuery}
      <span class="text-xs text-muted-foreground tabular-nums px-1 select-none">
        {searchTotalMatches} {searchTotalMatches === 1 ? "match" : "matches"}
      </span>
    {/if}
    <Tooltip.Root openDelay={0}>
      <Tooltip.Trigger asChild let:builder>
        <button
          class="inline-flex items-center justify-center rounded-sm size-6 transition-colors
            {searchCaseSensitive
              ? 'bg-primary text-primary-foreground'
              : 'text-muted-foreground hover:text-foreground hover:bg-accent'}"
          on:click={toggleCaseSensitive}
          use:builder.action
          {...builder}
        >
          <CaseSensitive class="size-3.5" />
        </button>
      </Tooltip.Trigger>
      <Tooltip.Content side="bottom">
        Match Case
      </Tooltip.Content>
    </Tooltip.Root>
    {#if hasSearchQuery}
      <Tooltip.Root openDelay={0}>
        <Tooltip.Trigger asChild let:builder>
          <button
            class="inline-flex items-center justify-center rounded-sm size-6 text-muted-foreground hover:text-foreground hover:bg-accent transition-colors"
            on:click={() => filterStore.searchPrev()}
            use:builder.action
            {...builder}
          >
            <ChevronUp class="size-3.5" />
          </button>
        </Tooltip.Trigger>
        <Tooltip.Content side="bottom">
          Previous Match (Shift+Enter)
        </Tooltip.Content>
      </Tooltip.Root>
      <Tooltip.Root openDelay={0}>
        <Tooltip.Trigger asChild let:builder>
          <button
            class="inline-flex items-center justify-center rounded-sm size-6 text-muted-foreground hover:text-foreground hover:bg-accent transition-colors"
            on:click={() => filterStore.searchNext()}
            use:builder.action
            {...builder}
          >
            <ChevronDown class="size-3.5" />
          </button>
        </Tooltip.Trigger>
        <Tooltip.Content side="bottom">
          Next Match (Enter)
        </Tooltip.Content>
      </Tooltip.Root>
      <Tooltip.Root openDelay={0}>
        <Tooltip.Trigger asChild let:builder>
          <button
            class="inline-flex items-center justify-center rounded-sm size-6 text-muted-foreground hover:text-foreground hover:bg-accent transition-colors"
            on:click={clearSearch}
            use:builder.action
            {...builder}
          >
            <X class="size-3.5" />
          </button>
        </Tooltip.Trigger>
        <Tooltip.Content side="bottom">
          Clear Search (Escape)
        </Tooltip.Content>
      </Tooltip.Root>
    {/if}
  </div>
</div>

<FilterPanel />
<TypeFilterPanel />

<Popover.Root bind:open={foldLevelOpen}>
  <Popover.Trigger asChild let:builder>
    <Tooltip.Root openDelay={0}>
      <Tooltip.Trigger asChild let:builder={tooltipBuilder}>
        <Button
          builders={[builder, tooltipBuilder]}
          variant="ghost"
          size="icon"
          class="size-9 shrink-0"
        >
          <Layers class="size-4" aria-hidden="true" />
          <span class="sr-only">Fold Level</span>
        </Button>
      </Tooltip.Trigger>
      <Tooltip.Content side="bottom" class="flex items-center gap-4">
        Fold Level: {foldLevel}
      </Tooltip.Content>
    </Tooltip.Root>
  </Popover.Trigger>

  <Popover.Content class="w-56 p-3" align="start">
    <div class="space-y-3">
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium">Fold Level</span>
        <span class="text-xs text-muted-foreground tabular-nums">{foldLevel} / 10</span>
      </div>
      <div class="flex items-center gap-3">
        <input
          type="range"
          min="0"
          max="10"
          step="1"
          value={foldLevel}
          on:input={onFoldLevelSlider}
          class="flex-1 h-2 accent-blue-600 cursor-pointer"
        />
        <input
          type="number"
          min="0"
          max="10"
          step="1"
          value={foldLevel}
          on:change={onFoldLevelInput}
          class="w-14 h-8 rounded-md border border-input bg-background px-2 text-sm text-center tabular-nums [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
        />
      </div>
      <div class="border-t pt-3 space-y-2">
        <span class="text-sm font-medium">Log Details</span>
        <div class="flex items-center gap-2">
          <Checkbox
            id="show-details-pid"
            checked={showDetailsPid}
            onCheckedChange={(val) => filterStore.setShowDetailsPid(val)}
          />
          <Label for="show-details-pid" class="text-sm cursor-pointer">Show PID</Label>
        </div>
        <div class="flex items-center gap-2">
          <Checkbox
            id="show-details-time"
            checked={showDetailsTime}
            onCheckedChange={(val) => filterStore.setShowDetailsTime(val)}
          />
          <Label for="show-details-time" class="text-sm cursor-pointer">Show Time</Label>
        </div>
      </div>
    </div>
  </Popover.Content>
</Popover.Root>

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
            {isMac ? "⌘K" : "Ctrl+K"}
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
