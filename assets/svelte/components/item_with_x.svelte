<script>
  import XIcon from "@lucide/svelte/icons/x";
  import BracesIcon from "@lucide/svelte/icons/braces";
  import PencilIcon from "@lucide/svelte/icons/pencil";
  import { fade } from "svelte/transition";

  let {
    onClick,
    onRemove,
    active = false,
    editable = false,
    children,
  } = $props();
</script>

<div
  transition:fade
  class="inline-flex justify-between items-center gap-1 rounded border border-dashed px-2 py-1 text-sm {active ? 'border-primary bg-primary/10' : 'border-border bg-background'}"
>
  <button
    onclick={onClick}
    title={editable ? "Click to edit" : undefined}
    class="group inline-flex min-w-0 items-center gap-1.5 text-left {editable ? 'cursor-pointer' : ''}"
  >
    {#if editable}
      <span class="shrink-0 text-muted-foreground transition-colors group-hover:text-primary">
        <BracesIcon class="size-3.5 group-hover:hidden" />
        <PencilIcon class="hidden size-3.5 group-hover:inline" />
      </span>
    {/if}
    <span class="min-w-0 {editable ? 'transition-colors group-hover:text-primary' : ''}">
      {@render children?.()}
    </span>
  </button>
  <button
    class="ml-1 rounded-sm opacity-70 cursor-pointer hover:bg-destructive/90 hover:text-destructive-foreground transition-colors"
    onclick={onRemove}
  >
    <XIcon class="size-4" />
  </button>
</div>
