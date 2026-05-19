<script>
  import { filterStore } from "./filter_store.js";
  import { TYPE_DOT_COLORS, getDotClass } from "./log_type_colors.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { ListFilter } from "@lucide/svelte/icons";

  let open = $state(false);
  let pidInputValue = $state("");
  let pidDropdownIndex = $state(-1);
  let mfaInputValue = $state("");
  let mfaDropdownIndex = $state(-1);

  // Type filter
  let hiddenTypes = $derived($filterStore.hiddenTypes);
  let availableTypes = $derived($filterStore.availableTypes);
  let hiddenTypeCount = $derived(hiddenTypes.length);
  let hasHiddenTypes = $derived(hiddenTypeCount > 0);
  let allTypesHidden = $derived(availableTypes.length > 0 && hiddenTypeCount >= availableTypes.length);

  // PID filter
  let filterPids = $derived($filterStore.filterPids);
  let availablePids = $derived($filterStore.availablePids);
  let filterPidCount = $derived(filterPids.length);
  let hasFilterPids = $derived(filterPidCount > 0);

  // PID dropdown items: available PIDs minus already-filtered, filtered by input text
  let pidDropdownItems = $derived(availablePids.filter(
    (p) => !filterPids.includes(p) && (pidInputValue === "" || p.toLowerCase().includes(pidInputValue.toLowerCase()))
  ));

  // MFA filter
  let filterMfas = $derived($filterStore.filterMfas);
  let availableMfas = $derived($filterStore.availableMfas);
  let filterMfaCount = $derived(filterMfas.length);
  let hasFilterMfas = $derived(filterMfaCount > 0);

  // MFA dropdown items: available MFAs minus already-filtered, filtered by input text
  let mfaDropdownItems = $derived(availableMfas.filter(
    (m) => !filterMfas.includes(m) && (mfaInputValue === "" || m.toLowerCase().includes(mfaInputValue.toLowerCase()))
  ));

  // Combined count for badge
  let totalFilterCount = $derived(hiddenTypeCount + filterPidCount + filterMfaCount);
  let hasAnyFilter = $derived(totalFilterCount > 0);

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

  function selectPid(pid) {
    filterStore.addFilterPid(pid);
    pidInputValue = "";
    pidDropdownIndex = -1;
  }

  function removePid(pid) {
    filterStore.removeFilterPid(pid);
  }

  function clearPids() {
    filterStore.clearFilterPids();
    pidInputValue = "";
    pidDropdownIndex = -1;
  }

  function onPidInput() {
    pidDropdownIndex = -1;
  }

  function handlePidKeyDown(e) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      e.stopPropagation();
      if (pidDropdownItems.length > 0) {
        pidDropdownIndex = Math.min(pidDropdownIndex + 1, pidDropdownItems.length - 1);
      }
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      e.stopPropagation();
      if (pidDropdownIndex > 0) {
        pidDropdownIndex = pidDropdownIndex - 1;
      }
    } else if (e.key === "Enter") {
      e.preventDefault();
      e.stopPropagation();
      if (pidDropdownIndex >= 0 && pidDropdownIndex < pidDropdownItems.length) {
        selectPid(pidDropdownItems[pidDropdownIndex]);
      } else if (pidInputValue.trim()) {
        // Try exact match (case-insensitive) or add as-is
        const match = availablePids.find(
          (p) => p.toLowerCase() === pidInputValue.trim().toLowerCase()
        );
        if (match && !filterPids.includes(match)) {
          selectPid(match);
        } else if (!filterPids.includes(pidInputValue.trim())) {
          // Allow manually typed PIDs not in the available list
          selectPid(pidInputValue.trim());
        }
      }
    } else if (e.key === "Backspace" && pidInputValue === "" && filterPids.length > 0) {
      removePid(filterPids[filterPids.length - 1]);
    }
  }

  function selectMfa(mfa) {
    filterStore.addFilterMfa(mfa);
    mfaInputValue = "";
    mfaDropdownIndex = -1;
  }

  function removeMfa(mfa) {
    filterStore.removeFilterMfa(mfa);
  }

  function clearMfas() {
    filterStore.clearFilterMfas();
    mfaInputValue = "";
    mfaDropdownIndex = -1;
  }

  function onMfaInput() {
    mfaDropdownIndex = -1;
  }

  function handleMfaKeyDown(e) {
    if (e.key === "ArrowDown") {
      e.preventDefault();
      e.stopPropagation();
      if (mfaDropdownItems.length > 0) {
        mfaDropdownIndex = Math.min(mfaDropdownIndex + 1, mfaDropdownItems.length - 1);
      }
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      e.stopPropagation();
      if (mfaDropdownIndex > 0) {
        mfaDropdownIndex = mfaDropdownIndex - 1;
      }
    } else if (e.key === "Enter") {
      e.preventDefault();
      e.stopPropagation();
      if (mfaDropdownIndex >= 0 && mfaDropdownIndex < mfaDropdownItems.length) {
        selectMfa(mfaDropdownItems[mfaDropdownIndex]);
      } else if (mfaInputValue.trim()) {
        // Try exact match (case-insensitive)
        const match = availableMfas.find(
          (m) => m.toLowerCase() === mfaInputValue.trim().toLowerCase()
        );
        if (match && !filterMfas.includes(match)) {
          selectMfa(match);
        }
      }
    } else if (e.key === "Backspace" && mfaInputValue === "" && filterMfas.length > 0) {
      removeMfa(filterMfas[filterMfas.length - 1]);
    }
  }
