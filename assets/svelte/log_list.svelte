<script>
  import { onMount, tick } from "svelte";
  import { dashboardStore } from "./d_store.js";
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import { cn } from "$lib/utils.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Separator } from "$lib/components/ui/separator/index.js";
  import { fade, blur, slide } from "svelte/transition";
  import { Gauge, BookOpen, Signature, Github, CirclePlay, Copy, Check, FileUp, Play } from "lucide-svelte/icons";
  import CopyClipBoard from "$lib/components/copy_clipboard.svelte";
  import ElixirDataViewer from "../vendor/elixir-data-viewer";
  import NodeSwitcher from "./node_switcher.svelte";

  export let live;
  export let node_info = {};
  let items = [];

  const TYPE_BADGE_CLASSES = {
    call:          "bg-blue-100 text-blue-800 border-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:border-blue-800",
    return_to:     "bg-blue-50 text-blue-600 border-blue-200 dark:bg-blue-950/50 dark:text-blue-400 dark:border-blue-800",
    return_from:   "bg-sky-100 text-sky-800 border-sky-200 dark:bg-sky-950 dark:text-sky-300 dark:border-sky-800",
    exception_from:"bg-red-100 text-red-800 border-red-200 dark:bg-red-950 dark:text-red-300 dark:border-red-800",
    send:          "bg-violet-100 text-violet-800 border-violet-200 dark:bg-violet-950 dark:text-violet-300 dark:border-violet-800",
    send_to_non_existing_process: "bg-violet-50 text-violet-600 border-violet-200 dark:bg-violet-950/50 dark:text-violet-400 dark:border-violet-800",
    receive:       "bg-indigo-100 text-indigo-800 border-indigo-200 dark:bg-indigo-950 dark:text-indigo-300 dark:border-indigo-800",
    spawn:         "bg-green-100 text-green-800 border-green-200 dark:bg-green-950 dark:text-green-300 dark:border-green-800",
    exit:          "bg-rose-100 text-rose-800 border-rose-200 dark:bg-rose-950 dark:text-rose-300 dark:border-rose-800",
    link:          "bg-amber-100 text-amber-800 border-amber-200 dark:bg-amber-950 dark:text-amber-300 dark:border-amber-800",
    unlink:        "bg-amber-50 text-amber-600 border-amber-200 dark:bg-amber-950/50 dark:text-amber-400 dark:border-amber-800",
    getting_linked:   "bg-amber-100 text-amber-700 border-amber-200 dark:bg-amber-950 dark:text-amber-300 dark:border-amber-800",
    getting_unlinked: "bg-amber-50 text-amber-600 border-amber-200 dark:bg-amber-950/50 dark:text-amber-400 dark:border-amber-800",
    register:      "bg-teal-100 text-teal-800 border-teal-200 dark:bg-teal-950 dark:text-teal-300 dark:border-teal-800",
    unregister:    "bg-teal-50 text-teal-600 border-teal-200 dark:bg-teal-950/50 dark:text-teal-400 dark:border-teal-800",
    in:            "bg-gray-100 text-gray-700 border-gray-200 dark:bg-gray-800 dark:text-gray-300 dark:border-gray-700",
    out:           "bg-gray-100 text-gray-600 border-gray-200 dark:bg-gray-800 dark:text-gray-400 dark:border-gray-700",
    gc_start:      "bg-orange-100 text-orange-800 border-orange-200 dark:bg-orange-950 dark:text-orange-300 dark:border-orange-800",
    gc_end:        "bg-orange-50 text-orange-600 border-orange-200 dark:bg-orange-950/50 dark:text-orange-400 dark:border-orange-800",
    cli:           "bg-slate-100 text-slate-700 border-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-700",
  };

  function get_badge_class(type) {
    return TYPE_BADGE_CLASSES[type] || "bg-secondary text-secondary-foreground border-transparent";
  }

  onMount(() => {
    let wrapper_s = document.getElementById("logs-container-s");
    let wrapper = document.getElementById("logs-container");

    live.handleEvent("add-log", (log) => {
      console.log(log);
      items = [...items, log];
      dashboardStore.updateLogCount(1);

      if ($dashboardStore.auto_scroll) {
        tick().then(() => {
          if (wrapper.scrollHeight > wrapper_s.scrollHeight) {
            let item_node = document.getElementById("last-log-container");
            item_node.scrollIntoView({ behavior: "smooth" });
          }
        });
      }
    });

    window.addEventListener("x:print-cli", (e) => {
      let log = {
        time: new Date().getTime() * 1000000,
        type: "cli",
        pid: "",
        content: e.detail,
      };
      items = [...items, log];
      dashboardStore.updateLogCount(1);
    });

    window.addEventListener("x:clear-logs", () => {
      items = [];
      dashboardStore.setLogCount(0);
    });

    window.addEventListener("x:download-logs", (e) => {
      const format = e.detail?.format || "text";
      const link = document.createElement("a");

      if (format === "json") {
        const exportItems = items.map(({ _details, _details_loading, ...rest }) => rest);
        const content = JSON.stringify(exportItems, null, 2);
        const file = new Blob([content], { type: "application/json" });
        link.href = URL.createObjectURL(file);
        link.download = "x_trace.json";
      } else {
        const content = items.map((log) => log.content).join("\n");
        const file = new Blob([content], { type: "text/plain" });
        link.href = URL.createObjectURL(file);
        link.download = "x_trace.log";
      }

      link.click();
      URL.revokeObjectURL(link.href);
    });

    window.addEventListener("x:import-logs", (e) => {
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
    });
  });

  function format_log(log) {
    let time = new Date(log.time / 1000000).toLocaleTimeString();
    ms = Math.trunc(log.time / 1000) % 1000;
    return time + "." + ms + " " + log.pid + " " + log.content;
  }

  let copied = false;
  let copyTimeout;

  function initViewer(node, content) {
    const viewer = new ElixirDataViewer(node, {defaultFoldLevel: 3, defaultWordWrap: true});
    viewer.setContent(content || "");
    return {
      update(newContent) {
        viewer.setContent(newContent || "");
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
    if ($dashboardStore.selected === item.time) {
      dashboardStore.setLog(null);
    } else {
      dashboardStore.setLog(item);
      if (item.trace_info && !item._details && !item._details_loading) {
        item._details_loading = true;
        items = items;
        live.pushEvent("format-details", { type: item.type, trace_info: item.trace_info }, ({ details }) => {
          item._details = details;
          item._details_loading = false;
          items = items;
        });
      }
    }
  }

  function applySettings(item) {
    settingsLocalStorage.select(item.id);
    live.pushEvent("apply-settings", item.encoded);
  }
</script>

<div class="grid grid-cols-1">
  <div id="logs-container" class="p-2 flex flex-col gap-1 mb-6">
    {#each items as item (item.time)}
      <div in:fade out:blur>
        <button
          class={cn(
            "w-full rounded-lg p-3 text-left text-sm transition-all",
            $dashboardStore.selected === item.time ? "bg-blue-100 border border-blue-300 dark:bg-blue-950 dark:border-blue-700" : "hover:bg-accent"
          )}
          on:click={() => toggleLog(item)}
        >
          <div class="flex items-start gap-2">
            <Badge variant="outline" class="shrink-0 {get_badge_class(item.type)}">{item.type}</Badge>
            <div class={cn(
              "text-muted-foreground text-sm",
              $dashboardStore.selected === item.time ? "" : "line-clamp-4"
            )}>
              {format_log(item)}
            </div>
          </div>
        </button>
        {#if $dashboardStore.selected === item.time}
          <div transition:slide={{ duration: 200 }} class="rounded-b-lg border border-t-0 border-blue-200 bg-blue-50/50 dark:border-blue-800 dark:bg-blue-950/30 px-4 pt-2 pb-3 -mt-1 ml-2 mr-2">
            <div class="flex items-center justify-between mb-2">
              <div class="text-xs grid grid-cols-[auto_1fr] gap-x-3 gap-y-1">
                <span class="font-semibold text-foreground">Time</span>
                <span class="text-muted-foreground">{new Date(item.time / 1000000).toLocaleString()}.{Math.trunc(item.time / 1000) % 1000}</span>
                {#if item.pid}
                  <span class="font-semibold text-foreground">PID</span>
                  <span class="text-muted-foreground">{item.pid}</span>
                {/if}
              </div>
              <Button variant="ghost" size="icon" class="h-7 w-7" on:click={() => copyContent(item.content)}>
                {#if copied}
                  <Check class="size-3.5 text-green-500" />
                {:else}
                  <Copy class="size-3.5" />
                {/if}
              </Button>
            </div>
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
          <Github class="size-4" />
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

          <!-- Import JSON Logs -->
          <div>
            <Button
              variant="outline"
              class="w-full justify-center gap-2"
              on:click={() => document.getElementById("upload-log-input").click()}
            >
              <FileUp class="size-4" />
              Import JSON Logs
            </Button>
          </div>

          <!-- Saved Settings -->
          {#if $settingsLocalStorage.items.length > 0}
            <div>
              <div class="text-sm font-semibold text-muted-foreground mb-3">Saved Settings</div>
              <div class="flex flex-col gap-3">
                {#each $settingsLocalStorage.items as item (item.id)}
                  <button
                    class="rounded-xl border border-border bg-card px-4 py-3 text-left transition-all hover:bg-accent hover:border-blue-300 dark:hover:border-blue-700 shadow-sm active:scale-[0.98]"
                    on:click={() => applySettings(item)}
                  >
                    <div class="flex items-center gap-3">
                      <CirclePlay class="size-5 text-blue-600 shrink-0" />
                      <span class="truncate font-medium text-sm">{item.name || item.t_specs}</span>
                    </div>
                  </button>
                {/each}
              </div>
            </div>

            <!-- Start Trace -->
            <div>
              <Button
                variant="default"
                class="w-full justify-center gap-2"
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
