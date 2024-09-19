<script>
 import Check from "lucide-svelte/icons/check";
 import ChevronsUpDown from "lucide-svelte/icons/chevrons-up-down";
 import { tick } from "svelte";
 import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
 import * as Command from "$lib/components/ui/command/index.js";
 import * as Popover from "$lib/components/ui/popover/index.js";
 import { Button } from "$lib/components/ui/button/index.js";
 import { cn } from "$lib/utils.js";

 export let live;
 export let datalist = [];
 export let event_name;
 export let value = "";
 export let try_to_button = false;
 let open = false;

 let inputValue = "";

 $: selectedValue = datalist.find((f) => f.value === value)?.label ?? "Select a item...";

 // We want to refocus the trigger button when the user selects
 // an item from the list so users can continue navigating the
 // rest of the form with the keyboard.
 function closeAndFocusTrigger(triggerId) {
  open = false;
  tick().then(() => {
   document.getElementById(triggerId)?.focus();
  });
 }
</script>

<Popover.Root bind:open let:ids>
 <Popover.Trigger asChild let:builder>
  <Button
   builders={[builder]}
   variant="outline"
   role="combobox"
   aria-expanded={open}
   class="justify-between"
  >
   {selectedValue}
   <ChevronsUpDown class="ml-2 h-4 w-4 shrink-0 opacity-50" />
  </Button>
 </Popover.Trigger>
 <Popover.Content class="p-0">
  <Command.Root loop>
   <Command.Input bind:value={inputValue} placeholder="Search item..." />
   <Command.Empty>
    No item found.
    {#if try_to_button }
    <Button on:click={() => {
     live.pushEvent(event_name, inputValue);
     closeAndFocusTrigger(ids.trigger);
     inputValue = "";
    }}>
     Try to [{inputValue}]
    </Button>
    {/if}
   </Command.Empty>
   <Command.Group>
   {#if datalist.length >= 9 }
    <ScrollArea class="h-72">
    {#each datalist as item}
     <Command.Item
      value={item.value}
      onSelect={(currentValue) => {
       value = currentValue;
       live.pushEvent(event_name, currentValue);
       closeAndFocusTrigger(ids.trigger);
      }}
     >
      <Check class={cn("mr-2 h-4 w-4",value !== item.value && "text-transparent")}/>
      {item.label}
     </Command.Item>
    {/each}
    </ScrollArea>
    {:else}
    {#each datalist as item}
     <Command.Item
      value={item.value}
      onSelect={(currentValue) => {
       value = currentValue;
       live.pushEvent(event_name, currentValue);
       closeAndFocusTrigger(ids.trigger);
      }}
     >
      <Check class={cn("mr-2 h-4 w-4",value !== item.value && "text-transparent")}/>
      {item.label}
     </Command.Item>
    {/each}
    {/if}
   </Command.Group>
  </Command.Root>
 </Popover.Content>
</Popover.Root>