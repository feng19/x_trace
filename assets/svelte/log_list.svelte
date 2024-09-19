<script>
  import { onMount, tick } from 'svelte';
  import { dashboardStore } from "./d_store.js";
  import { cn } from "$lib/utils.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { fade, blur } from 'svelte/transition';
  import Gauge from "lucide-svelte/icons/gauge";
  import BookOpen from "lucide-svelte/icons/book-open";
  import Signature from "lucide-svelte/icons/signature";
  import Github from "lucide-svelte/icons/github";

  export let live;
  let items = [];

  function get_badge_variant_from_label(label) {
    if (["work"].includes(label.toLowerCase())) {
      return "default";
    }

    if (["personal"].includes(label.toLowerCase())) {
      return "outline";
    }

    return "secondary";
  }

  onMount(() => {
    let wrapper_s = document.getElementById("logs-container-s")
    let wrapper = document.getElementById("logs-container")

    live.handleEvent("add-log", (log) => {
      items = [...items, log];
      dashboardStore.updateLogCount(1);

      if ($dashboardStore.auto_scroll) {
        tick().then(() => {
          if (wrapper.scrollHeight > wrapper_s.scrollHeight) {
            let item_node = document.getElementById("last-log-container");
            item_node.scrollIntoView({behavior: 'smooth'});
          }
        });
      }
    });

    window.addEventListener("x:print-cli", (e) => {
      let log = {time: new Date().getTime() * 1000000, type: "cli", pid: "", content: e.detail}
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
      const file = new Blob([content], { type: 'text/plain' });
      link.href = URL.createObjectURL(file);
      link.download = "x_trace.log";
      link.click();
      URL.revokeObjectURL(link.href);
    });
  });

  function format_log(log) {
    let time = new Date(log.time/1000000).toLocaleTimeString();
    ms = Math.trunc(log.time / 1000) % 1000;
    return time + "." + ms + " " + log.pid + " " + log.content;
  }
</script>

<div class="grid grid-cols-1">
  <div id="logs-container" class="p-2 flex flex-col gap-1 mb-6">
    {#each items as item (item.time)}
      <button in:fade out:blur
        class={cn(
          "hover:bg-accent rounded-lg p-3 text-left text-sm transition-all",
          $dashboardStore.selected === item.time && "bg-blue-300"
        )}
        on:click={() => dashboardStore.setLog(item)}
      >
        <div class="text-muted-foreground line-clamp-2 text-sm">
          {format_log(item)}
        </div>
      </button>
    {/each}
    <div id="last-log-container"></div>
  </div>


  {#if items.length == 0 }
  <div class="flex flex-col items-center" in:fade out:blur>
  <div class="mb-6 flex gap-4 items-center text-center text-sm text-gray-500">
    <Button variant="link" class="space-x-2" href="/dashboard" target="_blank">
      <Gauge class="size-4" />
      <span>Dashboard</span>
    </Button>
    <Button variant="link" class="space-x-2" href="https://hexdocs.pm/recon/recon_trace.html" target="_blank">
      <BookOpen class="size-4" />
      <span>Document</span>
    </Button>
    <Button variant="link" class="space-x-2" href="https://github.com/feng19" target="_blank">
      <Signature class="size-4" />
      <span>Author: feng19</span>
    </Button>
    <Button variant="link" class="space-x-2" href="https://github.com/feng19/x_trace" target="_blank">
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
