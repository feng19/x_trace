<script>
  import { dashboardStore } from "../d_store.js";
  import { settingsLocalStorage } from "../settings_local_storage.js";
  import { onMount } from "svelte";
  import { cn } from "$lib/utils.js";
  import NavBar from "$lib/components/nav_bar.svelte";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Separator } from "$lib/components/ui/select";
  import { CirclePlay, CircleX } from "lucide-svelte/icons";
  import { flip } from "svelte/animate";
  import { fade } from "svelte/transition";

  export let live;

  function remove(item) {
    console.log("remove id", item.id);
    settingsLocalStorage.remove(item);
    settingsLocalStorage.select(null);
  }

  function apply(item) {
    console.log("apply id:", item.id);
    settingsLocalStorage.select(item.id);
    live.pushEvent("apply-settings", item.encoded);
  }

  let apply_item = {
    title: "Apply this Setting",
    icon: CirclePlay,
    class: "h-full bg-blue-100 flex items-center",
    variant: "link",
    show: true,
    disabled: false,
  };
  let remove_item = {
    title: "Remove this Setting",
    icon: CircleX,
    class: "h-full bg-red-100 flex items-center",
    variant: "link",
    show: true,
    disabled: false,
  };
</script>

<div>
  {#each $settingsLocalStorage.items as item, index (item.id)}
    <div
      id={"ls-" + item.id}
      animate:flip={{ duration: 250 }}
      transition:fade
      class={cn(
        "flex select-none cursor-pointer",
        $settingsLocalStorage.selected == item.id
          ? "bg-red-100 font-bold"
          : "odd:bg-slate-50"
      )}
    >
      <input
        type="checkbox"
        class="hidden"
        id={"ls-c-" + item.id}
        on:click={() => settingsLocalStorage.select(item.id)}
      />
      <label for={"ls-c-" + item.id} class="flex-1 py-1 ml-2">
        <span class="font-bold">TSpecs:</span>
        <pre class="text-wrap">{item.t_specs}</pre>
        <span class="font-bold">Rate-Limiting:</span>
        <pre class="text-wrap">{item.max}</pre>
        <span class="font-bold">Options:</span>
        <pre class="text-wrap">{item.options}</pre>
      </label>

      <div class="grid grid-rows-2 place-items-center">
        <NavBar
          {live}
          side={"left"}
          items={[
            {
              ...apply_item,
              event: { type: "function", name: () => apply(item) },
            },
            {
              ...remove_item,
              event: { type: "function", name: () => remove(item) },
            },
          ]}
        />
      </div>
    </div>
  {/each}
</div>
