<script>
  import * as ToggleGroup from "$lib/components/ui/toggle-group/index.js";

  let {
    id,
    value = $bindable(),
    onValueChange,
    items,
  } = $props();
</script>

<ToggleGroup.Root type="single" id={id} value={value} {onValueChange}>
  {#each items as item}
  <ToggleGroup.Item value={item.value} disabled={value === item.value}
    class="select-none cursor-pointer disabled:bg-blue-500 disabled:text-white dark:disabled:bg-blue-600 dark:disabled:text-white disabled:opacity-100 disabled:font-semibold"
  >
    {item.label}
  </ToggleGroup.Item>
  {/each}
</ToggleGroup.Root>
