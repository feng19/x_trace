<script>
  import { Button } from "$lib/components/ui/button/index.js";
  import ItemWithX from "$lib/components/item_with_x.svelte";
  import { Import } from "lucide-svelte/icons";

  export let live;
  export let t_specs;

  // Import state
  let importText = "";
  let importing = false;

  function removeTSpec(index) {
    live.pushEvent("del-tspec", { index });
  }

  async function handleImport() {
    const raw = importText.trim();
    if (!raw) return;

    importing = true;
    try {
      const reply = await live.pushEvent("import-tspecs", { raw });
      if (reply?.code === 0) {
        importText = "";
      }
    } finally {
      importing = false;
    }
  }
</script>

<div class="space-y-2 flex flex-col">
  {#each t_specs as t_spec, index (t_spec)}
    <ItemWithX onClick={() => {}} onRemove={() => removeTSpec(index)}>
      {t_spec}
    </ItemWithX>
  {/each}
</div>

<div class="space-y-2 px-2">
  <textarea
    bind:value={importText}
    class="w-full h-32 rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 font-mono resize-y"
    placeholder={`# Examples:\n{Enum, :map, :return_trace}\n[{Enum, :map, :return_trace}, {Enum, :reduce, 3}]\n&Enum.map/2`}
  ></textarea>
  <Button
    class="w-full flex items-center justify-center gap-2"
    disabled={!importText.trim() || importing}
    on:click={handleImport}
  >
    <Import class="size-4" /> Import Specs
  </Button>
</div>
