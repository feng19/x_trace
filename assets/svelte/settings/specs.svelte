<script>
  import { dashboardStore } from "../d_store.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Input } from "$lib/components/ui/input";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import ItemWithX from "$lib/components/item_with_x.svelte";
  import { Braces, Play, RotateCcw, Save } from "lucide-svelte/icons";

  export let live;
  export let t_specs;
  export let op_status;

  // Parse state
  let parseText = "";
  let parsing = false;

  // Save state
  let savePopoverOpen = false;
  let saveName = "";

  $: startEnabled = op_status?.start_trace === true;
  $: resetEnabled = op_status?.reset_settings === true;
  $: resetShow = op_status?.reset_settings !== "hidden";
  $: saveShow = op_status?.save_settings !== "hidden";
  $: saveDisabled = !op_status?.save_settings;

  function removeTSpec(index) {
    live.pushEvent("del-tspec", { index });
  }

  async function handleParse() {
    const raw = parseText.trim();
    if (!raw) return;

    parsing = true;
    try {
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

  function handleSaveKeydown(e) {
    if (e.key === "Enter") {
      doSave();
    }
  }
</script>

<div class="flex flex-col gap-2">
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-2">
    {#each t_specs as t_spec, index (t_spec)}
      <ItemWithX onClick={() => {}} onRemove={() => removeTSpec(index)}>
        {t_spec}
      </ItemWithX>
    {/each}
  </div>

  <div class="flex-1 flex flex-col gap-2 px-0 sm:px-2 min-h-0">
    <textarea
      bind:value={parseText}
      class="w-full flex-1 min-h-[6rem] sm:min-h-[8rem] rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 font-mono resize-y"
      placeholder={`# Examples:\n{Enum, :map, :return_trace}\n[{Enum, :map, :return_trace}, {Enum, :reduce, 3}]\n&Enum.map/2`}
    ></textarea>
    <div class="grid grid-cols-2 gap-2">
      <Button
        class="w-full flex items-center justify-center gap-1.5 sm:gap-2 text-xs sm:text-sm"
        disabled={!parseText.trim() || parsing}
        on:click={handleParse}
      >
        <Braces class="size-3.5 sm:size-4" /> Parse Specs
      </Button>
      <Button
        variant="outline"
        class="w-full flex items-center justify-center gap-1.5 sm:gap-2 text-xs sm:text-sm {startEnabled ? 'text-red-600' : ''}"
        disabled={!startEnabled}
        on:click={() => {
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
          class="w-full flex items-center justify-center gap-1.5 sm:gap-2 text-xs sm:text-sm"
          disabled={!resetEnabled}
          on:click={() => live.pushEvent("reset-settings", {})}
        >
          <RotateCcw class="size-3.5 sm:size-4" /> Reset Settings
        </Button>
      {/if}
      {#if saveShow}
        <Popover.Root bind:open={savePopoverOpen}>
          <Popover.Trigger asChild let:builder>
            <Button
              builders={[builder]}
              variant="outline"
              class="w-full flex items-center justify-center gap-1.5 sm:gap-2 text-xs sm:text-sm"
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
              on:keydown={handleSaveKeydown}
              class="mb-2"
              autofocus
            />
            <div class="flex justify-end gap-2">
              <Button variant="outline" size="sm" on:click={() => { savePopoverOpen = false; saveName = ""; }}>
                Cancel
              </Button>
              <Button size="sm" disabled={!saveName.trim()} on:click={doSave}>
                Save
              </Button>
            </div>
          </Popover.Content>
        </Popover.Root>
      {/if}
    </div>
  </div>
</div>
