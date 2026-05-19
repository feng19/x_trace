<script>
  import { Input } from "$lib/components/ui/input";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import { Label } from "$lib/components/ui/label/index.js";
  import * as HoverCard from "$lib/components/ui/hover-card";
  import { AtSign, Unplug, PowerOff } from "@lucide/svelte/icons";
  import { blur } from "svelte/transition";

  let { node_info } = $props();
  let is_long_name = $state(false);
  let node_domain = $state("127.0.0.1");
  let node_domain_open = $state(false);

  function select_domain(domain) {
    node_domain = domain;
    node_domain_open = false;
  }
</script>

{#if node_info.local_node != "nonode@nohost"}
  <!-- Already setup node -->
  <div class="px-1 sm:px-2 space-y-4" in:blur={{ duration: 200 }}>
    <form id="connect-node" phx-submit="connect-node" class="space-y-4">
      <div class="space-y-1.5">
        <Label for="connect_node_input" class="text-xs sm:text-sm">Node to connect</Label>
        <Input
          id="connect_node_input"
          name="connect_node"
          placeholder="name@domain"
          required
        />
      </div>

      <div class="space-y-1.5">
        <Label for="connect_cookie_input" class="text-xs sm:text-sm">Cookie</Label>
        <Input
          id="connect_cookie_input"
          name="connect_cookie"
          placeholder="if empty will use value of Node.get_cookie()"
        />
      </div>
    </form>

    <div class="grid grid-cols-2 gap-3">
      <Button
        form="connect-node"
        type="submit"
        class="flex items-center justify-center gap-2"
      >
        <Unplug class="size-4" />
        <span>Connect</span>
      </Button>
      <Button
        phx-click="shutdown-node"
        type="button"
        variant="outline"
        class="flex items-center justify-center gap-2"
      >
        <PowerOff class="size-4" />
        <span>Shutdown</span>
      </Button>
    </div>
  </div>
{:else}
  <form
    phx-submit="setup-node"
    class="px-1 sm:px-2 space-y-4"
    in:blur={{ duration: 200 }}
  >
    <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
      <div class="flex-1">
        <Input
          name="node_name"
          value="x_trace"
          placeholder="node name"
          required
        />
      </div>
      <AtSign class="size-4 hidden sm:block shrink-0 text-muted-foreground" />
      <div class="flex-1">
        <Input
          name="node_domain"
          value={node_domain}
          autocomplete="off"
          placeholder="domain"
          disabled={!is_long_name}
          onfocus={() => (node_domain_open = true)}
        />

        <HoverCard.Root openDelay={0} bind:open={node_domain_open}>
          <HoverCard.Trigger />
          <HoverCard.Content>
            {#each node_info.domain_list as domain}
              <Button
                class="w-full"
                onclick={() => select_domain(domain)}
                variant="ghost"
              >
                {domain}
              </Button>
            {/each}
          </HoverCard.Content>
        </HoverCard.Root>
      </div>
    </div>

    <div class="flex items-center gap-3">
      <Label for="is_long_name" class="text-xs sm:text-sm shrink-0">Longname?</Label>
      <input type="hidden" name="is_long_name" value={is_long_name} />
      <Checkbox
        id="is_long_name"
        bind:checked={is_long_name}
      />
    </div>

    <div class="space-y-1.5">
      <Label for="cookie_input" class="text-xs sm:text-sm">Cookie</Label>
      <Input
        id="cookie_input"
        name="cookie"
        placeholder="if empty will use ~/.erlang.cookie"
      />
    </div>

    <Button type="submit" class="w-full">Setup Node</Button>
  </form>
{/if}
