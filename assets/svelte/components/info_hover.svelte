<script>
  import * as HoverCard from "$lib/components/ui/hover-card";
  import InfoIcon from "@lucide/svelte/icons/info";

  let {
    class: className = undefined,
    children,
  } = $props();
</script>

<HoverCard.Root openDelay={0}>
  <HoverCard.Trigger>
    <InfoIcon class="size-4" />
  </HoverCard.Trigger>
  <HoverCard.Content class={className}>
    {@render children?.()}
  </HoverCard.Content>
</HoverCard.Root>
