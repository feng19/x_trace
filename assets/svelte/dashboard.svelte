<script>
  import { onMount } from "svelte";
  import { dashboardStore } from "./d_store.js";
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import { mode, toggleMode } from "./dark_mode.js";
  import { ModeWatcher } from "mode-watcher";
  import Flash from "./flash.svelte";
  import InfoPanel from "./info_panel.svelte";
  import SettingPanel from "./setting_panel.svelte";
  import SearchBar from "./search_bar.svelte";
  import LogList from "./log_list.svelte";
  import * as Resizable from "$lib/components/ui/resizable";
  import { Separator } from "$lib/components/ui/separator";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import {
    Sun, Moon, Settings,
    Play, SquareX,
  } from "lucide-svelte/icons";

  export let live;
  export let node_info;
  export let trace_settings;
  export let rate_limiting;
  export let options_settings;
  export let op_status;

  let defaultLayout = [25, 75];

  $: startTraceItem = {
    show: op_status.start_trace !== "hidden",
    disabled: !op_status.start_trace,
    btn_class: op_status.start_trace ? "text-red-600" : "",
  };
  $: stopTraceItem = {
    show: op_status.stop_trace !== "hidden",
    disabled: !op_status.stop_trace,
    btn_class: op_status.stop_trace ? "text-red-600" : "",
  };
  $: isTracing = op_status?.stop_trace === true;
  $: if (isTracing) dashboardStore.setSettingMode(false);
  $: showLeftPanel = !isTracing && $dashboardStore.setting_mode;

  function onUpdateStore(data) {
    console.log(data);
    dashboardStore.update((obj) => ({ ...obj, ...data }));
  }

  live.handleEvent("update_store", onUpdateStore);

  onMount(() => {
    // Global keyboard shortcut: Cmd+K (Mac) / Ctrl+K (PC) to clear logs
    function onKeyDown(e) {
      if ((e.metaKey || e.ctrlKey) && e.key === "k") {
        e.preventDefault();
        window.dispatchEvent(new CustomEvent("x:clear-logs"));
      }
      // Ctrl/Cmd+F to focus search input
      if ((e.metaKey || e.ctrlKey) && e.key === "f") {
        e.preventDefault();
        const searchInput = document.getElementById("searchInput");
        if (searchInput) {
          searchInput.focus();
          searchInput.select();
        }
      }
    }
    window.addEventListener("keydown", onKeyDown);

    settingsLocalStorage.load();
    live.handleEvent("save-settings", (item) => {
      // If a local storage item is currently selected (applied), overwrite it
      if (!settingsLocalStorage.updateSelected(item)) {
        settingsLocalStorage.append(item);
      }
    });

    // after user select settings file
    document.getElementById("upload-setting-input").addEventListener(
      "change",
      (event) => {
        let input = event.target;
        if (input.files.length) {
          console.log("import settings files:", input.files);
          settingsLocalStorage.import_file(input.files[0]);
        }
        input.value = "";
      },
      true
    );

    // after user select log file for import
    document.getElementById("upload-log-input").addEventListener(
      "change",
      (event) => {
        let input = event.target;
        if (input.files.length) {
          let reader = new FileReader();
          reader.onload = function () {
            try {
              let importedItems = JSON.parse(this.result);
              dashboardStore.setSettingMode(false); // switch to log view so user sees imported logs
              window.dispatchEvent(
                new CustomEvent("x:import-logs", { detail: { items: importedItems } })
              );
            } catch (e) {
              console.error("Failed to parse imported log file:", e);
            }
          };
          reader.readAsText(input.files[0]);
        }
        input.value = "";
      },
      true
    );

    // load current settings
    if (window.__TAURI__) {
      const { readTextFile, BaseDirectory } = window.__TAURI__.fs;
      readTextFile("curr_settings.json", {
        baseDir: BaseDirectory.AppData,
      }).then((content) => {
        if (content.length > 0) {
          live.pushEvent("apply-settings", { encoded: content, quiet: true });
        }
      });
    } else {
      let curr_settings = localStorage.getItem("x-trace-curr-settings");
      if (curr_settings) {
        live.pushEvent("apply-settings", {
          encoded: curr_settings,
          quiet: true,
        });
      }
    }

    // save current settings
    live.handleEvent("save-curr-settings", ({ encoded }) => {
      if (window.__TAURI__) {
        const { writeTextFile, BaseDirectory } = window.__TAURI__.fs;
        writeTextFile("curr_settings.json", encoded, {
          baseDir: BaseDirectory.AppData,
        });
      } else {
        localStorage.setItem("x-trace-curr-settings", encoded);
      }
    });

    return () => {
      window.removeEventListener("keydown", onKeyDown);
    };
  });
