<script>
  import * as Popover from "$lib/components/ui/popover/index.js";
  import { Plus, Pencil, X } from "lucide-svelte/icons";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Label } from "$lib/components/ui/label/index.js";
  import { Input } from "$lib/components/ui/input/index.js";
  import { Separator } from "$lib/components/ui/select";
  import { flip } from "svelte/animate";
  import { fade } from "svelte/transition";
  import ElixirTypeSelect from "$lib/components/elixir_type_select.svelte";
  import ItemWithX from "$lib/components/item_with_x.svelte";
  import { dashboardStore } from "../d_store.js";

  export let live;

  let new_filter = {
    label: "",
    patterns: [],
    limits: [],
  };
  let editing = false;
  $: {
    if ($dashboardStore.selected_map_filter) {
      new_filter = $dashboardStore.selected_map_filter;
      editing = true;
    } else {
      new_filter = {
        label: "",
        patterns: [],
        limits: [],
      };
      editing = false;
    }
  }
  $: new_enabled =
    new_filter.label.length > 0 &&
    new_filter.patterns.length > 0 &&
    new_filter.limits.length > 0;

  let new_filter_pattern = {
    key: "",
    value: "",
    key_type: { value: "atom", label: "atom" },
    value_type: { value: "atom", label: "atom" },
  };
  $: new_filter_pattern_enabled =
    new_filter_pattern.key.length > 0 && new_filter_pattern.value.length > 0;

  let new_filter_limit = {
    key: "",
    key_type: { value: "atom", label: "atom" },
  };
  $: new_filter_limit_enabled = new_filter_limit.key.length > 0;

  function addPattern() {
    // filter duplicate
    let patterns = new_filter.patterns.filter(
      (p) => p.key !== new_filter_pattern.key
    );
    patterns.push({
      ...new_filter_pattern,
      key_type: new_filter_pattern.key_type.value,
      value_type: new_filter_pattern.value_type.value,
    });
    new_filter = { ...new_filter, patterns: patterns };
    new_filter_pattern = {
      ...new_filter_pattern,
      key: "",
      value: "",
    };
  }

  function addLimit() {
    let limits = new_filter.limits.filter(
      (l) => l.key !== new_filter_limit.key
    );
    limits.push({
      type: new_filter_limit.key_type.value,
      key: new_filter_limit.key,
    });
    new_filter = { ...new_filter, limits: limits };
    new_filter_limit = { ...new_filter_limit, key: "" };
  }

  function removePattern(index) {
    let patterns = new_filter.patterns;
    patterns.splice(index, 1);
    new_filter = { ...new_filter, patterns: patterns };
  }

  function removeLimit(index) {
    let limits = new_filter.limits;
    limits.splice(index, 1);
    new_filter = { ...new_filter, limits: limits };
  }

  function addFilter() {
    live.pushEvent("add-map-filter", new_filter);
    new_filter = {
      label: "",
      patterns: [],
      limits: [],
    };
  }

  function formatValueByType(type, value) {
    switch (type) {
      case "atom":
        return (":" + value).replace(/^:Elixir\./, "");
      default:
        return value;
    }
  }
</script>

<div class="space-y-4">
  <div class="space-y-2">
    <Label for="map_label">Label</Label>
    <Input
      id="map_label"
      name="label"
      bind:value={new_filter.label}
      placeholder="Enter label"
      required
    />
  </div>

  <div>
    <div class="flex justify-between items-center">
      <Label>Patterns</Label>
      <Popover.Root>
        <Popover.Trigger>
          <Button
            variant="ghost"
            size="icon"
            class="flex items-center justify-center gap-2"
          >
            <Plus class="h-4 w-4" />
          </Button>
        </Popover.Trigger>
        <Popover.Content>
          <div class="grid grid-cols-3 gap-2 items-center">
            <Label for="pattern_key_type">Key Type</Label>
            <ElixirTypeSelect
              id="pattern_key_type"
              class="col-span-2"
              name="key_type"
              bind:selected={new_filter_pattern.key_type}
              placeholder="type for key"
              required
            />

            <Label for="pattern_key">Key</Label>
            <Input
              id="pattern_key"
              class="col-span-2"
              name="key"
              bind:value={new_filter_pattern.key}
              placeholder="key"
              required
            />

            <Label for="pattern_value_type">Value Type</Label>
            <ElixirTypeSelect
              id="pattern_value_type"
              class="col-span-2"
              name="value_type"
              bind:selected={new_filter_pattern.value_type}
              placeholder="type for value"
              required
            />

            <Label for="pattern_value">Value</Label>
            <Input
              id="pattern_value"
              class="col-span-2"
              name="value"
              bind:value={new_filter_pattern.value}
              placeholder="value"
              required
            />

            <Button
              disabled={!new_filter_pattern_enabled}
              class="col-span-3 flex items-center justify-center gap-2"
              on:click={() => addPattern()}
            >
              <Plus class="size-4" /> Add
            </Button>
          </div>
        </Popover.Content>
      </Popover.Root>
    </div>

    <div class="space-y-2 flex flex-col">
      {#each new_filter.patterns as pattern, index (pattern.key)}
        <ItemWithX onClick={() => {}} onRemove={() => removePattern(index)}>
          {"{" +
            formatValueByType(pattern.key_type, pattern.key) +
            ", " +
            formatValueByType(pattern.value_type, pattern.value) +
            "}"}
        </ItemWithX>
      {/each}

      {#if new_filter.patterns.length === 0}
        <p class="text-sm text-gray-500 text-center">No patterns added</p>
      {/if}
    </div>
  </div>

  <div>
    <div class="flex justify-between items-center">
      <Label>Limits</Label>
      <Popover.Root>
        <Popover.Trigger>
          <Button
            variant="ghost"
            size="icon"
            class="flex items-center justify-center gap-2"
          >
            <Plus class="h-4 w-4" />
          </Button>
        </Popover.Trigger>
        <Popover.Content>
          <div class="grid grid-cols-3 gap-2 items-center">
            <Label for="limit_key_type">Key Type</Label>
            <ElixirTypeSelect
              id="limit_key_type"
              class="col-span-2"
              name="limit_key_type"
              bind:selected={new_filter_limit.key_type}
              placeholder="type for key"
              required
            />

            <Label for="limit_key">Key</Label>
            <Input
              id="limit_key"
              class="col-span-2"
              name="limit_key"
              bind:value={new_filter_limit.key}
              placeholder="key"
              required
            />

            <Button
              disabled={!new_filter_limit_enabled}
              class="col-span-3 flex items-center justify-center gap-2"
              on:click={() => addLimit()}
            >
              <Plus class="size-4" /> Add
            </Button>
          </div>
        </Popover.Content>
      </Popover.Root>
    </div>

    <div class="inline-flex flex-wrap gap-2">
      {#each new_filter.limits as limit, index (limit.key)}
        <ItemWithX onClick={() => {}} onRemove={() => removeLimit(index)}>
          {formatValueByType(limit.type, limit.key)}
        </ItemWithX>
      {/each}

      {#if new_filter.limits.length === 0}
        <p class="w-full text-sm text-gray-500 text-center">No limits added</p>
      {/if}
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
