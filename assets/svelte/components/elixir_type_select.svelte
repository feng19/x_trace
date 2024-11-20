<script>
  import * as Select from "$lib/components/ui/select/index.js";

  export let select_types = ["binary", "atom", "integer"];
  export let name;
  export let selected = undefined;
  export let placeholder = "";
  export let required = false;
</script>

<div {...$$restProps}>
  <Select.Root bind:selected>
    <Select.Trigger>
      <Select.Value {placeholder} />
    </Select.Trigger>
    <Select.Content>
      {#each select_types as type}
        <Select.Item value={type}>{type}</Select.Item>
      {/each}
    </Select.Content>
    <Select.Input {name} {required} />
  </Select.Root>
</div>
