<script>
  import * as Dialog from "$lib/components/ui/dialog/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import SettingsDisplay from "$lib/components/settings_display.svelte";

  export let open = false;
  export let title = "Details";
  export let tSpecs = [];
  export let max = "";
  export let options = "";
  export let cli = "";
  export let name = "";
  export let savedAt = "";
</script>

<Dialog.Root bind:open>
  <Dialog.Content class="max-w-4xl 2xl:max-w-6xl flex flex-col">
    <Dialog.Header class="flex-shrink-0">
      <Dialog.Title>{title}</Dialog.Title>
      {#if name || savedAt}
        <Dialog.Description>
          {#if name}
            <span class="font-semibold text-blue-700 dark:text-blue-400">{name}</span>
          {/if}
          {#if savedAt}
            <span class="text-muted-foreground ml-2">Saved: {new Date(savedAt).toLocaleString()}</span>
          {/if}
        </Dialog.Description>
      {/if}
    </Dialog.Header>

    <div class="flex-1 max-h-[80vh] 2xl:max-h-[85vh] overflow-y-auto pr-2">
      <SettingsDisplay {tSpecs} {max} {options} {cli} />
    </div>
  </Dialog.Content>
</Dialog.Root>
