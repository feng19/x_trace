<script>
  import { onMount, tick } from "svelte";
  import { dashboardStore } from "./d_store.js";
  import { filterStore } from "./filter_store.js";
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import { TYPE_DOT_COLORS, getDotClass } from "./log_type_colors.js";
  import {
    loadLogs as idbLoadLogs,
    saveLogs as idbSaveLogs,
    appendLog as idbAppendLog,
    updateLog as idbUpdateLog,
    clearLogs as idbClearLogs,
    migrateFromLocalStorage,
  } from "./log_idb_store.js";
  import { cn } from "$lib/utils.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import * as Tooltip from "$lib/components/ui/tooltip/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Separator } from "$lib/components/ui/separator/index.js";
  import { fade, blur, slide } from "svelte/transition";
  import { Gauge, BookOpen, Signature, ExternalLink, CirclePlay, Copy, Check, FileUp, Play, Settings, Terminal, Download, Trash2 } from "lucide-svelte/icons";
  import CopyClipBoard from "$lib/components/copy_clipboard.svelte";
  import ElixirDataViewer from "../vendor/elixir-data-viewer";
  import NodeSwitcher from "./node_switcher.svelte";
  import StringInspectDialog from "$lib/components/string_inspect_dialog.svelte";

  export let live;
  export let node_info = {};
  export let isTracing = false;

  let items = [];

  // Derive available types from items and push to filterStore
  $: allTypes = [...new Set(items.map(i => i.type))].sort();
  $: filterStore.setAvailableTypes(allTypes);

  // Filter items by hidden types and filter PIDs
  $: hiddenTypes = $filterStore.hiddenTypes;
  $: filterPids = $filterStore.filterPids;
  $: visibleItems = (() => {
    let result = items;
    if (hiddenTypes.length > 0) {
      result = result.filter(i => !hiddenTypes.includes(i.type));
    }
    if (filterPids.length > 0) {
      result = result.filter(i => i.pid && filterPids.includes(i.pid));
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
    // Migrate any existing localStorage logs to IndexedDB (one-time)
    await migrateFromLocalStorage();
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
        (item) =>
          item &&
          typeof item.time === "number" &&
          typeof item.type === "string" &&
          typeof item.content === "string"
      );

      if (validItems.length === 0) return;

      // Deduplicate by time, then sort chronologically
      const existingTimes = new Set(items.map((i) => i.time));
      const newItems = validItems.filter((i) => !existingTimes.has(i.time));
      items = [...items, ...newItems].sort((a, b) => a.time - b.time);
      dashboardStore.setLogCount(items.length);
      idbSaveLogs(items);
    }

    window.addEventListener("x:clear-logs", onClearLogs);
    window.addEventListener("x:expand-all-logs", onExpandAllLogs);
    window.addEventListener("x:collapse-all-logs", onCollapseAllLogs);
    window.addEventListener("x:download-logs", onDownloadLogs);
    window.addEventListener("x:import-logs", onImportLogs);

    return () => {
      window.removeEventListener("keydown", handleKeyNavigation);
      window.removeEventListener("keydown", handleCopyShortcut);
      window.removeEventListener("x:clear-logs", onClearLogs);
      window.removeEventListener("x:expand-all-logs", onExpandAllLogs);
      window.removeEventListener("x:collapse-all-logs", onCollapseAllLogs);
      window.removeEventListener("x:download-logs", onDownloadLogs);
      window.removeEventListener("x:import-logs", onImportLogs);
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
      if (event.type === "String") {
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

  function applySettings(item) {
    settingsLocalStorage.select(item.id);
    live.pushEvent("apply-settings", item.encoded);
  }
</script>

<div class="grid grid-cols-1 relative z-0">
  <div id="logs-container" class="p-1 flex flex-col gap-0 mb-6">
    {#each visibleItems as item (item.time)}
      <div in:fade out:blur data-log-time={item.time}>
        <button
          class={cn(
            "group w-full rounded-md py-1.5 px-2 text-left text-sm transition-all relative",
            $dashboardStore.selected === item.time ? "bg-blue-100 border border-blue-300 dark:bg-blue-950 dark:border-blue-700" : "hover:bg-accent"
          )}
          on:click={() => toggleLog(item)}
        >
          <div class="flex items-start gap-2">
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
              item._expanded ? "" : "line-clamp-4"
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
                    on:click={(e) => copyPid(e, item.time, item.pid)}
                    on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') copyPid(e, item.time, item.pid); }}
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
        </button>
        {#if item._expanded && !(item.type === "io" && !$filterStore.showDetailsTime)}
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
          class="gap-2 text-red-600 hover:text-red-700 dark:text-red-500 dark:hover:text-red-400"
          on:click={() => window.dispatchEvent(new CustomEvent("x:clear-logs"))}
        >
          <Trash2 class="size-4" />
          Clear Logs
        </Button>
      </div>
    {/if}
  </div>

  {#if items.length == 0}
    <div class="flex flex-col items-center px-4" in:fade out:blur>
      <!-- Links -->
      <div
        class="mb-6 flex gap-4 items-center text-center text-sm text-muted-foreground"
      >
        <Button
          variant="link"
          class="space-x-2"
          href="/dashboard"
          target="_blank"
        >
          <Gauge class="size-4" />
          <span>Dashboard</span>
        </Button>
        <Button
          variant="link"
          class="space-x-2"
          href="https://hexdocs.pm/recon/recon_trace.html"
          target="_blank"
        >
          <BookOpen class="size-4" />
          <span>Document</span>
        </Button>
        <Button
          variant="link"
          class="space-x-2"
          href="https://github.com/feng19"
          target="_blank"
        >
          <Signature class="size-4" />
          <span>Author: feng19</span>
        </Button>
        <Button
          variant="link"
          class="space-x-2"
          href="https://github.com/feng19/x_trace"
          target="_blank"
        >
          <ExternalLink class="size-4" />
          <span>Github</span>
        </Button>
      </div>

      <!-- Two-column: Description left, Settings right -->
      <div class="flex gap-8 justify-center">
        <!-- Left: Description -->
        <div>
          <pre class="text-sm text-muted-foreground">
  Tracing Elixir and Erlang Code

  The Erlang Trace BIFs allow to trace any Elixir and Erlang code at
  all. They work in two parts: pid specifications, and trace patterns.

  Pid specifications let you decide which processes to target. They
  can be specific pids, `all` pids, `existing` pids, or `new` pids
  (those not spawned at the time of the function call).

  The trace patterns represent functions. Functions can be specified
  in two parts: specifying the modules, functions, and arguments, and
  then with Erlang match specifications to add constraints to
  arguments (see `calls/3` for details).

  What defines whether you get traced or not is the intersection of
  both:

      .       _,--------,_      _,--------,_
           ,-'            `-,,-'            `-,
        ,-'              ,-'  '-,              `-,
       |   Matching    -'        '-   Matching    |
       |     Pids     |  Getting   |    Trace     |
       |              |   Traced   |  Patterns    |
       |               -,        ,-               |
        '-,              '-,  ,-'              ,-'
           '-,_          _,-''-,_          _,-'
               '--------'        '--------'

  If either the pid specification excludes a process or a trace
  pattern excludes a given call, no trace will be received.

  !! Go to [Trace Settings] start & trace. !!
  </pre>
        </div>

        <!-- Right: Actions & Local Storage Settings -->
        <div class="w-72 shrink-0 flex flex-col gap-6">
          <!-- Node Switcher -->
          {#if node_info?.node_list?.length > 1}
            <div>
              <div class="text-sm font-semibold text-muted-foreground mb-3">Switch Node</div>
              <NodeSwitcher {live} nodeList={node_info.node_list} selectedNode={node_info.connected_node} />
            </div>
            <Separator class="my-0" />
          {/if}

          <div class="flex flex-col gap-3">
            <!-- Import JSON Logs -->
            <Button
              variant="outline"
              class="w-full justify-center gap-2"
              on:click={() => document.getElementById("upload-log-input").click()}
            >
              <FileUp class="size-4" />
              Import JSON Logs
            </Button>

            <!-- Import Settings -->
            <Button
              variant="outline"
              class="w-full justify-center gap-2"
              on:click={() => document.getElementById("upload-setting-input").click()}
            >
              <Settings class="size-4" />
              Import Settings
            </Button>
          </div>

          <!-- Saved Settings -->
          {#if $settingsLocalStorage.items.length > 0}
            <div>
              <div class="text-sm font-semibold text-muted-foreground mb-3">Saved Settings</div>
              <div class="flex flex-col gap-3">
                {#each $settingsLocalStorage.items as item (item.id)}
                  <button
                    class={cn(
                      "rounded-xl border px-4 py-3 text-left transition-all shadow-sm active:scale-[0.98]",
                      $settingsLocalStorage.selected === item.id
                        ? "border-blue-400 bg-blue-50 dark:border-blue-600 dark:bg-blue-950/40 ring-1 ring-blue-300 dark:ring-blue-700"
                        : "border-border bg-card hover:bg-accent hover:border-blue-300 dark:hover:border-blue-700"
                    )}
                    on:click={() => applySettings(item)}
                  >
                    <div class="flex items-center gap-3">
                      <CirclePlay class={cn("size-5 shrink-0", $settingsLocalStorage.selected === item.id ? "text-blue-700 dark:text-blue-400" : "text-blue-600")} />
                      <div class="min-w-0 flex-1">
                        <span class="truncate font-medium text-sm block">{item.name || item.t_specs}</span>
                        {#if item.saved_at}
                          <span class="text-xs text-muted-foreground">Saved: {new Date(item.saved_at).toLocaleString()}</span>
                        {/if}
                      </div>
                    </div>
                  </button>
                {/each}
              </div>
            </div>

            <!-- Start Trace -->
            <div>
              <Button
                variant="outline"
                class="w-full justify-center gap-2 text-red-600"
                on:click={() => live.pushEvent("start-trace", {})}
              >
                <Play class="size-4" />
                Start Trace
              </Button>
            </div>
          {/if}
        </div>
      </div>
    </div>
  {/if}
</div>

<StringInspectDialog bind:open={stringDialogOpen} rawString={stringInspectText} />

