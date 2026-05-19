<script>
  import XIcon from "@lucide/svelte/icons/x";
  import { fade } from "svelte/transition";

  let {
    onClick,
    onRemove,
    active = false,
    children,
  } = $props();
</script>

<div
  transition:fade
  class="inline-flex justify-between items-center gap-1 rounded border border-dashed px-2 py-1 text-sm {active ? 'border-primary bg-primary/10' : 'border-border bg-background'}"
>
  <button onclick={onClick}>
    {@render children?.()}
  </button>
  <button
    class="ml-1 rounded-sm opacity-70 cursor-pointer hover:bg-destructive/90 hover:text-destructive-foreground transition-colors"
    onclick={onRemove}
  >
    <XIcon class="size-4" />
  </button>
</div>
