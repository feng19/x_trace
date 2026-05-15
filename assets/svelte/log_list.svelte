<script>
  import { onMount, tick } from "svelte";
  import { toast } from "svelte-sonner";
  import { dashboardStore } from "./d_store.js";
  import { filterStore } from "./filter_store.js";
  import { TYPE_DOT_COLORS, getDotClass } from "./log_type_colors.js";
  import {
    loadLogs as idbLoadLogs,
    saveLogs as idbSaveLogs,
    appendLog as idbAppendLog,
    updateLog as idbUpdateLog,
    clearLogs as idbClearLogs,
  } from "./log_idb_store.js";
  import { cn } from "$lib/utils.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { fade, blur, slide } from "svelte/transition";
  import { Copy, Check, Play, Terminal, Download, Trash2, X, CheckSquare, Square, ListFilter } from "lucide-svelte/icons";
  import { Checkbox } from "$lib/components/ui/checkbox";
  import CopyClipBoard from "$lib/components/copy_clipboard.svelte";
  import ElixirDataViewer from "../vendor/elixir-data-viewer";
  import StringInspectDialog from "$lib/components/string_inspect_dialog.svelte";
  import Welcome from "./welcome.svelte";

  export let live;
  export let node_info = {};
  export let isTracing = false;

  let items = [];

  // Selection mode
  $: selectingMode = $dashboardStore.selecting_mode;
  $: selectedLogTimes = $dashboardStore.selected_log_times;
  $: selectedCount = selectedLogTimes.size;
  $: allVisibleSelected = visibleItems.length > 0 && visibleItems.every(i => selectedLogTimes.has(i.time));

  function toggleSelectItem(e, item) {
    e.stopPropagation();
    dashboardStore.toggleLogSelection(item.time);
  }

  function selectAll() {
    dashboardStore.selectAllLogs(visibleItems.map(i => i.time));
  }

  function deselectAll() {
    dashboardStore.deselectAllLogs();
  }

  function cancelSelecting() {
    dashboardStore.setSelectingMode(false);
  }

  function downloadSelectedLogsAction() {
    const selectedItems = items.filter(i => selectedLogTimes.has(i.time));
    if (selectedItems.length === 0) return;

    const exportItems = selectedItems.map(({ _details, _details_loading, _expanded, ...rest }) => rest);
    const content = JSON.stringify(exportItems, null, 2);
    const file = new Blob([content], { type: "application/json" });
    const link = document.createElement("a");
    const now = new Date();
    const ts = now.getFullYear().toString() +
      String(now.getMonth() + 1).padStart(2, "0") +
      String(now.getDate()).padStart(2, "0") + "_" +
      String(now.getHours()).padStart(2, "0") +
      String(now.getMinutes()).padStart(2, "0") +
      String(now.getSeconds()).padStart(2, "0");
    link.href = URL.createObjectURL(file);
    link.download = `xtrace_selected_${ts}.json`;
    link.click();
    URL.revokeObjectURL(link.href);
    dashboardStore.setSelectingMode(false);
  }

  // Derive available types from items and push to filterStore
  $: allTypes = [...new Set(items.map(i => i.type))].sort();
  $: filterStore.setAvailableTypes(allTypes);

  // Derive available MFAs from items and push to filterStore
  $: allMfas = [...new Set(items.map(i => i.mfa).filter(Boolean))].sort();
  $: filterStore.setAvailableMfas(allMfas);

  // Filter items by hidden types, filter PIDs, and filter MFAs
  $: hiddenTypes = $filterStore.hiddenTypes;
  $: filterPids = $filterStore.filterPids;
  $: filterMfas = $filterStore.filterMfas;
  $: visibleItems = (() => {
    let result = items;
    if (hiddenTypes.length > 0) {
      result = result.filter(i => !hiddenTypes.includes(i.type));
    }
    if (filterPids.length > 0) {
      result = result.filter(i => i.pid && filterPids.includes(i.pid));
    }
    if (filterMfas.length > 0) {
      result = result.filter(i => i.mfa && filterMfas.includes(i.mfa));
    }
    return result;
  })();

  function get_dot_class(type) {
    return getDotClass(type);
  }

  function loadDetailsForItem(item) {
    if (item.trace_info && !item._details && !item._details_loading) {
      item._details_loading = true;
      items = items;
      live.pushEvent("format-details", { type: item.type, trace_info: item.trace_info }, ({ details }) => {
        item._details = details;
        item._details_loading = false;
        items = items;
        idbUpdateLog(item);
      });
    }
  }

  function handleKeyNavigation(e) {
    if (e.key !== "ArrowUp" && e.key !== "ArrowDown") return;
    if (!$dashboardStore.selected) return;

    // Don't interfere when focus is on input elements
    const tag = document.activeElement?.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;

    e.preventDefault();

    const currentIndex = visibleItems.findIndex((item) => item.time === $dashboardStore.selected);
    if (currentIndex === -1) return;

    const nextIndex = e.key === "ArrowUp" ? currentIndex - 1 : currentIndex + 1;
    if (nextIndex < 0 || nextIndex >= visibleItems.length) return;

    const currentItem = visibleItems[currentIndex];
    const nextItem = visibleItems[nextIndex];

    // Collapse current
    if (currentItem._expanded) {
      currentItem._expanded = false;
      dashboardStore.updateExpandedCount(-1);
    }

    // Expand next
    nextItem._expanded = true;
    dashboardStore.updateExpandedCount(1);
    dashboardStore.setLog(nextItem);
    loadDetailsForItem(nextItem);
    items = items;

    // Scroll into view
    tick().then(() => {
      const el = document.querySelector(`[data-log-time="${nextItem.time}"]`);
      if (el) el.scrollIntoView({ behavior: "smooth", block: "nearest" });
    });
  }

  function handleCopyShortcut(e) {
    // Only handle Cmd+C (Mac) or Ctrl+C (non-Mac)
    if (!(e.key === "c" && (e.metaKey || e.ctrlKey))) return;
    if (!$dashboardStore.selected) return;

    // Don't interfere when focus is on input elements
    const tag = document.activeElement?.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;

    // Don't interfere when user has text selected on the page
    const selection = window.getSelection();
    if (selection && selection.toString().length > 0) return;

    const selectedItem = visibleItems.find((item) => item.time === $dashboardStore.selected);
    if (!selectedItem) return;

    e.preventDefault();

    if (selectedItem.type === "call" && selectedItem.trace_info) {
      copyRecallCli(selectedItem);
    } else {
      copyContent(selectedItem.content);
    }
  }

  onMount(async () => {
    // Load persisted logs from IndexedDB
    const stored = await idbLoadLogs();
    if (stored.length > 0) {
      items = stored;
      dashboardStore.setLogCount(items.length);
    }

    let wrapper_s = document.getElementById("logs-container-s");
    let wrapper = document.getElementById("logs-container");

    window.addEventListener("keydown", handleKeyNavigation);
    window.addEventListener("keydown", handleCopyShortcut);
    window.addEventListener("click", closeContextMenu);
    window.addEventListener("keydown", handleContextMenuKeydown);

    live.handleEvent("add-log", (log) => {
      console.log(log);
      // If expand_all is active, auto-expand and load details for the new log (skip io type)
      if ($dashboardStore.expand_all && log.type !== "io") {
        log._expanded = true;
        dashboardStore.updateExpandedCount(1);
        if (log.trace_info) {
          log._details_loading = true;
          live.pushEvent("format-details", { type: log.type, trace_info: log.trace_info }, ({ details }) => {
            log._details = details;
            log._details_loading = false;
            items = items;
            idbUpdateLog(log);
          });
        }
      }
      items = [...items, log];
      dashboardStore.updateLogCount(1);
      idbAppendLog(log, items.length);

      if ($dashboardStore.auto_scroll) {
        tick().then(() => {
          if (wrapper.scrollHeight > wrapper_s.scrollHeight) {
            let item_node = document.getElementById("last-log-container");
            item_node.scrollIntoView({ behavior: "smooth" });
          }
        });
      }
    });

    function onClearLogs() {
      items = [];
      dashboardStore.setLogCount(0);
      dashboardStore.setExpandAll(false);
      idbClearLogs();
    }

    function onExpandAllLogs() {
      dashboardStore.setExpandAll(true);
      let newlyExpanded = 0;
      let expandedTotal = 0;
      items.forEach((item) => {
        if (item.type === "io") return;
        if (!item._expanded) {
          item._expanded = true;
          newlyExpanded++;
        }
        expandedTotal++;
        loadDetailsForItem(item);
      });
      dashboardStore.setExpandedCount(expandedTotal);
      items = items;
    }

    function onCollapseAllLogs() {
      items.forEach((item) => { item._expanded = false; });
      items = items;
      dashboardStore.setExpandAll(false);
    }

    function onDownloadLogs(e) {
      const format = e.detail?.format || "text";
      const link = document.createElement("a");
      const now = new Date();
      const ts = now.getFullYear().toString() +
        String(now.getMonth() + 1).padStart(2, "0") +
        String(now.getDate()).padStart(2, "0") + "_" +
        String(now.getHours()).padStart(2, "0") +
        String(now.getMinutes()).padStart(2, "0") +
        String(now.getSeconds()).padStart(2, "0");

      if (format === "json") {
        const exportItems = items.map(({ _details, _details_loading, _expanded, ...rest }) => rest);
        const content = JSON.stringify(exportItems, null, 2);
        const file = new Blob([content], { type: "application/json" });
        link.href = URL.createObjectURL(file);
        link.download = `xtrace_${ts}.json`;
      } else {
        const content = items.map((log) => log.content).join("\n");
        const file = new Blob([content], { type: "text/plain" });
        link.href = URL.createObjectURL(file);
        link.download = `xtrace_${ts}.log`;
      }

      link.click();
      URL.revokeObjectURL(link.href);
    }

    function onImportLogs(e) {
      const importedItems = e.detail?.items;
      if (!Array.isArray(importedItems)) return;
      const validItems = importedItems.filter(
        (item) => {
          return item &&
          typeof item.time === "number" &&
          typeof item.type === "string" &&
          typeof item.content === "string";
        }
      );
      if (validItems.length === 0) {
        toast.warning("Import failed: no valid log items found in the file.");
        return;
      }

      // Deduplicate by time, then sort chronologically
      const existingTimes = new Set(items.map((i) => i.time));
      const newItems = validItems.filter((i) => !existingTimes.has(i.time));
      items = [...items, ...newItems].sort((a, b) => a.time - b.time);
      dashboardStore.setLogCount(items.length);
      idbSaveLogs(items);
    }

    function onDownloadSelectedLogs() {
      downloadSelectedLogsAction();
    }

    window.addEventListener("x:clear-logs", onClearLogs);
    window.addEventListener("x:expand-all-logs", onExpandAllLogs);
    window.addEventListener("x:collapse-all-logs", onCollapseAllLogs);
    window.addEventListener("x:download-logs", onDownloadLogs);
    window.addEventListener("x:import-logs", onImportLogs);
    window.addEventListener("x:download-selected-logs", onDownloadSelectedLogs);

    return () => {
      window.removeEventListener("keydown", handleKeyNavigation);
      window.removeEventListener("keydown", handleCopyShortcut);
      window.removeEventListener("click", closeContextMenu);
      window.removeEventListener("keydown", handleContextMenuKeydown);
      window.removeEventListener("x:clear-logs", onClearLogs);
      window.removeEventListener("x:expand-all-logs", onExpandAllLogs);
      window.removeEventListener("x:collapse-all-logs", onCollapseAllLogs);
      window.removeEventListener("x:download-logs", onDownloadLogs);
      window.removeEventListener("x:import-logs", onImportLogs);
      window.removeEventListener("x:download-selected-logs", onDownloadSelectedLogs);
    };
  });

  function format_log_time(log) {
    let time = new Date(log.time / 1000000).toLocaleTimeString();
    let ms = String(Math.trunc(log.time / 1000) % 1000).padStart(3, "0");
    return time + "." + ms;
  }

  const PID_COLORS = [
    '#dc2626', // red
    '#16a34a', // green
    '#2563eb', // blue
    '#d97706', // amber
    '#9333ea', // purple
    '#0891b2', // cyan
    '#db2777', // pink
  ];

  function hashString(str) {
    let hash = 0;
    for (let i = 0; i < str.length; i++) {
      hash = ((hash << 5) - hash) + str.charCodeAt(i);
      hash |= 0;
    }
    return Math.abs(hash);
  }

  function pid_color(pid) {
    if (!pid) return 'inherit';
    return PID_COLORS[hashString(pid) % PID_COLORS.length];
  }

  // Context menu state for right-click on PID
  let contextMenu = { show: false, x: 0, y: 0, pid: null };

  function showContextMenu(e, pid) {
    if (!pid || selectingMode) return;
    e.preventDefault();
    e.stopPropagation();
    contextMenu = { show: true, x: e.clientX, y: e.clientY, pid };
  }

  function closeContextMenu() {
    if (contextMenu.show) {
      contextMenu = { ...contextMenu, show: false };
    }
  }

  function filterByPid() {
    if (contextMenu.pid) {
      filterStore.addFilterPid(contextMenu.pid);
    }
    closeContextMenu();
  }

  function handleContextMenuKeydown(e) {
    if (e.key === "Escape" && contextMenu.show) {
      closeContextMenu();
    }
  }

  let pidCopied = {};
  let pidCopyTimeouts = {};
  let pidTooltipOpen = {};

  function copyPid(e, key, pid) {
    e.stopPropagation();
    navigator.clipboard.writeText(pid);
    pidCopied[key] = true;
    pidCopied = pidCopied;
    pidTooltipOpen[key] = true;
    pidTooltipOpen = pidTooltipOpen;
    clearTimeout(pidCopyTimeouts[key]);
    pidCopyTimeouts[key] = setTimeout(() => {
      delete pidCopied[key];
      pidCopied = pidCopied;
      pidTooltipOpen[key] = false;
      pidTooltipOpen = pidTooltipOpen;
    }, 1500);
  }

  let copied = false;
  let copyTimeout;

  let recallCopied = {};
  let recallCopyTimeout = {};

  function copyRecallCli(item) {
    if (!item.trace_info) return;
    live.pushEvent("copy-recall-cli", { trace_info: item.trace_info }, ({ recall_cli }) => {
      const app = new CopyClipBoard({
        target: document.getElementById("clipboard"),
        props: { content: recall_cli.trim() },
      });
      app.$destroy();
      recallCopied[item.time] = true;
      recallCopied = recallCopied;
      clearTimeout(recallCopyTimeout[item.time]);
      recallCopyTimeout[item.time] = setTimeout(() => {
        delete recallCopied[item.time];
        recallCopied = recallCopied;
      }, 2000);
    });
  }

  let viewerIdCounter = 0;
  let stringDialogOpen = false;
  let stringInspectText = "";

  function initViewer(node, content) {
    let currentContent = content;
    const id = `log-list-${++viewerIdCounter}`;
    const foldLevel = filterStore.getFoldLevel();
    const viewer = new ElixirDataViewer(node, {defaultFoldLevel: foldLevel, defaultWordWrap: true});
    viewer.setContent(content || "");
    viewer.onInspect((event) => {
      if (event.type === "String" && event.copyText.length >= 150) {
        event.preventDefault();
        stringInspectText = event.copyText;
        stringDialogOpen = true;
      }
    });
    filterStore.registerViewer(id, viewer);
    return {
      update(newContent) {
        if (newContent === currentContent) return;
        currentContent = newContent;
        viewer.setContent(newContent || "");
        filterStore.refreshViewer(id, viewer);
      },
      destroy() {
        filterStore.unregisterViewer(id);
      },
    };
  }

  function copyContent(content) {
    const app = new CopyClipBoard({
      target: document.getElementById("clipboard"),
      props: { content: content.trim() },
    });
    app.$destroy();
    copied = true;
    clearTimeout(copyTimeout);
    copyTimeout = setTimeout(() => { copied = false; }, 2000);
  }

  function toggleLog(item) {
    if (item._expanded) {
      // Collapse this item
      item._expanded = false;
      dashboardStore.updateExpandedCount(-1);
      if ($dashboardStore.selected === item.time) {
        dashboardStore.setLog(null);
      }
    } else {
      // Expand this item
      item._expanded = true;
      dashboardStore.updateExpandedCount(1);
      dashboardStore.setLog(item);
      loadDetailsForItem(item);
    }
    items = items;
  }

