<script>
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import { dashboardStore } from "./d_store.js";
  import { cn } from "$lib/utils.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Separator } from "$lib/components/ui/separator/index.js";
  import { fade, blur } from "svelte/transition";
  import { Gauge, BookOpen, Signature, ExternalLink, CirclePlay, FileUp, Play, Settings } from "lucide-svelte/icons";
  import NodeSwitcher from "./node_switcher.svelte";

  export let live;
  export let node_info = {};

  function applySettings(item) {
    settingsLocalStorage.select(item.id);
    live.pushEvent("apply-settings", item.encoded);
  }
</script>

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
      href="https://www.erlang.org/doc/apps/kernel/trace.html"
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

  The <a href="https://www.erlang.org/doc/apps/kernel/trace.html" target="_blank" class="underline hover:text-foreground">Erlang Trace BIFs</a> allow to trace any Elixir and Erlang code at
  all. They work in two parts: pid specifications, and trace patterns.

  Pid specifications let you decide which processes to target. They
  can be specific pids, `all` pids, `existing` pids, or `new` pids
  (those not spawned at the time of the function call).

  The trace patterns represent functions. Functions can be specified
  in two parts: specifying the modules, functions, and arguments, and
  then with <a href="https://www.erlang.org/doc/apps/erts/match_spec.html" target="_blank" class="underline hover:text-foreground">Erlang match specifications</a> to add constraints to
  arguments.

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

  !! Go to <a href="#settings" on:click|preventDefault={() => dashboardStore.setSettingMode(true)} class="underline hover:text-foreground cursor-pointer">[Trace Settings]</a> start & trace. !!
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
          {#if $settingsLocalStorage.items.length > 5}
            <ScrollArea class="h-96">
              <div class="flex flex-col gap-3 pr-3">
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
            </ScrollArea>
          {:else}
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
          {/if}
        </div>

        <!-- Open Settings & Start Trace -->
        <div class="flex flex-col gap-3">
          <Button
            variant="outline"
            class="w-full justify-center gap-2"
            on:click={() => dashboardStore.setSettingMode(true)}
          >
            <Settings class="size-4" />
            Open Settings
          </Button>
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
