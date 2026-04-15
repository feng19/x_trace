<script>
  import { dashboardStore } from "./d_store.js";
  import CopyClipBoard from "$lib/components/copy_clipboard.svelte";
  import { Button, buttonVariants } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import * as Accordion from "$lib/components/ui/accordion/index.js";
  import { Separator } from "$lib/components/ui/select";
  import { Copy, Check, X } from "lucide-svelte/icons";
  import ElixirDataViewer from "../vendor/elixir-data-viewer";

  let copied = false;
  let copyTimeout;
  let accordionValue = ["details"];

  function initViewer(node, content) {
    const viewer = new ElixirDataViewer(node, {defaultFoldLevel: 3, defaultWordWrap: true});
    viewer.setContent(content || "");
    return {
      update(newContent) {
        viewer.setContent(newContent || "");
      },
    };
  }

  const copy = () => {
    const app = new CopyClipBoard({
      target: document.getElementById("clipboard"),
      props: { content: $dashboardStore.log.content.trim() },
    });
    app.$destroy();
    copied = true;
    clearTimeout(copyTimeout);
    copyTimeout = setTimeout(() => { copied = false; }, 2000);
  };
</script>

<div class="grid grid-cols-1">
  <div class="sticky top-0 z-49">
    <div class="px-2 bg-background flex h-[52px] items-center justify-between">
      <Tooltip.Root openDelay={0}>
        <Tooltip.Trigger
          class={buttonVariants({ variant: "ghost", size: "icon" })}
        >
          <Button variant="link" size="icon" on:click={copy}>
            {#if copied}
              <Check class="size-4 text-green-500" />
            {:else}
              <Copy class="size-4" />
            {/if}
          </Button>
          <span class="sr-only">{copied ? "Copied" : "Copy"}</span>
        </Tooltip.Trigger>
        <Tooltip.Content>{copied ? "Copied!" : "Copy"}</Tooltip.Content>
      </Tooltip.Root>

      <Tooltip.Root openDelay={0}>
        <Tooltip.Trigger
          class={buttonVariants({ variant: "ghost", size: "icon" })}
        >
          <Button
            variant="link"
            size="icon"
            on:click={() => dashboardStore.setLog(null)}
          >
            <X class="size-4" />
          </Button>
          <span class="sr-only">Close</span>
        </Tooltip.Trigger>
        <Tooltip.Content>Close</Tooltip.Content>
      </Tooltip.Root>
    </div>
    <Separator />
  </div>

  <div class="px-4 pt-3 pb-1 text-xs grid grid-cols-[auto_1fr] gap-x-3 gap-y-1">
    <span class="font-semibold text-foreground">Time</span>
    <span class="text-muted-foreground">{$dashboardStore.log.time}</span>
    <span class="font-semibold text-foreground">Type</span>
    <span class="text-muted-foreground">{$dashboardStore.log.type}</span>
    <span class="font-semibold text-foreground">PID</span>
    <span class="text-muted-foreground">{$dashboardStore.log.pid}</span>
  </div>

  {#if $dashboardStore.log.details_loading || $dashboardStore.log.details}
  <Separator />

  <Accordion.Root multiple bind:value={accordionValue} class="px-4">
    {#if $dashboardStore.log.details_loading}
      <Accordion.Item value="details">
        <Accordion.Trigger class="text-sm">Details</Accordion.Trigger>
        <Accordion.Content>
          <div class="text-sm text-muted-foreground">Loading details...</div>
        </Accordion.Content>
      </Accordion.Item>
    {:else if $dashboardStore.log.details}
      <Accordion.Item value="details">
        <Accordion.Trigger class="text-sm">Details</Accordion.Trigger>
        <Accordion.Content>
          <div use:initViewer={$dashboardStore.log.details}></div>
        </Accordion.Content>
      </Accordion.Item>
    {/if}
  </Accordion.Root>
  {/if}
</div>
