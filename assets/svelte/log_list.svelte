<script>
  import { onMount, tick } from "svelte";
  import { dashboardStore } from "./d_store.js";
  import { cn } from "$lib/utils.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { fade, blur } from "svelte/transition";
  import { Gauge, BookOpen, Signature, Github } from "lucide-svelte/icons";

  export let live;
  let items = [];

  const TYPE_BADGE_CLASSES = {
    call:          "bg-blue-100 text-blue-800 border-blue-200",
    return_to:     "bg-blue-50 text-blue-600 border-blue-200",
    return_from:   "bg-sky-100 text-sky-800 border-sky-200",
    exception_from:"bg-red-100 text-red-800 border-red-200",
    send:          "bg-violet-100 text-violet-800 border-violet-200",
    send_to_non_existing_process: "bg-violet-50 text-violet-600 border-violet-200",
    receive:       "bg-indigo-100 text-indigo-800 border-indigo-200",
    spawn:         "bg-green-100 text-green-800 border-green-200",
    exit:          "bg-rose-100 text-rose-800 border-rose-200",
    link:          "bg-amber-100 text-amber-800 border-amber-200",
    unlink:        "bg-amber-50 text-amber-600 border-amber-200",
    getting_linked:   "bg-amber-100 text-amber-700 border-amber-200",
    getting_unlinked: "bg-amber-50 text-amber-600 border-amber-200",
    register:      "bg-teal-100 text-teal-800 border-teal-200",
    unregister:    "bg-teal-50 text-teal-600 border-teal-200",
    in:            "bg-gray-100 text-gray-700 border-gray-200",
    out:           "bg-gray-100 text-gray-600 border-gray-200",
    gc_start:      "bg-orange-100 text-orange-800 border-orange-200",
    gc_end:        "bg-orange-50 text-orange-600 border-orange-200",
    cli:           "bg-slate-100 text-slate-700 border-slate-200",
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

    window.addEventListener("x:download-logs", () => {
      console.log("create setting file...");
      const link = document.createElement("a");
      const content = items.map((log) => log.content).join("\n");
      const file = new Blob([content], { type: "text/plain" });
      link.href = URL.createObjectURL(file);
      link.download = "x_trace.log";
      link.click();
      URL.revokeObjectURL(link.href);
    });
  });

  function format_log(log) {
    let time = new Date(log.time / 1000000).toLocaleTimeString();
    ms = Math.trunc(log.time / 1000) % 1000;
    return time + "." + ms + " " + log.pid + " " + log.content;
  }
</script>

<div class="grid grid-cols-1">
  <div id="logs-container" class="p-2 flex flex-col gap-1 mb-6">
    {#each items as item (item.time)}
      <button
        in:fade
        out:blur
        class={cn(
          "rounded-lg p-3 text-left text-sm transition-all",
          $dashboardStore.selected === item.time ? "bg-blue-300" : "hover:bg-accent"
        )}
        on:click={() => {
          dashboardStore.setLog(item);
          console.log(item);
          if (item.trace_info) {
            live.pushEvent("format-details", { type: item.type, trace_info: item.trace_info }, ({ details }) => {
              dashboardStore.setLogDetails(details);
            });
          } else {
            dashboardStore.setLogDetails(null);
          }
        }}
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
    {/each}
    <div id="last-log-container"></div>
  </div>

  {#if items.length == 0}
    <div class="flex flex-col items-center" in:fade out:blur>
      <div
        class="mb-6 flex gap-4 items-center text-center text-sm text-gray-500"
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
  {/if}
</div>
