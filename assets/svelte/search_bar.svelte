<script>
  import { dashboardStore } from "./d_store.js";
  import NavBar from "$lib/components/nav_bar.svelte";
  import {
    Eraser,
    Download,
    Filter,
    ArrowRightToLine,
    ArrowLeftFromLine,
  } from "lucide-svelte/icons";
  import { Input } from "$lib/components/ui/input";

  export let live;
  export let filters;

  $: left_items = [
    {
      title: "Filters",
      icon: Filter,
      event: {
        type: "function",
        name: () => {
          dashboardStore.toggleFilterPanel();
          dashboardStore.setRightPanel(null);
        },
      },
      variant: "ghost",
      show: true,
      disabled: false,
      btn_class: filters.count > 0 && "text-blue-600",
    },
  ];

  $: items = [
    {
      title: "Clear All",
      icon: Eraser,
      event: { type: "window", name: "clear-logs" },
      variant: "ghost",
      show: $dashboardStore.log_count !== 0,
      disabled: $dashboardStore.log_count == 0,
    },
    {
      title: "Download logs",
      icon: Download,
      event: { type: "window", name: "download-logs" },
      variant: "ghost",
      show: $dashboardStore.log_count !== 0,
      disabled: $dashboardStore.log_count == 0,
    },
    {
      title: "Hide Setting Panel",
      icon: ArrowRightToLine,
      event: {
        type: "function",
        name: () => dashboardStore.hideSettingPanel(),
      },
      variant: "ghost",
      show: $dashboardStore.right_panel_show,
      disabled: false,
    },
    {
      title: "Show Setting Panel",
      icon: ArrowLeftFromLine,
      event: {
        type: "function",
        name: () => dashboardStore.showSettingPanel(),
      },
      variant: "ghost",
      show: !$dashboardStore.right_panel_show,
      disabled: false,
    },
  ];
</script>

<NavBar {live} items={left_items} />

<div class="flex-1">
  <Input id="searchInput" name="search" />
</div>

<NavBar {live} {items} />
