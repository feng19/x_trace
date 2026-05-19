<script>
  import * as Select from "$lib/components/ui/select/index.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { toast } from "svelte-sonner";
  import { slide, fade } from 'svelte/transition';
  import { Monitor, CircleDot } from "@lucide/svelte/icons";

  let { live, nodeList = [], selectedNode = $bindable("") } = $props();
  let switching = $state(false);

  function onSwitchNode(value) {
    if (!value || value === selectedNode) return;
    switching = true;

    const promise = new Promise((resolve, reject) => {
      live.pushEvent("switch-node", {node: value}, (e) => {
        switching = false;
        if (e.code == 0) {
          selectedNode = value;
          resolve(e.msg);
        } else {
          reject(e.msg);
        }
      });
    });

    toast.promise(promise, {
      loading: "Switching node…",
      success: (message) => message,
      error: (message) => message,
    });
  }
</script>

{#if nodeList.length > 1}
{#key nodeList.join(",")}
<div in:fade={{ duration: 150 }}>
  <Select.Root type="single" value={selectedNode ?? ""} onValueChange={onSwitchNode}>
    <Select.Trigger
      class="w-full h-11 gap-2 px-4 py-2.5 truncate rounded-lg border-border/60 hover:border-border transition-colors"
      aria-label="Select node"
      disabled={switching}
    >
      <div class="flex w-full items-center gap-2.5 truncate">
        <Monitor class="size-4 shrink-0 text-muted-foreground" />
        <span class="truncate text-sm font-medium">{selectedNode}</span>
        <Badge variant="secondary" class="ml-auto shrink-0 tabular-nums text-[10px] px-1.5 h-4">
          {#key nodeList.length}
          <span in:slide>{nodeList.length}</span>
          {/key}
        </Badge>
      </div>
    </Select.Trigger>
    <Select.Content class="min-w-[var(--bits-select-trigger-width)] p-1.5">
      <Select.Group>
        {#each nodeList as node}
        <Select.Item value={node} label={node} class="px-3 py-2">
          <span class="flex items-center gap-2.5">
            <CircleDot class="size-3.5 {node === selectedNode ? 'text-emerald-500' : 'text-muted-foreground/40'}" />
            <span class="truncate">{node}</span>
          </span>
        </Select.Item>
        {/each}
      </Select.Group>
    </Select.Content>
  </Select.Root>
</div>
{/key}
{/if}
