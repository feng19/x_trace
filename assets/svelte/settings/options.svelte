<script>
  import { Input } from "$lib/components/ui/input";
  import { Label } from "$lib/components/ui/label";
  import { Button } from "$lib/components/ui/button/index.js";
  import Switch from "$lib/components/switch.svelte";
  import ItemWithX from "$lib/components/item_with_x.svelte";
  import { Plus, X } from "lucide-svelte/icons";
  import { flip } from "svelte/animate";
  import { fade } from "svelte/transition";

  export let live;
  export let scope;
  export let pid;
  export let add_pid_enable = false;
  export let pids;

  let scope_items = [
    { value: "local", label: "local" },
    { value: "global", label: "global" },
  ];
  let pid_items = [
    { value: "all", label: "all" },
    { value: "new", label: "new" },
    { value: "existing", label: "existing" },
    { value: "pid", label: "pid" },
  ];

  function removePid(index) {
    live.pushEvent("del-pid", { index });
  }
</script>

<div class="px-2 space-y-4">
  <div class="grid grid-cols-3 gap-x-2 gap-y-4 items-center">
    <Label for="options_scope">Fun Scope</Label>
    <div class="col-span-2">
      <Switch
        id="options_scope"
        items={scope_items}
        value={scope}
        onValueChange={(value) => live.pushEvent("set-scope", value)}
      />
    </div>

    <Label for="options_pid">Match Pids</Label>
    <div class="col-span-2">
      <Switch
        id="options_pid"
        items={pid_items}
        value={pid}
        onValueChange={(value) => live.pushEvent("set-pid", value)}
      />
    </div>
  </div>

  {#if pid === "pid" && pids.length != 0}
    <div class="inline-flex flex-wrap gap-2" transition:fade>
      {#each pids as pid_item, index (pid_item)}
        <ItemWithX onClick={() => {}} onRemove={() => removePid(index)}>
          {pid_item}
        </ItemWithX>
      {/each}
    </div>
  {/if}

  {#if pid === "pid"}
    <form
      phx-change="validate-pid"
      phx-submit="add-pid"
      class="grid grid-cols-2 gap-4"
      transition:fade
    >
      <Input name="pid" id="options_pid_input" placeholder="A.B.C" required />
      <Button
        class="w-full flex items-center justify-center gap-2"
        disabled={!add_pid_enable}
        type="submit"
      >
        <Plus class="size-4" /> Add
      </Button>
    </form>
  {/if}
</div>
