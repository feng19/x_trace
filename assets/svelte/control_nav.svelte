<script>
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import NavBar from "$lib/components/nav_bar.svelte";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Input } from "$lib/components/ui/input";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import * as Popover from "$lib/components/ui/popover/index.js";
  import {
    Play,
    SquareX,
    RotateCcw,
    Save,
    FileUp,
    FileDown,
  } from "lucide-svelte/icons";
  import { cn } from "$lib/utils.js";

  export let live;
  export let isCollapsed;
  export let side;
  export let op_status;

  let savePopoverOpen = false;
  let saveName = "";

  function doSave() {
    let name = saveName.trim();
    if (name) {
      live.pushEvent("save-settings", { name });
      saveName = "";
      savePopoverOpen = false;
    }
  }

  function handleSaveKeydown(e) {
    if (e.key === "Enter") {
      doSave();
    }
  }

  $: items_before = [
    {
      title: "Start Trace",
      icon: Play,
      event: { type: "phx-click", name: "start-trace" },
      variant: "ghost",
      show: op_status.start_trace !== "hidden",
      disabled: !op_status.start_trace,
      btn_class: op_status.start_trace && "text-red-600",
    },
    {
      title: "Stop Trace",
      icon: SquareX,
      event: { type: "phx-click", name: "stop-trace" },
      variant: "ghost",
      show: op_status.stop_trace !== "hidden",
      disabled: !op_status.stop_trace,
      btn_class: op_status.stop_trace && "text-red-600",
    },
    {
      title: "Reset Settings",
      icon: RotateCcw,
      event: { type: "phx-click", name: "reset-settings" },
      variant: "ghost",
      show: op_status.reset_settings !== "hidden",
      disabled: !op_status.reset_settings,
    },
  ];

  $: items_after = [
    {
      title: "Import Settings",
      icon: FileUp,
      event: {
        type: "function",
        name: () => {
          document.getElementById("upload-setting-input").click();
        },
      },
      variant: "ghost",
      show: op_status.import_settings !== "hidden",
      disabled: false,
    },
    {
      title: "Download Settings",
      icon: FileDown,
      event: {
        type: "function",
        name: () => {
          if (window.__TAURI__) {
            settingsLocalStorage.tauri_download();
          } else {
            settingsLocalStorage.download();
          }
        },
      },
      variant: "ghost",
      show: op_status.download_settings !== "hidden",
      disabled: false,
    },
  ];

  $: saveShow = op_status.save_settings !== "hidden";
  $: saveDisabled = !op_status.save_settings;
</script>

<NavBar {live} items={items_before} {isCollapsed} {side} />

{#if saveShow}
  <Popover.Root bind:open={savePopoverOpen}>
    <Popover.Trigger asChild let:builder>
      {#if isCollapsed}
        <Tooltip.Root openDelay={0}>
          <Tooltip.Trigger asChild let:builder={tooltipBuilder}>
            <Button
              builders={[builder, tooltipBuilder]}
              disabled={saveDisabled}
              variant="ghost"
              size="icon"
              class="size-12"
            >
              <Save class="size-4" aria-hidden="true" />
              <span class="sr-only">Save Settings</span>
            </Button>
          </Tooltip.Trigger>
          <Tooltip.Content {side} class="flex items-center gap-4">
            Save Settings
          </Tooltip.Content>
        </Tooltip.Root>
      {:else}
        <Button
          builders={[builder]}
          disabled={saveDisabled}
          variant="ghost"
          class="justify-start"
        >
          <Save class="mr-2 size-4" aria-hidden="true" />
          Save Settings
        </Button>
      {/if}
    </Popover.Trigger>
    <Popover.Content class="w-64 p-3" align="start" side="right">
      <p class="text-sm font-medium mb-2">Save Settings</p>
      <Input
        placeholder="Enter a name..."
        bind:value={saveName}
        on:keydown={handleSaveKeydown}
        class="mb-2"
        autofocus
      />
      <div class="flex justify-end gap-2">
        <Button variant="outline" size="sm" on:click={() => { savePopoverOpen = false; saveName = ""; }}>
          Cancel
        </Button>
        <Button size="sm" disabled={!saveName.trim()} on:click={doSave}>
          Save
        </Button>
      </div>
    </Popover.Content>
  </Popover.Root>
{/if}

<NavBar {live} items={items_after} {isCollapsed} {side} />