</script>

<ModeWatcher />
<Flash {live} />

<Resizable.PaneGroup
  direction="horizontal"
  class="h-full flex-1 items-stretch"
>
  <!-- left -->
  {#if showLeftPanel}
    <Resizable.Pane
      defaultSize={defaultLayout[0]}
      minSize={15}
      maxSize={45}
    >
      <ScrollArea class="h-screen overflow-y-auto overscroll-y-auto px-1">
        <InfoPanel {live} {node_info} {trace_settings} />

        <div class="p-2 space-y-2">
          {#if startTraceItem.show}
            <Button
              variant="outline"
              class="w-full space-x-2 {startTraceItem.btn_class}"
              disabled={startTraceItem.disabled}
              on:click={() => live.pushEvent("start-trace", {})}
            >
              <Play class="size-4" />
              <span>Start Trace</span>
            </Button>
          {/if}
          {#if stopTraceItem.show}
            <Button
              variant="outline"
              class="w-full space-x-2 {stopTraceItem.btn_class}"
              disabled={stopTraceItem.disabled}
              on:click={() => live.pushEvent("stop-trace", {})}
            >
              <SquareX class="size-4" />
              <span>Stop Trace</span>
            </Button>
          {/if}
        </div>
      </ScrollArea>
    </Resizable.Pane>

    <Resizable.Handle withHandle />
  {/if}

  <!-- center -->
  <Resizable.Pane defaultSize={showLeftPanel ? defaultLayout[1] : 100} minSize={30}>
    <ScrollArea
      id="logs-container-s"
      class="h-screen overflow-y-auto overscroll-y-auto grid grid-cols-1"
    >
      <div class="sticky top-0 z-50 bg-background">
        <div class="px-2 h-[52px] flex items-center gap-1">
          <Tooltip.Root openDelay={0}>
            <Tooltip.Trigger asChild let:builder>
              <Button
                on:click={() => dashboardStore.toggleSettingMode()}
                builders={[builder]}
                variant={$dashboardStore.setting_mode ? "default" : "ghost"}
                size="icon"
                class="size-9 shrink-0"
              >
                <Settings class="size-4" aria-hidden="true" />
                <span class="sr-only">{$dashboardStore.setting_mode ? 'Close Settings' : 'Open Settings'}</span>
              </Button>
            </Tooltip.Trigger>
            <Tooltip.Content side="bottom" class="flex items-center gap-4">
              {$dashboardStore.setting_mode ? 'Close Settings' : 'Open Settings'}
            </Tooltip.Content>
          </Tooltip.Root>
          <SearchBar {live} {isTracing} {op_status} />

          <Tooltip.Root openDelay={0}>
            <Tooltip.Trigger asChild let:builder>
              <Button
                on:click={toggleMode}
                builders={[builder]}
                variant="ghost"
                size="icon"
                class="size-9 shrink-0"
              >
                {#if $mode === "dark"}
                  <Sun class="size-4" aria-hidden="true" />
                {:else}
                  <Moon class="size-4" aria-hidden="true" />
                {/if}
                <span class="sr-only">Toggle Dark Mode</span>
              </Button>
            </Tooltip.Trigger>
            <Tooltip.Content side="bottom" class="flex items-center gap-4">
              {$mode === "dark" ? 'Light Mode' : 'Dark Mode'}
            </Tooltip.Content>
          </Tooltip.Root>
        </div>
        <Separator />
      </div>

      {#if $dashboardStore.setting_mode}
        <SettingPanel {live} {node_info} {trace_settings} {rate_limiting} {options_settings} {op_status} />
      {/if}
      <div class:hidden={$dashboardStore.setting_mode}>
        <LogList {live} {node_info} {isTracing} />
      </div>
      <input
        type="file"
        id="upload-setting-input"
        class="hidden"
        name="upload-setting"
        accept=".json"
      />
      <input
        type="file"
        id="upload-log-input"
        class="hidden"
        name="upload-log"
        accept=".json"
      />
      <div id="clipboard"></div>
    </ScrollArea>
  </Resizable.Pane>
</Resizable.PaneGroup>
