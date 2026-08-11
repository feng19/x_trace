<script>
  import { settingsLocalStorage } from "./settings_local_storage.js";
  import { dashboardStore } from "./d_store.js";
  import { cn } from "$lib/utils.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { Separator } from "$lib/components/ui/separator/index.js";
  import { fade, blur } from "svelte/transition";
  import { Gauge, BookOpen, Signature, ExternalLink, CirclePlay, FileUp, Play, Settings } from "@lucide/svelte/icons";
  import NodeSwitcher from "./node_switcher.svelte";
  import SettingsDisplay from "$lib/components/settings_display.svelte";
  import * as HoverCard from "$lib/components/ui/hover-card";

  let { live, node_info = {}, version = "", trace_settings = {} } = $props();

  // Show the "Current Trace Settings" card only when the user has configured
  // trace patterns that are NOT tied to a saved preset (no selection).
  let showCurrentSettings = $derived(
    (trace_settings?.t_specs?.length ?? 0) > 0
  );

  // Put the selected preset first, keeping the rest in their saved order.
  let savedItems = $derived.by(() => {
    const { items, selected } = $settingsLocalStorage;
    const index = selected ? items.findIndex((v) => v.id === selected) : -1;
    if (index <= 0) return items;
    return [items[index], ...items.slice(0, index), ...items.slice(index + 1)];
  });

  function applySettings(item) {
    settingsLocalStorage.select(item.id);
    live.pushEvent("apply-settings", item.encoded);
  }
</script>

