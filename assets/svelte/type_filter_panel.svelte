<script>
  import { filterStore } from "./filter_store.js";
  import { TYPE_DOT_COLORS, getDotClass } from "./log_type_colors.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { ListFilter } from "lucide-svelte/icons";

  let open = false;

  $: hiddenTypes = $filterStore.hiddenTypes;
  $: availableTypes = $filterStore.availableTypes;
  $: hiddenCount = hiddenTypes.length;
  $: hasHidden = hiddenCount > 0;
  $: allHidden = availableTypes.length > 0 && hiddenCount >= availableTypes.length;

  function isChecked(type) {
    return !hiddenTypes.includes(type);
  }

  function onToggle(type) {
    filterStore.toggleType(type);
  }

  function selectAll() {
    filterStore.showAllTypes();
  }

  function deselectAll() {
    filterStore.hideAllTypes();
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
          {#if hasHidden}
            <span
              class="absolute -top-0.5 -right-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-orange-600 px-1 text-[10px] font-medium text-white"
            >
              {hiddenCount}
            </span>
          {/if}
          <span class="sr-only">Filter by Type</span>
        </Button>
      </Tooltip.Trigger>
      <Tooltip.Content side="bottom" class="flex items-center gap-4">
        Filter by Type{hasHidden ? ` (${hiddenCount} hidden)` : ""}
      </Tooltip.Content>
    </Tooltip.Root>
  </Popover.Trigger>

  <Popover.Content class="w-60 p-0" align="start">
    <div class="p-3 space-y-3">
      <!-- Header -->
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium">Filter by Type</span>
        <div class="flex items-center gap-1">
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" on:click={selectAll} disabled={!hasHidden}>
            All
          </Button>
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" on:click={deselectAll} disabled={allHidden}>
            None
          </Button>
        </div>
      </div>

      <!-- Type checkboxes -->
      {#if availableTypes.length > 0}
        <div class="max-h-64 overflow-y-auto space-y-1">
          {#each availableTypes as type (type)}
            <button
              class="flex w-full items-center gap-2 rounded-md px-2 py-1 text-sm hover:bg-accent transition-colors"
              on:click={() => onToggle(type)}
            >
              <Checkbox
                checked={isChecked(type)}
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

      <!-- Info -->
      {#if hasHidden}
        <div class="text-xs text-muted-foreground">
          {hiddenCount} type{hiddenCount > 1 ? "s" : ""} hidden
        </div>
      {/if}
    </div>
  </Popover.Content>
</Popover.Root>
