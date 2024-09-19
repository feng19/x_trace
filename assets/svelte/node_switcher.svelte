<script>
  import { dashboardStore } from "./d_store.js";
  import { cn } from "$lib/utils.js";
  import * as Select from "$lib/components/ui/select/index.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { toast } from "svelte-sonner";
  import Atom from "lucide-svelte/icons/atom";
  import { slide } from 'svelte/transition';

  export let live;
  export let isCollapsed;
  export let nodeList = [];
  export let selectedNode = null;

  function onSwitchNode(e) {
    let selected = e?.value
    const promise = new Promise((resolve, reject) => {
      live.pushEvent("switch-node", e.value, (e) => {
        if (e.code == 0) {
          selectedNode = selected;
          resolve(e.msg);
        } else {
          reject(e.msg);
        }
      });
    });

    toast.promise(promise, {
      loading: "Loading...",
      success: (message) => {
        return message;
      },
      error: (message) => {
        return message;
      },
    });
  }
</script>

<Select.Root portal={null} selected={selectedNode} onSelectedChange={onSwitchNode} >
  <Select.Trigger
    class={cn(
      "flex items-center gap-2 [&>span]:line-clamp-1 [&>span]:flex [&>span]:w-full [&>span]:items-center [&>span]:gap-1 [&>span]:truncate [&_svg]:h-4 [&_svg]:w-4 [&_svg]:shrink-0",
      isCollapsed &&
        "flex h-10 w-10 shrink-0 items-center justify-center p-0 [&>div>svg]:hidden [&>span]:w-auto"
    )}
    aria-label="Select node"
  >
    <span class="pointer-events-none">
      <div class={cn(isCollapsed ? "!ml-0 !hidden" : "w-full ml-2 flex items-center justify-between")}>
        <span>
          {selectedNode}
        </span>
        <Badge variant="outline">
          {#key nodeList.length}
          <span in:slide>{nodeList.length}</span>
          {/key}
        </Badge>
      </div>
      {#if isCollapsed}
        <Atom class="ml-2 size-6" />
      {/if}
    </span>
  </Select.Trigger>
  <Select.Content sameWidth={!isCollapsed} align={isCollapsed ? "start" : "undefined"}>
    <Select.Group>
      {#each nodeList as node}
      <Select.Item value={node} label={node}>
        {node}
      </Select.Item>
      {/each}
    </Select.Group>
  </Select.Content>
  <Select.Input hidden name="node" />
</Select.Root>
