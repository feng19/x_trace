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
  import { Separator } from "$lib/components/ui/select";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import {
    PanelLeftClose, PanelLeftOpen, Sun, Moon, Settings,
    Play, SquareX,
  } from "lucide-svelte/icons";

  export let live;
  export let node_info;
  export let trace_settings;
  export let rate_limiting;
  export let options_settings;
  export let op_status;

  let isCollapsed = false;
  let navCollapsedSize = 4;
  let defaultLayout = [25, 75];
  let left_panel;
  let leftPanelHidden = false;

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
  $: showLeftPanel = !isTracing && !leftPanelHidden;

  function toggleLeftPanel() {
    leftPanelHidden = !leftPanelHidden;
  }

  function onUpdateStore(data) {
    console.log(data);
    dashboardStore.update((obj) => ({ ...obj, ...data }));
  }

  live.handleEvent("update_store", onUpdateStore);

  function onLayoutChange(sizes) {
    // document.cookie = `PaneForge:layout=${JSON.stringify(sizes)}`;
  }

  function onCollapse() {
    isCollapsed = true;
  }
  function onExpand() {
    isCollapsed = false;
  }

  onMount(() => {
    // Global keyboard shortcut: Cmd+Shift+K (Mac) / Ctrl+Shift+K (PC) to clear logs
    function onKeyDown(e) {
      if (e.shiftKey && (e.metaKey || e.ctrlKey) && e.key === "K") {
        e.preventDefault();
        window.dispatchEvent(new CustomEvent("x:clear-logs"));
      }
    }
    window.addEventListener("keydown", onKeyDown);

    settingsLocalStorage.load();
    live.handleEvent("save-settings", (item) => {
      dashboardStore.setSettingTab("local-settings");
      settingsLocalStorage.append(item);
    });

    // after user select settings file
    document.getElementById("upload-setting-input").addEventListener(
      "change",
      (event) => {
        let input = event.target;
        if (input.files.length) {
          console.log("import settings files:", input.files);
          dashboardStore.setSettingTab("local-settings");
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
  {onLayoutChange}
  class="h-full flex-1 items-stretch"
>
  <!-- left -->
  {#if showLeftPanel}
    <Resizable.Pane
      defaultSize={defaultLayout[0]}
      collapsedSize={navCollapsedSize}
      collapsible
      minSize={15}
      maxSize={45}
      {onCollapse}
      {onExpand}
      bind:pane={left_panel}
    >
      <ScrollArea class="h-screen overflow-y-auto overscroll-y-auto px-1">
        {#if !isCollapsed}
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
        {/if}
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
          {#if !isTracing}
            <Tooltip.Root openDelay={0}>
              <Tooltip.Trigger asChild let:builder>
                <Button
                  on:click={toggleLeftPanel}
                  builders={[builder]}
                  variant="ghost"
                  size="icon"
                  class="size-9 shrink-0"
                >
                  {#if leftPanelHidden}
                    <PanelLeftOpen class="size-4" aria-hidden="true" />
                  {:else}
                    <PanelLeftClose class="size-4" aria-hidden="true" />
                  {/if}
                  <span class="sr-only">{leftPanelHidden ? 'Show' : 'Hide'} Left Panel</span>
                </Button>
              </Tooltip.Trigger>
              <Tooltip.Content side="bottom" class="flex items-center gap-4">
                {leftPanelHidden ? 'Show' : 'Hide'} Left Panel
              </Tooltip.Content>
            </Tooltip.Root>
          {/if}
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
      {:else}
        <LogList {live} {node_info} />
      {/if}
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
