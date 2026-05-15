<script>
  import * as HoverCard from "$lib/components/ui/hover-card";
  import Info from "lucide-svelte/icons/info";

  let className = undefined;
  export { className as class };
</script>

<HoverCard.Root openDelay={0}>
  <HoverCard.Trigger>
    <Info class="size-4" />
  </HoverCard.Trigger>
  <HoverCard.Content class={className}>
    <slot />
  </HoverCard.Content>
</HoverCard.Root>