<div class="flex flex-col items-center px-4" in:fade out:blur>
  <!-- Version -->
  {#if version}
    <div class="mb-2 text-xs text-muted-foreground/60 font-mono">xTrace v{version}</div>
  {/if}

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

  !! Go to <a href="#settings" onclick={(e) => { e.preventDefault(); dashboardStore.setSettingMode(true); }} class="underline hover:text-foreground cursor-pointer">[Trace Settings]</a> start & trace. !!
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
          class="w-full justify-center gap-2 h-10"
          onclick={() => document.getElementById("upload-log-input").click()}
        >
          <FileUp class="size-4" />
          Import JSON Logs
        </Button>

        <!-- Import Settings -->
        <Button
          variant="outline"
          class="w-full justify-center gap-2 h-10"
          onclick={() => document.getElementById("upload-setting-input").click()}
        >
          <Settings class="size-4" />
          Import Settings
        </Button>

        <!-- Current Trace Settings (unsaved, not from a preset) -->
        {#if showCurrentSettings}
          <HoverCard.Root openDelay={200} closeDelay={100}>
            <HoverCard.Trigger>
              {#snippet child({ props })}
                <button
                  {...props}
                  class="w-full cursor-pointer rounded-xl border border-dashed border-blue-300 dark:border-blue-700 bg-blue-50/50 dark:bg-blue-950/30 px-4 py-3 text-left transition-all shadow-sm hover:bg-blue-50 dark:hover:bg-blue-950/50 active:scale-[0.98]"
                  onclick={() => dashboardStore.setSettingMode(true)}
                >
                  <div class="flex items-center gap-3">
                    <Gauge class="size-5 shrink-0 text-blue-600 dark:text-blue-400" />
                    <div class="min-w-0 flex-1">
                      <span class="truncate font-medium text-sm block">Current Trace Settings</span>
                      <span class="text-xs text-muted-foreground">
                        {trace_settings.t_specs.length} matching pattern{trace_settings.t_specs.length > 1 ? "s" : ""} · unsaved
                      </span>
                    </div>
                  </div>
                </button>
              {/snippet}
            </HoverCard.Trigger>
            <HoverCard.Content
              side="left"
              align="start"
              class="w-[26rem] lg:w-[34rem] 2xl:w-[44rem] max-w-[90vw] max-h-[70vh] overflow-y-auto"
            >
              <div class="font-semibold text-sm text-blue-700 dark:text-blue-400 mb-2">Current Trace Settings</div>
              <SettingsDisplay
                tSpecs={trace_settings.t_specs}
                max={trace_settings.max}
                options={trace_settings.options}
              />
            </HoverCard.Content>
          </HoverCard.Root>
        {/if}
      </div>

      <!-- Saved Settings -->
      {#if $settingsLocalStorage.items.length > 0}
        {#snippet savedCard(item)}
          <HoverCard.Root openDelay={200} closeDelay={100}>
            <HoverCard.Trigger>
              {#snippet child({ props })}
                <button
                  {...props}
                  class={cn(
                    "w-full cursor-pointer rounded-xl border px-4 py-3 text-left transition-all shadow-sm active:scale-[0.98]",
                    $settingsLocalStorage.selected === item.id
                      ? "border-blue-400 bg-blue-50 dark:border-blue-600 dark:bg-blue-950/40 ring-1 ring-blue-300 dark:ring-blue-700"
                      : "border-border bg-card hover:bg-accent hover:border-blue-300 dark:hover:border-blue-700"
                  )}
                  onclick={() => applySettings(item)}
                >
                  <div class="flex items-center gap-3">
                    <CirclePlay class={cn("size-5 shrink-0", $settingsLocalStorage.selected === item.id ? "text-blue-700 dark:text-blue-400" : "text-blue-600")} />
                    <div class="min-w-0 flex-1">
                      <div class="flex items-center gap-1.5">
                        <span class="truncate font-medium text-sm">{item.name || item.t_specs}</span>
                        {#if item.t_specs_count > 0}
                          <Badge
                            variant="secondary"
                            class="shrink-0 px-1.5 py-0 text-[10px] tabular-nums"
                            title="{item.t_specs_count} matching pattern{item.t_specs_count > 1 ? 's' : ''}"
                          >
                            {item.t_specs_count}
                          </Badge>
                        {/if}
                      </div>
                      {#if item.saved_at}
                        <span class="text-xs text-muted-foreground">Saved: {new Date(item.saved_at).toLocaleString()}</span>
                      {/if}
                    </div>
                  </div>
                </button>
              {/snippet}
            </HoverCard.Trigger>
            <HoverCard.Content
              side="left"
              align="start"
              class="w-[26rem] lg:w-[34rem] 2xl:w-[44rem] max-w-[90vw] max-h-[70vh] overflow-y-auto"
            >
              {#if item.name}
                <div class="font-semibold text-sm text-blue-700 dark:text-blue-400">{item.name}</div>
              {/if}
              {#if item.saved_at}
                <div class="text-xs text-muted-foreground mb-2">Saved: {new Date(item.saved_at).toLocaleString()}</div>
              {/if}
              <SettingsDisplay tSpecs={item.t_specs} max={item.max} options={item.options} />
            </HoverCard.Content>
          </HoverCard.Root>
        {/snippet}

        <div>
          <div class="text-sm font-semibold text-muted-foreground mb-3">Saved Settings</div>
          {#if savedItems.length > 5}
            <ScrollArea class="h-96">
              <div class="flex flex-col gap-3 pr-3">
                {#each savedItems as item (item.id)}
                  {@render savedCard(item)}
                {/each}
              </div>
            </ScrollArea>
          {:else}
            <div class="flex flex-col gap-3">
              {#each savedItems as item (item.id)}
                {@render savedCard(item)}
              {/each}
            </div>
          {/if}
        </div>

        <!-- Open Settings & Start Trace -->
        <div class="flex flex-col gap-3">
          <Button
            variant="outline"
            class="w-full justify-center gap-2 h-10"
            onclick={() => dashboardStore.setSettingMode(true)}
          >
            <Settings class="size-4" />
            Open Settings
          </Button>
          <Button
            variant="outline"
            class="w-full justify-center gap-2 h-10 text-red-600"
            onclick={() => live.pushEvent("start-trace", {})}
          >
            <Play class="size-4" />
            Start Trace
          </Button>
        </div>
      {/if}
    </div>
  </div>
</div>
