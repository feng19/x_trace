<script>
  import { onMount, tick, untrack } from "svelte";
  import { toast } from "svelte-sonner";
  import { dashboardStore } from "./d_store.js";
  import { filterStore } from "./filter_store.js";
  import { getDotClass } from "./log_type_colors.js";
  import { downloadFile, timestampSuffix } from "./file_utils.js";
  import {
    loadLogs as idbLoadLogs,
    saveLogs as idbSaveLogs,
    appendLog as idbAppendLog,
    updateLog as idbUpdateLog,
    clearLogs as idbClearLogs,
  } from "./log_idb_store.js";
  import { cn } from "$lib/utils.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { fade, blur, slide } from "svelte/transition";
  import { Copy, Check, Play, Terminal, Download, Trash2, X, ListFilter } from "@lucide/svelte/icons";
  import { Checkbox } from "$lib/components/ui/checkbox";
  import ElixirDataViewer from "../vendor/elixir-data-viewer";
  import StringInspectDialog from "$lib/components/string_inspect_dialog.svelte";
  import Welcome from "./welcome.svelte";

  let { live, node_info = {}, isTracing = false, version = "", trace_settings = {} } = $props();

  let items = $state([]);

  // Pseudo log items rendered as dividers: `separator` is the wavy line marking
  // the boundary between two trace runs, `marker` is the straight green line the
  // user drops in manually while tracing. Neither is a real log: both are
  // excluded from type filters, selection, expansion and the log count.
  const SEPARATOR_TYPE = "separator";
  const MARKER_TYPE = "marker";
  const SEPARATOR_CONTENT = "~".repeat(64);
  const MARKER_CONTENT = "-".repeat(64);

  function isSeparator(item) {
    return item.type === SEPARATOR_TYPE;
  }

  function isMarker(item) {
    return item.type === MARKER_TYPE;
  }

  function isDivider(item) {
    return isSeparator(item) || isMarker(item);
  }

  function countLogs(list) {
    return list.filter((i) => !isDivider(i)).length;
  }

  function appendDivider(type, content) {
    // Times are nanoseconds (System.system_time/0) and are used as the IndexedDB
    // key, so make sure the synthetic one cannot collide with a real log.
    let time = Date.now() * 1000000;
    const taken = new Set(items.map((i) => i.time));
    while (taken.has(time)) time += 1;

    const divider = { time, type, pid: "", content };
    items = [...items, divider];
    idbAppendLog(divider, items.length);
  }

  // Insert a wavy divider whenever a trace run starts while logs from an
  // earlier run are still on screen, so the boundary between runs is visible.
  function insertRunSeparator() {
    if (items.length === 0) return;
    if (isDivider(items[items.length - 1])) return;
    appendDivider(SEPARATOR_TYPE, SEPARATOR_CONTENT);
  }

  // Manual marker (floating button, tracing only). Skipped when the last item is
  // already a marker, since a second one right after it would mark nothing.
  function insertMarker() {
    if (items.length > 0 && isMarker(items[items.length - 1])) return;
    appendDivider(MARKER_TYPE, MARKER_CONTENT);
  }

  // Capture the initial value on purpose: only a false->true transition marks a
  // new run (a reload while tracing must not insert a separator).
  let wasTracing = untrack(() => isTracing);
  $effect(() => {
    const tracing = isTracing;
    untrack(() => {
      if (tracing && !wasTracing) insertRunSeparator();
      wasTracing = tracing;
    });
  });

  // Selection mode
  let selectingMode = $derived($dashboardStore.selecting_mode);
  let selectedLogTimes = $derived($dashboardStore.selected_log_times);
  let selectedCount = $derived(selectedLogTimes.size);

  // Available types / PIDs / MFAs are maintained incrementally so that appending
  // a log updates them without re-scanning and re-sorting the whole list each time.
  // Each append folds the log's option fields into a Set (O(1)); the refresh is
  // coalesced into a single microtask so a burst of appends sorts once, not per item.
  let availableTypes = $state([]);
  let availablePids = $state([]);
  let availableMfas = $state([]);
  const typeSet = new Set();
  const pidSet = new Set();
  const mfaSet = new Set();
  let optionsRefreshScheduled = false;

  function addToOptionSet(set, value) {
    if (value && !set.has(value)) {
      set.add(value);
      return true;
    }
    return false;
  }

  function scheduleOptionsRefresh() {
    if (optionsRefreshScheduled) return;
    optionsRefreshScheduled = true;
    queueMicrotask(() => {
      optionsRefreshScheduled = false;
      availableTypes = [...typeSet].sort();
      availablePids = [...pidSet].sort();
      availableMfas = [...mfaSet].sort();
    });
  }

  function addOptionsForItem(item, schedule = true) {
    let changed = false;
    if (!isDivider(item)) changed = addToOptionSet(typeSet, item.type) || changed;
    changed = addToOptionSet(pidSet, item.pid) || changed;
    changed = addToOptionSet(mfaSet, item.mfa) || changed;
    if (changed && schedule) scheduleOptionsRefresh();
  }

  function resetOptions() {
    typeSet.clear();
    pidSet.clear();
    mfaSet.clear();
    scheduleOptionsRefresh();
  }

  function loadOptionsFromItems(list) {
    typeSet.clear();
    pidSet.clear();
    mfaSet.clear();
    for (const item of list) addOptionsForItem(item, false);
    scheduleOptionsRefresh();
  }

  $effect(() => {
    filterStore.setAvailableTypes(availableTypes);
  });
  $effect(() => {
    filterStore.setAvailablePids(availablePids);
  });
  $effect(() => {
    filterStore.setAvailableMfas(availableMfas);
  });

  // Filter items by hidden types, filter PIDs, and filter MFAs
  let hiddenTypes = $derived($filterStore.hiddenTypes);
  let filterPids = $derived($filterStore.filterPids);
  let filterMfas = $derived($filterStore.filterMfas);
  let visibleItems = $derived((() => {
    let result = items;
    if (hiddenTypes.length > 0) {
      result = result.filter(i => !hiddenTypes.includes(i.type));
    }
    if (filterPids.length > 0) {
      result = result.filter(i => isDivider(i) || (i.pid && filterPids.includes(i.pid)));
    }
    if (filterMfas.length > 0) {
      result = result.filter(i => isDivider(i) || (i.mfa && filterMfas.includes(i.mfa)));
    }
    return result;
  })());

  let selectableItems = $derived(visibleItems.filter(i => !isDivider(i)));
  let allVisibleSelected = $derived(selectableItems.length > 0 && selectableItems.every(i => selectedLogTimes.has(i.time)));

  function toggleSelectItem(e, item) {
    e.stopPropagation();
    dashboardStore.toggleLogSelection(item.time);
  }

  function selectAll() {
    dashboardStore.selectAllLogs(selectableItems.map(i => i.time));
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
    downloadFile(
      `xtrace_selected_${timestampSuffix()}.json`,
      JSON.stringify(exportItems, null, 2)
    );
    dashboardStore.setSelectingMode(false);
  }

  // Details are loaded in batches of up to DETAIL_BATCH_SIZE items: every item
  // queued during one task is flushed in the next microtask as one request per
  // chunk. This turns the N per-item round-trips of expand-all into a handful
  // of requests while keeping each payload bounded.
  const DETAIL_BATCH_SIZE = 50;
  let detailBatch = [];
  let detailBatchScheduled = false;

  function queueLoadDetails(item) {
    if (!item.trace_info || item._details || item._details_loading) return;
    item._details_loading = true;
    detailBatch.push(item);
    if (detailBatchScheduled) return;
    detailBatchScheduled = true;
    queueMicrotask(() => {
      detailBatchScheduled = false;
      const batch = detailBatch;
      detailBatch = [];
      if (batch.length === 0) return;
      for (let i = 0; i < batch.length; i += DETAIL_BATCH_SIZE) {
        const chunk = batch.slice(i, i + DETAIL_BATCH_SIZE);
        live.pushEvent(
          "format-details",
          { items: chunk.map((it) => ({ type: it.type, trace_info: it.trace_info })) },
          ({ results }) => {
            for (let j = 0; j < chunk.length; j++) {
              const item = chunk[j];
              item._details = results?.[j]?.details;
              item._details_loading = false;
              idbUpdateLog(item);
            }
          }
        );
      }
    });
  }

  function loadDetailsForItem(item) {
    queueLoadDetails(item);
  }

  function handleKeyNavigation(e) {
    if (e.key !== "ArrowUp" && e.key !== "ArrowDown") return;
    if (!$dashboardStore.selected) return;

    // Don't interfere when focus is on input elements
    const tag = document.activeElement?.tagName;
    if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") return;

    e.preventDefault();

    // Separators are dividers, not logs: skip over them when navigating
    const navItems = selectableItems;
    const currentIndex = navItems.findIndex((item) => item.time === $dashboardStore.selected);
    if (currentIndex === -1) return;

    const nextIndex = e.key === "ArrowUp" ? currentIndex - 1 : currentIndex + 1;
    if (nextIndex < 0 || nextIndex >= navItems.length) return;

    const currentItem = navItems[currentIndex];
    const nextItem = navItems[nextIndex];

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
      loadOptionsFromItems(stored);
      dashboardStore.setLogCount(countLogs(items));
    }

    let wrapper_s = document.getElementById("logs-container-s");
    let wrapper = document.getElementById("logs-container");

    window.addEventListener("keydown", handleKeyNavigation);
    window.addEventListener("keydown", handleCopyShortcut);
    window.addEventListener("click", closeContextMenu);
    window.addEventListener("keydown", handleContextMenuKeydown);

    live.handleEvent("add-log", (log) => {
      items = [...items, log];
      dashboardStore.updateLogCount(1);
      idbAppendLog(log, items.length);
      addOptionsForItem(log);

      // If expand_all is active, auto-expand and load details for the new log (skip io type).
      // Operate on the proxied item (items[items.length - 1]) so mutations are reactive.
      if ($dashboardStore.expand_all && log.type !== "io") {
        const newItem = items[items.length - 1];
        newItem._expanded = true;
        dashboardStore.updateExpandedCount(1);
        loadDetailsForItem(newItem);
      }

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
      resetOptions();
      dashboardStore.setLogCount(0);
      dashboardStore.setExpandAll(false);
      idbClearLogs();
    }

    function onExpandAllLogs() {
      dashboardStore.setExpandAll(true);
      let expandedTotal = 0;
      items.forEach((item) => {
        if (item.type === "io" || isDivider(item)) return;
        if (!item._expanded) {
          item._expanded = true;
        }
        expandedTotal++;
        loadDetailsForItem(item);
      });
      dashboardStore.setExpandedCount(expandedTotal);
    }

    function onCollapseAllLogs() {
      items.forEach((item) => { item._expanded = false; });
      dashboardStore.setExpandAll(false);
    }

    function onDownloadLogs(e) {
      const format = e.detail?.format || "text";
      const ts = timestampSuffix();

      if (format === "json") {
        const exportItems = items.map(({ _details, _details_loading, _expanded, ...rest }) => rest);
        downloadFile(`xtrace_${ts}.json`, JSON.stringify(exportItems, null, 2));
      } else {
        const content = items.map((log) => log.content).join("\n");
        downloadFile(`xtrace_${ts}.log`, content, "text/plain");
      }
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
      loadOptionsFromItems(items);
      dashboardStore.setLogCount(countLogs(items));
      idbSaveLogs(items);
    }

    function onDownloadSelectedLogs() {
      downloadSelectedLogsAction();
    }

    function onAddMarker() {
      insertMarker();
      // Same follow-the-tail behaviour as an incoming log, so the line the user
      // just dropped is actually in view.
      if ($dashboardStore.auto_scroll) {
        tick().then(() => {
          if (wrapper.scrollHeight > wrapper_s.scrollHeight) {
            document.getElementById("last-log-container").scrollIntoView({ behavior: "smooth" });
          }
        });
      }
    }

    window.addEventListener("x:clear-logs", onClearLogs);
    window.addEventListener("x:add-marker", onAddMarker);
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
      window.removeEventListener("x:add-marker", onAddMarker);
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
  let contextMenu = $state({ show: false, x: 0, y: 0, pid: null });

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

  let pidCopied = $state({});
  let pidCopyTimeouts = {};
  let pidTooltipOpen = $state({});

  function copyPid(e, key, pid) {
    e.stopPropagation();
    navigator.clipboard.writeText(pid);
    pidCopied[key] = true;
    pidTooltipOpen[key] = true;
    clearTimeout(pidCopyTimeouts[key]);
    pidCopyTimeouts[key] = setTimeout(() => {
      delete pidCopied[key];
      pidTooltipOpen[key] = false;
    }, 1500);
  }

  let copied = $state(false);
  let copyTimeout;

  let recallCopied = $state({});
  let recallCopyTimeout = {};

  async function writeClipboard(text) {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(text);
      } else {
        // Fallback for insecure contexts (e.g. http://)
        const ta = document.createElement("textarea");
        ta.value = text;
        ta.setAttribute("readonly", "");
        ta.style.position = "fixed";
        ta.style.top = "0";
        ta.style.left = "0";
        ta.style.opacity = "0";
        document.body.appendChild(ta);
        ta.select();
        const ok = document.execCommand("copy");
        document.body.removeChild(ta);
        if (!ok) throw new Error("execCommand copy failed");
      }
      toast.success("Copied");
      return true;
    } catch (err) {
      console.error("Copy failed", err);
      toast.error("Copy failed");
      return false;
    }
  }

  function copyRecallCli(item) {
    if (!item.trace_info) return;
    live.pushEvent("copy-recall-cli", { trace_info: item.trace_info }, async ({ recall_cli }) => {
      const ok = await writeClipboard(recall_cli.trim());
      if (!ok) return;
      recallCopied[item.time] = true;
      clearTimeout(recallCopyTimeout[item.time]);
      recallCopyTimeout[item.time] = setTimeout(() => {
        delete recallCopied[item.time];
      }, 2000);
    });
  }

  let viewerIdCounter = 0;
  let stringDialogOpen = $state(false);
  let stringInspectText = $state("");

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

  async function copyContent(content) {
    const ok = await writeClipboard(content.trim());
    if (!ok) return;
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
        onclick={allVisibleSelected ? deselectAll : selectAll}
      >
        {allVisibleSelected ? "Deselect All" : "Select All"}
      </button>
      <div class="flex-1"></div>
      <Button
        variant="outline"
        size="sm"
        class="gap-1.5"
        disabled={selectedCount === 0}
        onclick={downloadSelectedLogsAction}
      >
        <Download class="size-3.5" />
        Download ({selectedCount})
      </Button>
      <Button variant="ghost" size="sm" class="gap-1.5" onclick={cancelSelecting}>
        <X class="size-3.5" />
        Cancel
      </Button>
    </div>
  {/if}
  <div id="logs-container" class="p-1 flex flex-col gap-0 mb-6">
    {#each visibleItems as item (item.time)}
      {#if isSeparator(item)}
        <!-- run boundary: logs above belong to a previous trace run -->
        <div in:fade class="px-2 py-2 select-none" aria-hidden="true">
          <svg class="h-2 w-full text-muted-foreground/60">
            <defs>
              <pattern id="run-sep-{item.time}" width="12" height="8" patternUnits="userSpaceOnUse">
                <path d="M0 4 Q3 0.5 6 4 T12 4" fill="none" stroke="currentColor" stroke-width="1.2" />
              </pattern>
            </defs>
            <rect width="100%" height="8" fill="url(#run-sep-{item.time})" />
          </svg>
        </div>
      {:else if isMarker(item)}
        <!-- manual marker dropped by the user while tracing -->
        <div in:fade class="px-2 py-2 select-none" aria-hidden="true">
          <div class="h-0.5 w-full rounded-full bg-green-600/80 dark:bg-green-500/80"></div>
        </div>
      {:else}
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
            onclick={(e) => selectingMode ? toggleSelectItem(e, item) : toggleLog(item)}
          >
            <div class="flex items-start gap-2">
              {#if selectingMode}
                <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
                <span role="presentation" class="shrink-0 mt-0.5 flex items-center" onclick={(e) => e.stopPropagation()}>
                  <Checkbox
                    checked={selectedLogTimes.has(item.time)}
                    onCheckedChange={() => dashboardStore.toggleLogSelection(item.time)}
                  />
                </span>
              {/if}
              <Tooltip.Root openDelay={200}>
                <Tooltip.Trigger>
                  <span
                    class="shrink-0 mt-1.5 inline-block size-2.5 rounded-full {getDotClass(item.type)}"
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
                {format_log_time(item)}{" "}<Tooltip.Root open={pidTooltipOpen[item.time] ?? false} onOpenChange={(v) => { pidTooltipOpen[item.time] = v; }} openDelay={200}>
                  <Tooltip.Trigger>
                    <span
                      role="button"
                      tabindex="-1"
                      class="cursor-pointer font-semibold hover:underline inline-flex items-center"
                      style="color: {pid_color(item.pid)}"
                      onclick={(e) => { if (!selectingMode) copyPid(e, item.time, item.pid); }}
                      oncontextmenu={(e) => showContextMenu(e, item.pid)}
                      onkeydown={(e) => { if (!selectingMode && (e.key === 'Enter' || e.key === ' ')) copyPid(e, item.time, item.pid); }}
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
                    <Tooltip.Trigger>
                      <Button variant="ghost" size="icon" class="h-7 w-7" onclick={(e) => { e.stopPropagation(); copyRecallCli(item); }}>
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
                <Button variant="ghost" size="icon" class="h-7 w-7" onclick={(e) => { e.stopPropagation(); copyContent(item.content); }}>
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
      {/if}
    {/each}
    <div id="last-log-container"></div>

    {#if !isTracing && items.length > 0}
      <div class="flex items-center gap-3 ml-4 p-2" transition:fade>
        <Button
          variant="outline"
          class="gap-2"
          onclick={() => window.dispatchEvent(new CustomEvent("x:download-logs"))}
        >
          <Download class="size-4" />
          Download Logs
        </Button>
        <Button
          variant="outline"
          class="gap-2"
          onclick={() => window.dispatchEvent(new CustomEvent("x:download-logs", { detail: { format: "json" } }))}
        >
          <Download class="size-4" />
          Download JSON
        </Button>
        <Button
          variant="outline"
          class="gap-2 text-red-600 hover:text-red-700 dark:text-red-500 dark:hover:text-red-400"
          onclick={() => window.dispatchEvent(new CustomEvent("x:clear-logs"))}
        >
          <Trash2 class="size-4" />
          Clear Logs
        </Button>
        <Button
          variant="outline"
          class="gap-2 text-green-600 hover:text-green-700 dark:text-green-500 dark:hover:text-green-400"
          onclick={() => live.pushEvent("start-trace", {})}
        >
          <Play class="size-4" />
          Start Trace
        </Button>
      </div>
    {/if}
  </div>

  {#if items.length == 0}
    <Welcome {live} {node_info} {version} {trace_settings} />
  {/if}
</div>

<StringInspectDialog bind:open={stringDialogOpen} rawString={stringInspectText} />

{#if contextMenu.show}
  <!-- svelte-ignore a11y_click_events_have_key_events -->
  <div
    role="menu"
    tabindex="-1"
    class="fixed z-50 min-w-[160px] rounded-md border bg-popover p-1 shadow-md"
    style="left: {contextMenu.x}px; top: {contextMenu.y}px;"
    onclick={(e) => e.stopPropagation()}
  >
    <button
      class="flex w-full items-center gap-2 rounded-sm px-2 py-1.5 text-sm hover:bg-accent hover:text-accent-foreground transition-colors"
      onclick={filterByPid}
    >
      <ListFilter class="size-3.5" />
      Filter by PID <span class="ml-auto text-xs text-muted-foreground font-mono">{contextMenu.pid}</span>
    </button>
  </div>
{/if}
