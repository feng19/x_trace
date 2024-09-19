<script>
  import { onMount } from 'svelte';
  import { dashboardStore } from "./d_store.js";
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import Flash from "./flash.svelte";
  import NodeSwitcher from "./node_switcher.svelte";
  import InfoPanel from "./info_panel.svelte";
  import LogList from "./log_list.svelte";
  import SettingPanel from "./setting_panel.svelte";
  import LogDetail from "./log_detail.svelte";
  import ControlNav from "./control_nav.svelte";
  import SearchBar from "./search_bar.svelte";
  import { cn } from "$lib/utils.js";
  import * as Resizable from "$lib/components/ui/resizable";
  import { Separator } from "$lib/components/ui/select";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { slide } from 'svelte/transition';

  export let live;
  export let node_info;
  export let trace_settings;
  export let rate_limiting;
  export let options_settings;
  export let op_status;
  export let t_spec;
  export let spec_datalist;
  let isCollapsed = false;
  let navCollapsedSize = 4;
  let defaultLayout = [265, 655, 260];
  let setting_panel;

  function onUpdateStore(data) {
    console.log(data)
    dashboardStore.update((obj) => ({ ...obj, ...data }));
  }

  live.handleEvent("update_store", onUpdateStore)

  function onLayoutChange(sizes) {
    // document.cookie = `PaneForge:layout=${JSON.stringify(sizes)}`;
  }

  function onCollapse() { isCollapsed = true; }
  function onExpand() { isCollapsed = false; }

  $: {
    if ($dashboardStore.setting_panel_show) {
      setting_panel && setting_panel.expand();
    } else {
      setting_panel && setting_panel.collapse();
    }
  }

  function onSettingPanelCollapse() { dashboardStore.hideSettingPanel() }
  function onSettingPanelExpand() { dashboardStore.showSettingPanel() }

  onMount(() => {
    settingsLocalStorage.load();
    live.handleEvent("save-settings", (item) => {
      dashboardStore.setSettingTab("local-settings");
      settingsLocalStorage.append(item);
    });

    // after user select file
    document.getElementById("upload-setting-input").addEventListener("change", (event) => {
      let input = event.target;
      if(input.files.length) {
        console.log("import settings files:", input.files)
        dashboardStore.setSettingTab("local-settings");
        settingsLocalStorage.import_file(input.files[0]);
      }
      input.value = "";
    }, true);

    let curr_settings = localStorage.getItem('x-trace-curr-settings');
    if (curr_settings) { live.pushEvent('apply-settings', {encoded: curr_settings, quiet: true}); }
    live.handleEvent("save-curr-settings", ({encoded}) => {
      localStorage.setItem('x-trace-curr-settings', encoded);
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
  <Resizable.Pane
    defaultSize={defaultLayout[0]}
    collapsedSize={navCollapsedSize}
    collapsible
    minSize={15}
    maxSize={20}
    {onCollapse}
    {onExpand}
  >
    <div class={cn("flex h-[52px] items-center justify-center", isCollapsed ? "h-[52px]" : "px-2")}>
      <NodeSwitcher {isCollapsed} {live} nodeList={node_info.node_list} selectedNode={node_info.connected_node} />
    </div>
    <Separator />

    {#if !isCollapsed }
    <InfoPanel {node_info} {trace_settings}/>
    <Separator />
    {/if}

    <div data-collapsed={isCollapsed} class="group flex flex-col gap-4 py-2 data-[collapsed=true]:py-2">
      <div class="grid gap-1 px-2 group-[[data-collapsed=true]]:justify-center group-[[data-collapsed=true]]:px-2">
        <ControlNav {live} {isCollapsed} {op_status} side="right"/>
      </div>
    </div>
  </Resizable.Pane>

  <Resizable.Handle withHandle />

  <!-- center -->
  <Resizable.Pane defaultSize={defaultLayout[1]} minSize={30}>
    <ScrollArea id="logs-container-s" class="h-screen overflow-y-auto overscroll-y-auto grid grid-cols-1">
      <div class="sticky top-0 z-49 bg-white">
        <div class="px-2 h-[52px] flex items-center gap-1">
          <SearchBar {live} />
        </div>
        <Separator />
      </div>
      <LogList {live} />
      <input type="file" id="upload-setting-input" class="hidden" name="upload-setting" accept=".json"/>
      <div id="clipboard"></div>
    </ScrollArea>
  </Resizable.Pane>

  <Resizable.Handle withHandle />

  <!-- right -->
  <Resizable.Pane collapsible={true} bind:pane={setting_panel} onCollapse={onSettingPanelCollapse} onExpand={onSettingPanelExpand}
    defaultSize={defaultLayout[2]} minSize={15} maxSize={45}>
    <ScrollArea class="h-screen overflow-y-auto overscroll-y-auto">
      {#if $dashboardStore.selected }
        <LogDetail />
      {:else}
        <div class="sticky top-0 z-49 bg-white">
          <div class="px-2 h-[52px] flex items-center gap-2">
            <ControlNav {live} {op_status} isCollapsed side="bottom"/>
          </div>
          <Separator />
        </div>
        <SettingPanel {live} {node_info} {t_spec} {trace_settings} {rate_limiting} {options_settings} {spec_datalist} />
      {/if}
    </ScrollArea>
  </Resizable.Pane>
</Resizable.PaneGroup>