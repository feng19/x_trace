<script>
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import NavBar from "$lib/components/nav_bar.svelte";
  import {
    Play,
    SquareX,
    RotateCcw,
    Save,
    FileUp,
    FileDown,
  } from "lucide-svelte/icons";

  export let live;
  export let isCollapsed;
  export let side;
  export let op_status;
  $: items = [
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
    {
      title: "Save Settings",
      icon: Save,
      event: { type: "phx-click", name: "save-settings" },
      variant: "ghost",
      show: op_status.save_settings !== "hidden",
      disabled: !op_status.save_settings,
    },
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
</script>

<NavBar {live} {items} {isCollapsed} {side} />
