<script>
  import * as HoverCard from "$lib/components/ui/hover-card";
  import Info from "lucide-svelte/icons/info";
</script>

<HoverCard.Root openDelay={0}>
  <HoverCard.Trigger>
    <Info class="size-4" />
  </HoverCard.Trigger>
  <HoverCard.Content>
    <slot />
  </HoverCard.Content>
</HoverCard.Root>