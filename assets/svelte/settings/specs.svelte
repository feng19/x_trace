<script>
  import { dashboardStore } from "../d_store.js";
  import { settingsLocalStorage } from "../settings_local_storage.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Input } from "$lib/components/ui/input";
  import { Textarea } from "$lib/components/ui/textarea";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import ItemWithX from "$lib/components/item_with_x.svelte";
  import { Braces, Pencil, Play, RotateCcw, Save, X } from "@lucide/svelte/icons";

  let {
    live,
    t_specs,
    op_status,
  } = $props();

  // Parse state
  let parseText = $state("");
  let parsing = $state(false);
  let editingIndex = $state(null);

  // Save state
  let savePopoverOpen = $state(false);
  let saveName = $state("");

  let startEnabled = $derived(op_status?.start_trace === true);
  let resetEnabled = $derived(op_status?.reset_settings === true);
  let resetShow = $derived(op_status?.reset_settings !== "hidden");
  let saveShow = $derived(op_status?.save_settings !== "hidden");
  let saveDisabled = $derived(!op_status?.save_settings);
  let hasSelectedStorage = $derived($settingsLocalStorage.selected != null);

  function removeTSpec(index) {
    live.pushEvent("del-tspec", { index });
  }

  function selectTSpec(index) {
    parseText = t_specs[index];
    editingIndex = index;
  }

  async function handleParse() {
    const raw = parseText.trim();
    if (!raw) return;

    parsing = true;
    try {
      if (editingIndex != null) {
        await live.pushEvent("del-tspec", { index: editingIndex });
        editingIndex = null;
      }
      const reply = await live.pushEvent("import-tspecs", { raw });
      if (reply?.code === 0) {
        parseText = "";
      }
    } finally {
      parsing = false;
    }
  }

  function doSave() {
    let name = saveName.trim();
    if (name) {
      live.pushEvent("save-settings", { name });
      saveName = "";
      savePopoverOpen = false;
    }
  }

  function doQuickSave() {
    let { selected, items } = $settingsLocalStorage;
    let item = items.find((v) => v.id === selected);
    let name = item?.name || "Untitled";
    live.pushEvent("save-settings", { name });
  }

  function handleSaveKeydown(e) {
    if (e.key === "Enter") {
      doSave();
    }
  }
</script>

<div class="flex flex-col gap-3">
  {#if t_specs.length > 0}
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-2">
      {#each t_specs as t_spec, index (t_spec)}
        <ItemWithX onClick={() => selectTSpec(index)} onRemove={() => removeTSpec(index)} active={editingIndex === index}>
          {t_spec}
        </ItemWithX>
      {/each}
    </div>
  {/if}

  <div class="flex flex-col gap-3 px-0 sm:px-2">
    <Textarea
      bind:value={parseText}
      class="min-h-[6rem] sm:min-h-[8rem] font-mono resize-y {editingIndex != null ? 'border-primary ring-2 ring-primary/30' : ''}"
      placeholder={`# Examples:\n{Enum, :map, :return_trace}\n[{Enum, :map, :return_trace}, {Enum, :reduce, 3}]\n&Enum.map/2 | Enum.map/2 | Enum.map`}
    />

    <div class="grid grid-cols-2 gap-2">
      <div class="flex gap-1">
        <Button
          class="flex-1 flex items-center justify-center gap-1.5 text-xs sm:text-sm"
          disabled={!parseText.trim() || parsing}
          onclick={handleParse}
        >
          {#if editingIndex != null}
            <Pencil class="size-3.5 sm:size-4" /> Update Spec
          {:else}
            <Braces class="size-3.5 sm:size-4" /> Parse Specs
          {/if}
        </Button>
        {#if editingIndex != null}
          <Button
            variant="outline"
            size="icon"
            class="shrink-0"
            onclick={() => { editingIndex = null; parseText = ""; }}
          >
            <X class="size-3.5 sm:size-4" />
          </Button>
        {/if}
      </div>
      <Button
        variant="outline"
        class="w-full flex items-center justify-center gap-1.5 text-xs sm:text-sm {startEnabled ? 'text-red-600 dark:text-red-400' : ''}"
        disabled={!startEnabled}
        onclick={() => {
          dashboardStore.setSettingMode(false);
          live.pushEvent("start-trace", {});
        }}
      >
        <Play class="size-3.5 sm:size-4" /> Start Trace
      </Button>
    </div>

    <div class="grid grid-cols-2 gap-2">
      {#if resetShow}
        <Button
          variant="outline"
          class="w-full flex items-center justify-center gap-1.5 text-xs sm:text-sm"
          disabled={!resetEnabled}
          onclick={() => { settingsLocalStorage.select(null); live.pushEvent("reset-settings", {}); }}
        >
          <RotateCcw class="size-3.5 sm:size-4" /> Reset Settings
        </Button>
      {/if}
      {#if saveShow}
        {#if hasSelectedStorage}
          <Button
            variant="outline"
            class="w-full flex items-center justify-center gap-1.5 text-xs sm:text-sm"
            disabled={saveDisabled}
            onclick={doQuickSave}
          >
            <Save class="size-3.5 sm:size-4" /> Save Settings
          </Button>
        {:else}
          <Popover.Root bind:open={savePopoverOpen}>
            <Popover.Trigger>
              <Button
                variant="outline"
                class="w-full flex items-center justify-center gap-1.5 text-xs sm:text-sm"
                disabled={saveDisabled}
              >
                <Save class="size-3.5 sm:size-4" /> Save Settings
              </Button>
            </Popover.Trigger>
            <Popover.Content class="w-64 p-3" align="start" side="top">
              <p class="text-sm font-medium mb-2">Save Settings</p>
              <Input
                placeholder="Enter a name..."
                bind:value={saveName}
                onkeydown={handleSaveKeydown}
                class="mb-2"
                autofocus
              />
              <div class="flex justify-end gap-2">
                <Button variant="outline" size="sm" onclick={() => { savePopoverOpen = false; saveName = ""; }}>
                  Cancel
                </Button>
                <Button size="sm" disabled={!saveName.trim()} onclick={doSave}>
                  Save
                </Button>
              </div>
            </Popover.Content>
          </Popover.Root>
        {/if}
      {/if}
    </div>
  </div>
</div>
