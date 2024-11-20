<script>
  import { dashboardStore } from "./d_store.js";
  import CopyClipBoard from "$lib/components/copy_clipboard.svelte";
  import { Button, buttonVariants } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { Separator } from "$lib/components/ui/select";
  import { Copy, X } from "lucide-svelte/icons";

  // export let live;
  const copy = () => {
    const app = new CopyClipBoard({
      target: document.getElementById("clipboard"),
      props: { content: $dashboardStore.log.content.trim() },
    });
    app.$destroy();
  };
</script>

<div class="grid grid-cols-1">
  <div class="sticky top-0 z-49">
    <div class="px-2 bg-white flex h-[52px] items-center justify-between">
      <Tooltip.Root openDelay={0}>
        <Tooltip.Trigger
          class={buttonVariants({ variant: "ghost", size: "icon" })}
        >
          <Button variant="link" size="icon" on:click={copy}>
            <Copy class="size-4" />
          </Button>
          <span class="sr-only">Copy</span>
        </Tooltip.Trigger>
        <Tooltip.Content>Copy</Tooltip.Content>
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
  <div class="p-4">
    <p>time: {$dashboardStore.log.time}</p>
    <p>type: {$dashboardStore.log.type}</p>
    <p>pid: {$dashboardStore.log.pid}</p>
    <pre class="text-wrap">{$dashboardStore.log.content}</pre>
  </div>
</div>