</script>

<div class="grid grid-cols-1 relative z-0">
  {#if selectingMode}
    <div class="sticky top-[53px] z-40 bg-blue-50 dark:bg-blue-950/50 border-b border-blue-200 dark:border-blue-800 px-3 py-2 flex items-center gap-3">
      <span class="text-sm font-medium text-blue-700 dark:text-blue-300">
        {selectedCount} selected
      </span>
      <button
        class="text-xs px-2 py-1 rounded hover:bg-blue-100 dark:hover:bg-blue-900 text-blue-600 dark:text-blue-400"
        on:click={allVisibleSelected ? deselectAll : selectAll}
      >
        {allVisibleSelected ? "Deselect All" : "Select All"}
      </button>
      <div class="flex-1"></div>
      <Button
        variant="outline"
        size="sm"
        class="gap-1.5"
        disabled={selectedCount === 0}
        on:click={downloadSelectedLogsAction}
      >
        <Download class="size-3.5" />
        Download ({selectedCount})
      </Button>
      <Button variant="ghost" size="sm" class="gap-1.5" on:click={cancelSelecting}>
        <X class="size-3.5" />
        Cancel
      </Button>
    </div>
  {/if}
  <div id="logs-container" class="p-1 flex flex-col gap-0 mb-6">
    {#each visibleItems as item (item.time)}
      <div in:fade out:blur data-log-time={item.time}>
        <button
          class={cn(
            "group w-full rounded-md py-1.5 px-2 text-left text-sm transition-all relative",
            selectingMode && selectedLogTimes.has(item.time)
              ? "bg-blue-100 border border-blue-300 dark:bg-blue-950 dark:border-blue-700"
              : !selectingMode && $dashboardStore.selected === item.time
                ? "bg-blue-100 border border-blue-300 dark:bg-blue-950 dark:border-blue-700"
                : "hover:bg-accent"
          )}
          on:click={(e) => selectingMode ? toggleSelectItem(e, item) : toggleLog(item)}
        >
          <div class="flex items-start gap-2">
            {#if selectingMode}
              <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
              <span class="shrink-0 mt-0.5 flex items-center" on:click|stopPropagation>
                <Checkbox
                  checked={selectedLogTimes.has(item.time)}
                  onCheckedChange={() => dashboardStore.toggleLogSelection(item.time)}
                />
              </span>
            {/if}
            <Tooltip.Root openDelay={200}>
              <Tooltip.Trigger asChild let:builder>
                <span
                  use:builder.action
                  {...builder}
                  class="shrink-0 mt-1.5 inline-block size-2.5 rounded-full {get_dot_class(item.type)}"
                ></span>
              </Tooltip.Trigger>
              <Tooltip.Content side="top" class="text-xs px-2 py-1">
                {item.type}
              </Tooltip.Content>
            </Tooltip.Root>
            <div class={cn(
              "text-muted-foreground text-sm",
              selectingMode ? "line-clamp-2" : (item._expanded ? "" : "line-clamp-4")
            )}>
              {format_log_time(item)}{" "}<Tooltip.Root bind:open={pidTooltipOpen[item.time]} openDelay={200}>
                <Tooltip.Trigger asChild let:builder>
                  <span
                    use:builder.action
                    {...builder}
                    role="button"
                    tabindex="-1"
                    class="cursor-pointer font-semibold hover:underline inline-flex items-center"
                    style="color: {pid_color(item.pid)}"
                    on:click={(e) => { if (!selectingMode) copyPid(e, item.time, item.pid); }}
                    on:contextmenu={(e) => showContextMenu(e, item.pid)}
                    on:keydown={(e) => { if (!selectingMode && (e.key === 'Enter' || e.key === ' ')) copyPid(e, item.time, item.pid); }}
                  >{item.pid}</span>
                </Tooltip.Trigger>
                <Tooltip.Content side="top" class="text-xs px-2 py-1">
                  {#if pidCopied[item.time]}
                    <span class="text-green-500">Copied!</span>
                  {:else}
                    Click to copy PID
                  {/if}
                </Tooltip.Content>
              </Tooltip.Root>{" "}{item.content}
            </div>
          </div>
          {#if !selectingMode}
            <div class={cn(
              "absolute right-1 top-1 flex items-center gap-0.5 transition-opacity",
              $dashboardStore.selected === item.time ? "opacity-100" : "opacity-0 group-hover:opacity-100"
            )}>
              {#if item.type === "call" && item.trace_info}
                <Tooltip.Root openDelay={200}>
                  <Tooltip.Trigger asChild let:builder>
                    <Button variant="ghost" size="icon" class="h-7 w-7" builders={[builder]} on:click={(e) => { e.stopPropagation(); copyRecallCli(item); }}>
                      {#if recallCopied[item.time]}
                        <Check class="size-3.5 text-green-500" />
                      {:else}
                        <Terminal class="size-3.5" />
                      {/if}
                    </Button>
                  </Tooltip.Trigger>
                  <Tooltip.Content side="top" class="text-xs px-2 py-1">
                    Copy Recall CLI
                  </Tooltip.Content>
                </Tooltip.Root>
              {/if}
              <Button variant="ghost" size="icon" class="h-7 w-7" on:click={(e) => { e.stopPropagation(); copyContent(item.content); }}>
                {#if copied}
                  <Check class="size-3.5 text-green-500" />
                {:else}
                  <Copy class="size-3.5" />
                {/if}
              </Button>
            </div>
          {/if}
        </button>
        {#if !selectingMode && item._expanded && !(item.type === "io" && !$filterStore.showDetailsTime)}
          <div transition:slide={{ duration: 200 }} class={cn(
            "rounded-b-md px-3 pt-1.5 pb-2 -mt-0.5 ml-2 mr-2",
            $dashboardStore.selected === item.time
              ? "border border-t-0 border-blue-200 bg-blue-50/50 dark:border-blue-800 dark:bg-blue-950/30"
              : "bg-muted/30"
          )}>
            {#if $filterStore.showDetailsTime || ($filterStore.showDetailsPid && item.pid)}
              <div class="text-xs grid grid-cols-[auto_1fr] gap-x-3 gap-y-0.5 mb-1">
                {#if $filterStore.showDetailsTime}
                  <span class="font-semibold text-foreground">Time</span>
                  <span class="text-muted-foreground">{new Date(item.time / 1000000).toLocaleString()}.{Math.trunc(item.time / 1000) % 1000}</span>
                {/if}
                {#if $filterStore.showDetailsPid && item.pid}
                  <span class="font-semibold text-foreground">PID</span>
                  <span class="text-muted-foreground">{item.pid}</span>
                {/if}
              </div>
            {/if}
            {#if item._details_loading}
              <div class="text-sm text-muted-foreground">Loading details...</div>
            {:else if item._details}
              <div use:initViewer={item._details}></div>
            {/if}
          </div>
        {/if}
      </div>
    {/each}
    <div id="last-log-container"></div>

    {#if !isTracing && items.length > 0}
      <div class="flex items-center gap-3 ml-4 p-2" transition:fade>
        <Button
          variant="outline"
          class="gap-2"
          on:click={() => window.dispatchEvent(new CustomEvent("x:download-logs"))}
        >
          <Download class="size-4" />
          Download Logs
        </Button>
        <Button
          variant="outline"
          class="gap-2"
          on:click={() => window.dispatchEvent(new CustomEvent("x:download-logs", { detail: { format: "json" } }))}
        >
          <Download class="size-4" />
          Download JSON
        </Button>
        <Button
          variant="outline"
          class="gap-2 text-red-600 hover:text-red-700 dark:text-red-500 dark:hover:text-red-400"
          on:click={() => window.dispatchEvent(new CustomEvent("x:clear-logs"))}
        >
          <Trash2 class="size-4" />
          Clear Logs
        </Button>
        <Button
          variant="outline"
          class="gap-2 text-green-600 hover:text-green-700 dark:text-green-500 dark:hover:text-green-400"
          on:click={() => live.pushEvent("start-trace", {})}
        >
          <Play class="size-4" />
          Start Trace
        </Button>
      </div>
    {/if}
  </div>

  {#if items.length == 0}
    <Welcome {live} {node_info} />
  {/if}
</div>

<StringInspectDialog bind:open={stringDialogOpen} rawString={stringInspectText} />

{#if contextMenu.show}
  <!-- svelte-ignore a11y-click-events-have-key-events a11y-no-static-element-interactions -->
  <div
    class="fixed z-50 min-w-[160px] rounded-md border bg-popover p-1 shadow-md"
    style="left: {contextMenu.x}px; top: {contextMenu.y}px;"
    on:click|stopPropagation
  >
    <button
      class="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-sm hover:bg-accent hover:text-accent-foreground transition-colors"
      on:click={filterByPid}
    >
      <ListFilter class="size-3.5" />
      Filter by PID <span class="ml-auto text-xs text-muted-foreground font-mono">{contextMenu.pid}</span>
    </button>
  </div>
{/if}

