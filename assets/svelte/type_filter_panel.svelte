<script>
  import { filterStore } from "./filter_store.js";
  import { TYPE_DOT_COLORS, getDotClass } from "./log_type_colors.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { ListFilter } from "lucide-svelte/icons";

  let open = false;
  let pidInputValue = "";

  // Type filter
  $: hiddenTypes = $filterStore.hiddenTypes;
  $: availableTypes = $filterStore.availableTypes;
  $: hiddenTypeCount = hiddenTypes.length;
  $: hasHiddenTypes = hiddenTypeCount > 0;
  $: allTypesHidden = availableTypes.length > 0 && hiddenTypeCount >= availableTypes.length;

  // PID filter
  $: filterPids = $filterStore.filterPids;
  $: filterPidCount = filterPids.length;
  $: hasFilterPids = filterPidCount > 0;

  // Combined count for badge
  $: totalFilterCount = hiddenTypeCount + filterPidCount;
  $: hasAnyFilter = totalFilterCount > 0;

  function isTypeChecked(type) {
    return !hiddenTypes.includes(type);
  }

  function onToggleType(type) {
    filterStore.toggleType(type);
  }

  function selectAllTypes() {
    filterStore.showAllTypes();
  }

  function deselectAllTypes() {
    filterStore.hideAllTypes();
  }

  function addPid() {
    const pid = pidInputValue.trim();
    if (pid) {
      filterStore.addFilterPid(pid);
      pidInputValue = "";
    }
  }

  function removePid(pid) {
    filterStore.removeFilterPid(pid);
  }

  function clearPids() {
    filterStore.clearFilterPids();
    pidInputValue = "";
  }

  function handlePidKeyDown(e) {
    if (e.key === "Enter") {
      e.preventDefault();
      addPid();
    } else if (e.key === "Backspace" && pidInputValue === "" && filterPids.length > 0) {
      removePid(filterPids[filterPids.length - 1]);
    }
  }
</script>

<Popover.Root bind:open>
  <Popover.Trigger asChild let:builder>
    <Tooltip.Root openDelay={0}>
      <Tooltip.Trigger asChild let:builder={tooltipBuilder}>
        <Button
          builders={[builder, tooltipBuilder]}
          variant="ghost"
          size="icon"
          class="size-9 shrink-0 relative"
        >
          <ListFilter class="size-4" aria-hidden="true" />
          {#if hasAnyFilter}
            <span
              class="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-orange-600 px-1 text-[10px] font-medium text-white"
            >
              {totalFilterCount}
            </span>
          {/if}
          <span class="sr-only">Filter by</span>
        </Button>
      </Tooltip.Trigger>
      <Tooltip.Content side="bottom" class="flex items-center gap-4">
        Filter by{hasAnyFilter ? ` (${totalFilterCount} active)` : ""}
      </Tooltip.Content>
    </Tooltip.Root>
  </Popover.Trigger>

  <Popover.Content class="w-64 p-0" align="start">
    <div class="p-3 space-y-3">
      <!-- Type Section Header -->
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium">Type</span>
        <div class="flex items-center gap-1">
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" on:click={selectAllTypes} disabled={!hasHiddenTypes}>
            All
          </Button>
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" on:click={deselectAllTypes} disabled={allTypesHidden}>
            None
          </Button>
        </div>
      </div>

      <!-- Type checkboxes -->
      {#if availableTypes.length > 0}
        <div class="max-h-48 overflow-y-auto space-y-1">
          {#each availableTypes as type (type)}
            <button
              class="flex w-full items-center gap-2 rounded-md px-2 py-1 text-sm hover:bg-accent transition-colors"
              on:click={() => onToggleType(type)}
            >
              <Checkbox
                checked={isTypeChecked(type)}
                class="pointer-events-none"
              />
              <span class="shrink-0 inline-block size-2.5 rounded-full {getDotClass(type)}"></span>
              <span class="truncate">{type}</span>
            </button>
          {/each}
        </div>
      {:else}
        <div class="text-xs text-muted-foreground">
          No log types detected yet.
        </div>
      {/if}

      <!-- Type Info -->
      {#if hasHiddenTypes}
        <div class="text-xs text-muted-foreground">
          {hiddenTypeCount} type{hiddenTypeCount > 1 ? "s" : ""} hidden
        </div>
      {/if}

      <!-- Separator -->
      <div class="border-t"></div>

      <!-- PID Section Header -->
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium">PID</span>
        {#if hasFilterPids}
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" on:click={clearPids}>
            Clear
          </Button>
        {/if}
      </div>

      <!-- PID input with tags -->
      <div class="flex flex-wrap items-center gap-1 rounded-md border border-input bg-background px-2 py-1.5 min-h-[36px]">
        {#each filterPids as pid (pid)}
          <Badge variant="secondary" class="gap-1 pl-2 pr-1 py-0.5 text-xs font-mono">
            {pid}
            <button
              class="ml-0.5 rounded-sm hover:bg-muted-foreground/20 p-0.5 leading-none"
              on:click|stopPropagation={() => removePid(pid)}
            >
              ✕
            </button>
          </Badge>
        {/each}
        <input
          bind:value={pidInputValue}
          on:keydown={handlePidKeyDown}
          class="flex-1 min-w-[60px] bg-transparent text-sm outline-none placeholder:text-muted-foreground font-mono"
          placeholder={filterPids.length === 0 ? "Paste PID to filter…" : "Add PID…"}
        />
      </div>

      <!-- PID Info -->
      {#if hasFilterPids}
        <div class="text-xs text-muted-foreground">
          Showing only {filterPidCount} PID{filterPidCount > 1 ? "s" : ""}
        </div>
      {:else}
        <div class="text-xs text-muted-foreground">
          No PID filter — showing all
        </div>
      {/if}
    </div>
  </Popover.Content>
</Popover.Root>