</script>

<Popover.Root bind:open>
  <Popover.Trigger>
    <Tooltip.Root openDelay={0}>
      <Tooltip.Trigger>
        <Button
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
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" onclick={selectAllTypes} disabled={!hasHiddenTypes}>
            All
          </Button>
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" onclick={deselectAllTypes} disabled={allTypesHidden}>
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
              onclick={() => onToggleType(type)}
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
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" onclick={clearPids}>
            Clear
          </Button>
        {/if}
      </div>

      <!-- PID input with dropdown and tags -->
      <div class="relative">
        <div class="flex flex-wrap items-center gap-1 rounded-md border border-input bg-background px-2 py-1.5 min-h-[36px]">
          {#each filterPids as pid (pid)}
            <Badge variant="secondary" class="gap-1 pl-2 pr-1 py-0.5 text-xs font-mono">
              {pid}
              <button
                class="ml-0.5 rounded-sm hover:bg-muted-foreground/20 p-0.5 leading-none"
                onclick={(e) => { e.stopPropagation(); removePid(pid); }}
              >
                ✕
              </button>
            </Badge>
          {/each}
          <input
            bind:value={pidInputValue}
            oninput={onPidInput}
            onkeydown={handlePidKeyDown}
            class="flex-1 min-w-[60px] bg-transparent text-sm outline-none placeholder:text-muted-foreground font-mono"
            placeholder={filterPids.length === 0 ? "Filter by PID…" : "Add PID…"}
          />
        </div>

        <!-- PID Dropdown -->
        {#if open && pidInputValue && pidDropdownItems.length > 0}
          <div class="absolute z-50 mt-1 w-full rounded-md border bg-popover shadow-md max-h-48 overflow-y-auto">
            {#each pidDropdownItems as item, i (item)}
              <button
                class="w-full px-3 py-1.5 text-sm text-left font-mono hover:bg-accent hover:text-accent-foreground {i === pidDropdownIndex ? 'bg-accent text-accent-foreground' : ''}"
                onmousedown={(e) => { e.preventDefault(); selectPid(item); }}
              >
                {item}
              </button>
            {/each}
          </div>
        {/if}
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

      <!-- Separator -->
      <div class="border-t"></div>

      <!-- MFA Section Header -->
      <div class="flex items-center justify-between">
        <span class="text-sm font-medium">MFA</span>
        {#if hasFilterMfas}
          <Button variant="ghost" size="sm" class="h-7 px-2 text-xs" onclick={clearMfas}>
            Clear
          </Button>
        {/if}
      </div>

      <!-- MFA input with dropdown and tags -->
      <div class="relative">
        <div class="flex flex-wrap items-center gap-1 rounded-md border border-input bg-background px-2 py-1.5 min-h-[36px]">
          {#each filterMfas as mfa (mfa)}
            <Badge variant="secondary" class="gap-1 pl-2 pr-1 py-0.5 text-xs font-mono">
              {mfa}
              <button
                class="ml-0.5 rounded-sm hover:bg-muted-foreground/20 p-0.5 leading-none"
                onclick={(e) => { e.stopPropagation(); removeMfa(mfa); }}
              >
                ✕
              </button>
            </Badge>
          {/each}
          <input
            bind:value={mfaInputValue}
            oninput={onMfaInput}
            onkeydown={handleMfaKeyDown}
            class="flex-1 min-w-[60px] bg-transparent text-sm outline-none placeholder:text-muted-foreground font-mono"
            placeholder={filterMfas.length === 0 ? "Filter by MFA…" : "Add MFA…"}
          />
        </div>

        <!-- MFA Dropdown -->
        {#if open && mfaInputValue && mfaDropdownItems.length > 0}
          <div class="absolute z-50 mt-1 w-full rounded-md border bg-popover shadow-md max-h-48 overflow-y-auto">
            {#each mfaDropdownItems as item, i (item)}
              <button
                class="w-full px-3 py-1.5 text-sm text-left font-mono hover:bg-accent hover:text-accent-foreground {i === mfaDropdownIndex ? 'bg-accent text-accent-foreground' : ''}"
                onmousedown={(e) => { e.preventDefault(); selectMfa(item); }}
              >
                {item}
              </button>
            {/each}
          </div>
        {/if}
      </div>

      <!-- MFA Info -->
      {#if hasFilterMfas}
        <div class="text-xs text-muted-foreground">
          Showing only {filterMfaCount} MFA{filterMfaCount > 1 ? "s" : ""}
        </div>
      {:else}
        <div class="text-xs text-muted-foreground">
          No MFA filter — showing all
        </div>
      {/if}
    </div>
  </Popover.Content>
</Popover.Root>
