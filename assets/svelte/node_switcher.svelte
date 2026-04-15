<script>
  import * as Select from "$lib/components/ui/select/index.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { toast } from "svelte-sonner";
  import { slide } from 'svelte/transition';

  export let live;
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

{#if nodeList.length > 1}
<Select.Root portal={null} selected={selectedNode} onSelectedChange={onSwitchNode} >
  <Select.Trigger
    class="flex items-center gap-2 [&>span]:line-clamp-1 [&>span]:flex [&>span]:w-full [&>span]:items-center [&>span]:gap-1 [&>span]:truncate [&_svg]:h-4 [&_svg]:w-4 [&_svg]:shrink-0"
    aria-label="Select node"
  >
    <span class="pointer-events-none">
      <div class="w-full ml-2 flex items-center justify-between">
        <span>
          {selectedNode}
        </span>
        <Badge variant="outline">
          {#key nodeList.length}
          <span in:slide>{nodeList.length}</span>
          {/key}
        </Badge>
      </div>
    </span>
  </Select.Trigger>
  <Select.Content>
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
{/if}
