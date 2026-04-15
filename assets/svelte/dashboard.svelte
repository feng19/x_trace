<script>
  import { onMount } from "svelte";
  import { dashboardStore } from "./d_store.js";
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import Flash from "./flash.svelte";
  import InfoPanel from "./info_panel.svelte";
  import SettingPanel from "./setting_panel.svelte";
  import ControlNav from "./control_nav.svelte";
  import SearchBar from "./search_bar.svelte";
  import LogList from "./log_list.svelte";
  import * as Resizable from "$lib/components/ui/resizable";
  import { Separator } from "$lib/components/ui/select";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";

  export let live;
  export let node_info;
  export let trace_settings;
  export let rate_limiting;
  export let options_settings;
  export let op_status;

  let isCollapsed = false;
  let navCollapsedSize = 4;
  let defaultLayout = [35, 65];
  let left_panel;

  $: isTracing = op_status?.stop_trace === true;

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
    settingsLocalStorage.load();
    live.handleEvent("save-settings", (item) => {
      dashboardStore.setSettingTab("local-settings");
      settingsLocalStorage.append(item);
    });

    // after user select file
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
  });
</script>

<Flash {live} />

<Resizable.PaneGroup
  direction="horizontal"
  {onLayoutChange}
  class="h-full flex-1 items-stretch"
>
  <!-- left -->
  {#if !isTracing}
    <Resizable.Pane
      defaultSize={defaultLayout[0]}
      collapsedSize={navCollapsedSize}
      collapsible
      minSize={20}
      maxSize={45}
      {onCollapse}
      {onExpand}
      bind:pane={left_panel}
    >
      <ScrollArea class="h-screen overflow-y-auto overscroll-y-auto">
        <div class="sticky top-0 z-49 bg-white">
          <div class="flex h-[52px] items-center justify-center px-2">
            <div class="flex items-center gap-1">
              <ControlNav {live} isCollapsed {op_status} side="bottom" />
            </div>
          </div>
          <Separator />
        </div>

        {#if !isCollapsed}
          <InfoPanel {node_info} {trace_settings} />
          <Separator />
          <SettingPanel {live} {node_info} {trace_settings} {rate_limiting} {options_settings} />
        {/if}
      </ScrollArea>
    </Resizable.Pane>

    <Resizable.Handle withHandle />
  {/if}

  <!-- center -->
  <Resizable.Pane defaultSize={isTracing ? 100 : defaultLayout[1]} minSize={30}>
    <ScrollArea
      id="logs-container-s"
      class="h-screen overflow-y-auto overscroll-y-auto grid grid-cols-1"
    >
      <div class="sticky top-0 z-49 bg-white">
        <div class="px-2 h-[52px] flex items-center gap-1">
          <SearchBar {live} {isTracing} />
        </div>
        <Separator />
      </div>

      <LogList {live} />
      <input
        type="file"
        id="upload-setting-input"
        class="hidden"
        name="upload-setting"
        accept=".json"
      />
      <div id="clipboard"></div>
    </ScrollArea>
  </Resizable.Pane>
</Resizable.PaneGroup>
