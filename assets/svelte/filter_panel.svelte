<script>
  import { filterStore } from "./filter_store.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { SlidersHorizontal, Eraser } from "lucide-svelte/icons";
  import { Badge } from "$lib/components/ui/badge/index.js";

  let open = false;
  let inputValue = "";
  let dropdownIndex = -1;
  let inputEl;

  $: filteredKeys = $filterStore.filteredKeys;
  $: availableKeys = $filterStore.availableKeys;
  $: filterCount = filteredKeys.length;
  $: hasFilter = filterCount > 0;

  // Dropdown items: available keys minus already-filtered, filtered by input text
  $: dropdownItems = availableKeys.filter(
    (k) => !filteredKeys.includes(k) && (inputValue === "" || k.toLowerCase().includes(inputValue.toLowerCase()))
  );

  function selectKey(key) {
    filterStore.addKey(key);
    inputValue = "";
    dropdownIndex = -1;
    if (inputEl) inputEl.focus();
  }

  function removeKey(key) {
    filterStore.removeKey(key);
  }

  function clearAll() {
    filterStore.clearKeys();
    inputValue = "";
    dropdownIndex = -1;
  }

  function handleKeyDown(e) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      if (dropdownItems.length > 0) {
        dropdownIndex = Math.min(dropdownIndex + 1, dropdownItems.length - 1);
      }
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      if (dropdownIndex > 0) {
        dropdownIndex = dropdownIndex - 1;
      }
    } else if (e.key === "Enter") {
      e.preventDefault();
      if (dropdownIndex >= 0 && dropdownIndex < dropdownItems.length) {
        selectKey(dropdownItems[dropdownIndex]);
      } else if (inputValue.trim()) {
        // Try exact match (case-insensitive)
        const match = availableKeys.find(
          (k) => k.toLowerCase() === inputValue.trim().toLowerCase()
        );
        if (match && !filteredKeys.includes(match)) {
          selectKey(match);
        }
      }
    } else if (e.key === "Escape") {
      e.preventDefault();
      if (inputValue) {
        inputValue = "";
        dropdownIndex = -1;
      } else {
        open = false;
      }
    } else if (e.key === "Backspace" && inputValue === "" && filteredKeys.length > 0) {
      // Remove the last filter tag on backspace with empty input
      removeKey(filteredKeys[filteredKeys.length - 1]);
    }
  }

  function onInput() {
    dropdownIndex = -1;
  }

  function onOpen(isOpen) {
    open = isOpen;
    if (isOpen) {
      // Focus input when popover opens
      setTimeout(() => {
        if (inputEl) inputEl.focus();
      }, 50);
    } else {
      inputValue = "";
      dropdownIndex = -1;
    }
  }
</script>

<Popover.Root bind:open onOpenChange={onOpen}>
  <Popover.Trigger asChild let:builder>
    <Tooltip.Root openDelay={0}>
      <Tooltip.Trigger asChild let:builder={tooltipBuilder}>
        <Button
          builders={[builder, tooltipBuilder]}
          variant="ghost"
          size="icon"
          class="size-9 shrink-0 relative"
        >
          <SlidersHorizontal class="size-4" aria-hidden="true" />
          {#if hasFilter}
            <span
              class="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-blue-600 px-1 text-[10px] font-medium text-white"
            >
              {filterCount}
            </span>
          {/if}
          <span class="sr-only">Filter Keys</span>
        </Button>
      </Tooltip.Trigger>
      <Tooltip.Content side="bottom" class="flex items-center gap-4">
        Filter Keys{hasFilter ? ` (${filterCount} hidden)` : ""}
      </Tooltip.Content>
    </Tooltip.Root>
  </Popover.Trigger>

  <Popover.Content class="w-72 p-0" align="start">
    <div class="p-3 space-y-3">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium">Filter by Key</span>
        {#if hasFilter}
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" on:click={clearAll}>
            <Eraser class="size-3 mr-1" />
            Clear
          </Button>
        {/if}
      </div>

      <!-- Input with dropdown -->
      <div class="relative">
        <!-- Tags + Input -->
        <div class="flex flex-wrap items-center gap-1 rounded-md border border-input bg-background px-2 py-1.5 min-h-[36px]">
          {#each filteredKeys as key (key)}
            <Badge variant="secondary" class="gap-1 pl-2 pr-1 py-0.5 text-xs">
              {key}
              <button
                class="ml-0.5 rounded-sm hover:bg-muted-foreground/20 p-0.5 leading-none"
                on:click|stopPropagation={() => removeKey(key)}
              >
                ✕
              </button>
            </Badge>
          {/each}
          <input
            bind:this={inputEl}
            bind:value={inputValue}
            on:input={onInput}
            on:keydown={handleKeyDown}
            class="flex-1 min-w-[60px] bg-transparent text-sm outline-none placeholder:text-muted-foreground"
            placeholder={filteredKeys.length === 0 ? "Filter by key…" : "Add key…"}
          />
        </div>

        <!-- Dropdown -->
        {#if open && dropdownItems.length > 0}
          <div class="absolute z-50 mt-1 w-full rounded-md border bg-popover shadow-md max-h-48 overflow-y-auto">
            {#each dropdownItems as item, i (item)}
              <button
                class="w-full px-3 py-1.5 text-sm text-left hover:bg-accent hover:text-accent-foreground {i === dropdownIndex ? 'bg-accent text-accent-foreground' : ''}"
                on:mousedown|preventDefault={() => selectKey(item)}
              >
                {item}
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <!-- Info -->
      {#if hasFilter}
        <div class="text-xs text-muted-foreground">
          {filterCount} key{filterCount > 1 ? "s" : ""} hidden
        </div>
      {:else if availableKeys.length === 0}
        <div class="text-xs text-muted-foreground">
          No keys detected yet. Expand a log entry to detect keys.
        </div>
      {/if}
    </div>
  </Popover.Content>
</Popover.Root>
