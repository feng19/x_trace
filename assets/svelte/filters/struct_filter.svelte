<script>
  import { Label } from "$lib/components/ui/label/index.js";
  import Combobox from "$lib/components/combobox.svelte";
  import { Plus, Pencil, X } from "lucide-svelte/icons";
  import { Button } from "$lib/components/ui/button/index.js";
  import ItemWithX from "$lib/components/item_with_x.svelte";

  export let live;
  export let struct_list = [];
  $: module_list = struct_list.map((item) => {
    return { label: item.module, value: "Elixir." + item.module };
  });
  let field_list = [];
  $: {
    if (struct_selected) {
      let fields = struct_list.find(
        (item) => item.module === struct_selected.replace(/^Elixir\./, "")
      ).fields;

      field_list = fields.map((item) => {
        return { label: item, value: item };
      });
    } else {
      field_list = [];
    }
  }

  let struct_selected;
  $: field_enabled = struct_selected && true;
  let field_selected;

  let new_filter = {
    label: "",
    patterns: [],
    limits: [],
  };
  let editing = false;
  $: new_enabled =
    new_filter.label.length > 0 &&
    new_filter.patterns.length > 0 &&
    new_filter.limits.length > 0;

  $: {
    if (struct_selected) {
      new_filter = {
        ...new_filter,
        label: struct_selected.replace(/^Elixir\./, ""),
        patterns: [
          {
            key_type: "atom",
            key: "__struct__",
            value_type: "atom",
            value: struct_selected,
          },
        ],
      };
    }
  }

  function addField() {
    let is_not_existing =
      new_filter.limits.find((item) => item.key === field_selected) ===
      undefined;
    if (is_not_existing) {
      new_filter = {
        ...new_filter,
        limits: [...new_filter.limits, { type: "atom", key: field_selected }],
      };
    }
  }

  function removeField(index) {
    let limits = new_filter.limits;
    limits.splice(index, 1);
    new_filter = {
      ...new_filter,
      limits: limits,
    };
  }

  function addFilter() {
    live.pushEvent("add-map-filter", new_filter);
    new_filter = {
      label: "",
      patterns: [],
      limits: [],
    };
  }
</script>

<div class="space-y-4">
  <div>
    <Label for="struct-selector">Struct</Label>
    <div class="flex flex-col">
      <Combobox
        bind:selected={struct_selected}
        value={""}
        datalist={module_list}
      />
    </div>
  </div>

  <div>
    <Label for="field-selector">Field</Label>
    <div class="flex gap-2">
      <div class="flex-1 flex flex-col">
        <Combobox
          class="w-full flex-1"
          bind:selected={field_selected}
          disabled={!field_enabled}
          value={""}
          datalist={field_list}
        />
      </div>
      <Button disabled={!field_enabled} on:click={addField}>
        <Plus class="size-4" />
      </Button>
    </div>
  </div>

  <div class="inline-flex flex-wrap gap-2">
    {#each new_filter.limits as limit, index (limit.key)}
      <ItemWithX onClick={() => {}} onRemove={() => removeField(index)}>
        :{limit.key}
      </ItemWithX>
    {/each}
    <div class="hidden only:block">
      <p class="text-sm text-gray-500 text-center">No fields added</p>
    </div>
  </div>

  <Button
    class="w-full flex items-center justify-center gap-2"
    disabled={!new_enabled}
    on:click={() => addFilter()}
  >
    {#if !editing}
      <Plus class="size-4" /> Add Filter
    {:else}
      <Pencil class="size-4" /> Edit Filter
    {/if}
  </Button>
</div>
