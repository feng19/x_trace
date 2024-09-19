<script>
  import { Input } from "$lib/components/ui/input";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Checkbox } from "$lib/components/ui/checkbox/index.js";
  import { Label } from "$lib/components/ui/label/index.js";
  import * as Select from "$lib/components/ui/select";
  import * as HoverCard from "$lib/components/ui/hover-card";
  import AtSign from "lucide-svelte/icons/at-sign";
  import Unplug from "lucide-svelte/icons/unplug";
  import PowerOff from "lucide-svelte/icons/power-off";
  import { blur } from 'svelte/transition';

  // export let live;
  export let node_info;
  let is_long_name = false;
  let node_domain = "127.0.0.1";
  let node_domain_open = false;

  function select_domain(domain) {
    node_domain = domain;
    node_domain_open = false;
  }
</script>

{#if node_info.local_node != "nonode@nohost" }
  <!-- already setup node -->
  <div class="px-2 space-y-4" in:blur={{duration: 200}} >
    <form id="connect-node" phx-submit="connect-node" class="space-y-4">
      <div>
        <Label for="connect_node_input">Node to connect</Label>
        <Input id="connect_node_input" name="connect_node" placeholder="name@domain" required />
      </div>

      <div>
        <Label for="connect_cookie_input">Cookie</Label>
        <Input id="connect_cookie_input" name="connect_cookie" placeholder="if empty will use value of Node.get_cookie()" />
      </div>
    </form>

    <div class="grid grid-cols-2 gap-4">
      <Button form="connect-node" type="submit" disabled={false} class="space-x-2">
        <Unplug class="size-4"/>
        <span>Connect</span>
      </Button>
      <Button phx-click="shutdown-node" type="button" class="space-x-2">
        <PowerOff class="size-4"/>
        <span>Shutdown Node</span>
      </Button>
    </div>
  </div>
{:else}
  <form phx-submit="setup-node" class="px-2 flex flex-col gap-4" in:blur={{duration: 200}} >
    <div class="flex items-center gap-2">
      <div class="flex-1">
        <Input name="node_name" value="x_trace" placeholder="node name" required />
      </div>
      <AtSign class="size-4"/>
      <div class="flex-1">
        <Input name="node_domain" value={node_domain} autocomplete="off" placeholder="domain"
          disabled={ !is_long_name } on:focus={() => node_domain_open = true }/>

        <HoverCard.Root openDelay={0} bind:open={node_domain_open}>
          <HoverCard.Trigger/>
          <HoverCard.Content>
          {#each node_info.domain_list as domain }
            <Button class="w-full" on:click={() => { select_domain(domain) }} variant="ghost"> {domain} </Button>
          {/each}
          </HoverCard.Content>
        </HoverCard.Root>
      </div>
    </div>

    <div class="grid grid-cols-5 place-items-center">
      <Label class="col-span-2" for="is_long_name">Longname?</Label>
      <input type="hidden" name="is_long_name" value={is_long_name} />
      <Checkbox class="col-span-3" id="is_long_name" bind:checked={is_long_name} />
    </div>

    <div class="grid grid-cols-5 place-items-center">
      <Label class="col-span-2" for="cookie_input">Cookie</Label>
      <Input class="col-span-3" id="cookie_input" name="cookie" placeholder="if empty will use value of ~/.erlang.cookie" />
    </div>
    <Button type="submit">Setup Node</Button>
  </form>
{/if}