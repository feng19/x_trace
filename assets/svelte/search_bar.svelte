<script>
  import { dashboardStore } from "./d_store.js";
  import NavBar from "$lib/components/nav_bar.svelte";
  import Eraser from "lucide-svelte/icons/eraser";
  import Download from "lucide-svelte/icons/download";
  import Filter from "lucide-svelte/icons/filter";
  import ArrowRightToLine from "lucide-svelte/icons/arrow-right-to-line";
  import ArrowLeftFromLine from "lucide-svelte/icons/arrow-left-from-line";
  import { Input } from "$lib/components/ui/input";

  export let live;

  let left_items = [
    {
      title: "Filter",
      icon: Filter,
      event: {type: "function", name: () => { console.log("todo") }},
      variant: "ghost",
      show: true,
      disabled: false
    },
  ];

  $: items = [
    {
      title: "Clear All",
      icon: Eraser,
      event: {type: "window", name: "clear-logs"},
      variant: "ghost",
      show: $dashboardStore.log_count !== 0,
      disabled: $dashboardStore.log_count == 0
    },
    {
      title: "Download logs",
      icon: Download,
      event: {type: "window", name: "download-logs"},
      variant: "ghost",
      show: $dashboardStore.log_count !== 0,
      disabled: $dashboardStore.log_count == 0
    },
    {
      title: "Hide Setting Panel",
      icon: ArrowRightToLine,
      event: {type: "function", name: () => dashboardStore.hideSettingPanel()},
      variant: "ghost",
      show: $dashboardStore.setting_panel_show,
      disabled: false
    },
    {
      title: "Show Setting Panel",
      icon: ArrowLeftFromLine,
      event: {type: "function", name: () => dashboardStore.showSettingPanel()},
      variant: "ghost",
      show: !$dashboardStore.setting_panel_show,
      disabled: false
    },
  ];
</script>

<NavBar {live} items={left_items} />

<div class="flex-1">
  <Input id="searchInput" name="search" />
</div>

<NavBar {live} {items} />