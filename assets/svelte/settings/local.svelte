<script>
  import { dashboardStore } from "../d_store.js";
  import { settingsLocalStorage } from "../settings_local_storage.js";
  import { onMount } from "svelte";
  import { cn } from "$lib/utils.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { CirclePlay, X, Maximize2 } from "lucide-svelte/icons";
  import { flip } from "svelte/animate";
  import { fade } from "svelte/transition";
  import DetailDialog from "$lib/components/detail_dialog.svelte";
  import SettingsDisplay from "$lib/components/settings_display.svelte";

  export let live;

  let detailDialogOpen = false;
  let detailItem = null;

  function remove(item) {
    console.log("remove id", item.id);
    settingsLocalStorage.remove(item);
    settingsLocalStorage.select(null);
  }

  function apply(item) {
    console.log("apply id:", item.id);
    settingsLocalStorage.select(item.id);
    live.pushEvent("apply-settings", item.encoded);
  }

  function showDetail(item) {
    detailItem = item;
    detailDialogOpen = true;
  }
</script>

<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
  {#each $settingsLocalStorage.items as item (item.id)}
    <div
      animate:flip={{ duration: 250 }}
      transition:fade
      class={cn(
        "relative rounded-lg border bg-card p-3 shadow-sm hover:shadow transition-all flex flex-col max-h-64 overflow-hidden",
        $settingsLocalStorage.selected == item.id
          ? "border-blue-400 dark:border-blue-600 ring-1 ring-blue-200 dark:ring-blue-800"
          : "hover:border-blue-300 dark:hover:border-blue-700"
      )}
    >
      <!-- Action buttons in top-right -->
      <div class="absolute top-1.5 right-1.5 flex items-center gap-0.5">
        <button
          class="rounded-full p-0.5 text-muted-foreground hover:text-foreground hover:bg-muted transition-colors"
          on:click|stopPropagation={() => showDetail(item)}
          title="Expand"
        >
          <Maximize2 class="size-3.5" />
        </button>
        <button
          class="rounded-full p-0.5 text-muted-foreground hover:text-destructive hover:bg-destructive/10 transition-colors"
          on:click|stopPropagation={() => remove(item)}
          title="Remove"
        >
          <X class="size-3.5" />
        </button>
      </div>

      {#if item.name}
        <div class="font-semibold text-sm text-blue-700 dark:text-blue-400 truncate pr-5">{item.name}</div>
      {/if}
      {#if item.saved_at}
        <div class="text-xs text-muted-foreground mt-1">
          Saved: {new Date(item.saved_at).toLocaleString()}
        </div>
      {/if}

      <ScrollArea class="p-2 min-h-0 flex-1">
        <SettingsDisplay
          tSpecs={item.t_specs}
          max={item.max}
          options={item.options}
          compact
        />
      </ScrollArea>

      <Button
        variant="outline"
        size="sm"
        class="w-full mt-3 h-8 text-blue-600 hover:text-blue-700 hover:bg-blue-50 dark:text-blue-400 dark:hover:bg-blue-950 border-blue-200 dark:border-blue-800"
        on:click={() => apply(item)}
      >
        <CirclePlay class="size-3.5 mr-1.5" />
        Apply
      </Button>
    </div>
  {/each}
</div>

{#if $settingsLocalStorage.items.length === 0}
  <div class="text-center text-sm text-muted-foreground py-4">
    No local settings found
  </div>
{/if}

{#if detailItem}
  <DetailDialog
    bind:open={detailDialogOpen}
    title="Saved Settings"
    tSpecs={detailItem.t_specs}
    max={detailItem.max}
    options={detailItem.options}
    name={detailItem.name}
    savedAt={detailItem.saved_at}
  />
{/if}
