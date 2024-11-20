<script>
  import { Separator } from "$lib/components/ui/select";
  import { Button } from "$lib/components/ui/button";
  import { Badge } from "$lib/components/ui/badge";
  import { Plus, X } from "lucide-svelte/icons";
  import { dashboardStore } from "../d_store.js";
  import { fade } from "svelte/transition";
  import ItemWithX from "$lib/components/item_with_x.svelte";

  export let live;
  export let filters;
  function openRightPanel(type) {
    dashboardStore.setRightPanel(type);
  }

  function selectFilter(type, filter) {
    switch (type) {
      case "map":
        dashboardStore.setSelectedMapFilter(filter);
        break;
      case "record":
        dashboardStore.setSelectedRecordFilter(filter);
        break;
      default:
        break;
    }
  }

  function removeFilter(type, label) {
    switch (type) {
      case "map":
        live.pushEvent("remove-map-filter", { label });
        break;
      case "record":
        live.pushEvent("remove-record-filter", { label });
        break;
      default:
        break;
    }
  }
</script>

<div class="p-4 space-y-6">
  <div class="mb-4 flex gap-4">
    <Button class="gap-2" on:click={() => openRightPanel("struct-filter")}>
      <Plus class="size-4" /> Add Struct Filter
    </Button>

    <Button class="gap-2" on:click={() => openRightPanel("map-filter")}>
      <Plus class="size-4" /> Add Map Filter
    </Button>

    <!-- <Button class="gap-2" on:click={() => openRightPanel("record-filter")}>
      <Plus class="size-4" /> Add Record Filter
    </Button> -->
  </div>

  <div class="space-y-4">
    {#if filters.count > 0}
      <div>
        <h3 class="text-sm font-medium mb-2">Map filters</h3>
        <div class="flex gap-2">
          {#if filters.maps.length > 0}
            {#each filters.maps as filter}
              <ItemWithX
                onClick={() => selectFilter("map", filter)}
                onRemove={() => removeFilter("map", filter.label)}
              >
                {filter.label}
              </ItemWithX>
            {/each}
          {:else}
            <p class="text-sm text-gray-500">No map filters found</p>
          {/if}
        </div>
      </div>

      <!-- <div>
        <h3 class="text-sm font-medium mb-2">Record filters</h3>
        <div class="p-2 gap-2">
          {#if filters.records.length > 0}
            {#each filters.records as filter}
              <ItemWithX
                onClick={() => selectFilter("record", filter)}
                onRemove={() => removeFilter("record", filter.label)}
              >
                {filter.label}
              </ItemWithX>
            {/each}
          {:else}
            <p class="text-sm text-gray-500">No record filters found</p>
          {/if}
        </div>
      </div> -->
    {:else}
      <p class="text-sm text-gray-500 text-center">No filters found</p>
    {/if}
  </div>
</div>
