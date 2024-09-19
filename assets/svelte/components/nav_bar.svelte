<script>
  import { cn } from "$lib/utils.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { slide } from 'svelte/transition';

  export let live;
  export let isCollapsed = true;
  export let side = "bottom";
  export let items;

  function buttonClick(type, event_name) {
    switch (type) {
      case "phx-click":
        live.pushEvent(event_name, {});
        break;
      case "window":
        window.dispatchEvent(new CustomEvent("x:"+event_name, {}));
        break;
      case "function":
        event_name();
        break;
      default:
        break;
    }
  }
</script>

{#each items as item}
  {#if item.show}
  <div class={cn(isCollapsed ? "" : "w-full grid gap-1", item.class)} transition:slide={{axis: isCollapsed ? "x" : "y", duration: 200}}>
  {#if isCollapsed}
    <Tooltip.Root openDelay={0}>
      <Tooltip.Trigger asChild let:builder>
        <Button
          on:click={() => {buttonClick(item.event.type, item.event.name)}}
          disabled={item.disabled}
          builders={[builder]}
          variant={item.variant}
          size="icon"
          class={cn(
            "size-12", item.btn_class,
            item.variant === "default" &&
              "dark:bg-muted dark:text-muted-foreground dark:hover:bg-muted dark:hover:text-white"
          )}
        >
          <svelte:component this={item.icon} class="size-4" aria-hidden="true" />
          <span class="sr-only">{item.title}</span>
        </Button>
      </Tooltip.Trigger>
      <Tooltip.Content {side} class="flex items-center gap-4">
        {item.title}
      </Tooltip.Content>
    </Tooltip.Root>
  {:else}
    <Button
      on:click={() => {buttonClick(item.event.type, item.event.name)}}
      disabled={item.disabled}
      variant={item.variant}
      class={cn("justify-start", item.btn_class, {
        "dark:bg-muted dark:hover:bg-muted dark:text-white dark:hover:text-white":
          item.variant === "default",
      })}
    >
      <svelte:component this={item.icon} class="mr-2 size-4" aria-hidden="true" />
      {item.title}
    </Button>
  {/if}
  </div>
  {/if}
{/each}