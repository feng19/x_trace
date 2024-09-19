<script>
  import * as ToggleGroup from "$lib/components/ui/toggle-group/index.js";

  export let id;
  export let value;
  export let onValueChange;
  export let items;
</script>

<ToggleGroup.Root type="single" id={id} value={value} {onValueChange}>
  {#each items as item}
  <ToggleGroup.Item value={item.value} disabled={value === item.value}
    class="select-none cursor-pointer disabled:!bg-blue-300 disabled:!opacity-100 disabled:font-bold"
  >
    {item.label}
  </ToggleGroup.Item>
  {/each}
</ToggleGroup.Root>