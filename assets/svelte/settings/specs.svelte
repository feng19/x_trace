<script>
  import { Button } from "$lib/components/ui/button/index.js";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import { Label } from "$lib/components/ui/label/index.js";
  import LiveCombobox from "$lib/components/live_combobox.svelte";
  import Switch from "$lib/components/switch.svelte";
  import ItemWithX from "$lib/components/item_with_x.svelte";
  import { Plus, X, Import } from "lucide-svelte/icons";
  import { flip } from "svelte/animate";
  import { fade } from "svelte/transition";

  export let live;
  export let t_specs;
  export let app;
  export let module;
  export let fun;
  export let args;
  export let enable;
  export let app_list;
  export let module_list;
  export let module_total = 0;
  export let fun_list;
  export let args_list;

  let args_str;
  $: {
    if (typeof args === "number") {
      args_str = args.toString();
    } else {
      args_str = args;
    }
  }
  $: m_list = [
    { value: "_", label: "All Modules" },
    ...module_list.map((x) => ({ value: x, label: x })),
  ];
  $: f_list = [
    { value: "_", label: "All Functions" },
    ...fun_list.map((x) => ({ value: x, label: x })),
  ];
  $: a_list = [
    { value: "_", label: "All Arguments" },
    ...args_list.map((x) => ({ value: x, label: x })),
  ];

  // Single-level mode: One App / All App / Import
  let mode = app === "all" ? "all" : "_one";
  let mode_items = [
    { value: "_one", label: "One App" },
    { value: "all", label: "All App" },
    { value: "import", label: "Import" },
  ];

  function onModeChange(value) {
    mode = value;
    if (value !== "import") {
      app = value;
    }
  }

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
  <Switch
    id="spec_mode_switch"
    items={mode_items}
    value={mode}
    onValueChange={onModeChange}
  />

  {#if mode === "import"}
    <div class="space-y-2" transition:fade>
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
  {:else}
    <div transition:fade>
      <div class="space-y-2">
        {#if mode === "_one"}
          <div class="grid grid-cols-6 gap-2 items-center" transition:fade>
            <Label for="app-list">App</Label>
            <div class="col-span-5 flex flex-col">
              <LiveCombobox
                {live}
                event_name="app-changed"
                value={app}
                datalist={app_list.map((x) => ({ value: x, label: x }))}
              />
            </div>
          </div>
        {/if}

        <div class="grid grid-cols-6 gap-2 items-center">
          <Label for="module-list">Mod</Label>
          <div class="col-span-5 flex flex-col">
            <LiveCombobox
              {live}
              event_name="module-changed"
              value={module.replace(/^Elixir\./, "")}
              datalist={m_list}
              total_count={module_total}
              try_to_button
              server_search={true}
              search_event="search-modules"
            />
          </div>
        </div>
        <div class="grid grid-cols-6 gap-2 items-center">
          <Label for="fun-list">Fun</Label>
          <div class="col-span-5 flex flex-col">
            <LiveCombobox
              {live}
              event_name="fun-changed"
              value={fun}
              datalist={f_list}
            />
          </div>
        </div>
        <div class="grid grid-cols-6 gap-2 items-center">
          <Label for="args-list">Args</Label>
          <div class="col-span-5 flex flex-col">
            <LiveCombobox
              {live}
              event_name="args-changed"
              value={args_str}
              datalist={a_list}
            />
          </div>
        </div>
        <Button
          class="w-full flex items-center justify-center gap-2"
          disabled={!enable}
          phx-click="add-tspec"
        >
          <Plus class="size-4" /> Add Spec
        </Button>
      </div>
    </div>
  {/if}
</div>
