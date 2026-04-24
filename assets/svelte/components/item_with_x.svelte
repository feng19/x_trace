<script>
  import { X } from "lucide-svelte/icons";
  import { fade } from "svelte/transition";

  export let onClick;
  export let onRemove;
  export let active = false;
</script>

<div
  transition:fade
  class="inline-flex justify-between items-center gap-1 rounded border border-dashed px-2 py-1 text-sm {active ? 'border-primary bg-primary/10' : 'border-border bg-background'}"
>
  <button on:click={onClick}>
    <slot />
  </button>
  <button
    class="ml-1 rounded-sm opacity-70 cursor-pointer hover:bg-destructive/90 hover:text-destructive-foreground transition-colors"
    on:click={onRemove}
  >
    <X class="size-4" />
  </button>
</div>
