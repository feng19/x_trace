<script>
  import { Input } from "$lib/components/ui/input";
  import { Label } from "$lib/components/ui/label";
  import { Button } from "$lib/components/ui/button/index.js";
  import Switch from "$lib/components/switch.svelte";
  import ItemWithX from "$lib/components/item_with_x.svelte";
  import InfoHover from "$lib/components/info_hover.svelte";
  import { Plus } from "@lucide/svelte/icons";
  import { flip } from "svelte/animate";
  import { fade } from "svelte/transition";

  let {
    live,
    scope,
    pid,
    add_pid_enable = false,
    pids,
  } = $props();

  let scope_items = [
    { value: "local", label: "local" },
    { value: "global", label: "global" },
  ];
  let pid_items = [
    { value: "all", label: "all" },
    { value: "new", label: "new" },
    { value: "existing", label: "existing" },
    { value: "pid", label: "pid" },
  ];

  const scope_descriptions = {
    local: "All types of function calls, including local calls within a module.",
    global: "Only exported functions match and only global calls generate trace messages.",
  };

  const pid_descriptions = {
    all: "All currently existing processes and all that will be created in the future.",
    new: "All processes that will be created in the future.",
    existing: "All currently existing processes.",
    pid: "Specific process identifiers (pids).",
  };

  function removePid(index) {
    live.pushEvent("del-pid", { index });
  }
</script>

<div class="px-1 sm:px-2 space-y-4">
  <div class="space-y-4">
    <div class="space-y-1.5">
      <div class="flex items-center gap-1">
        <Label for="options_scope" class="text-xs sm:text-sm">Function Scope</Label>
        <InfoHover>
          <p class="text-sm font-medium mb-1">Function Scope</p>
          <p class="text-xs text-muted-foreground mb-2">
            Determines which function calls are traced:
          </p>
          <ul class="text-xs text-muted-foreground list-disc pl-4 space-y-1">
            <li><strong>global</strong> — Only exported functions match and only global calls generate trace messages.</li>
            <li><strong>local</strong> — All types of function calls, including local calls within a module.</li>
          </ul>
          <a
            href="https://www.erlang.org/doc/apps/kernel/trace.html#function/4"
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-blue-500 hover:underline mt-2 inline-block"
          >
            Erlang Docs: trace:function/4
          </a>
        </InfoHover>
      </div>
      <Switch
        id="options_scope"
        items={scope_items}
        value={scope}
        onValueChange={(value) => live.pushEvent("set-scope", value)}
      />
      {#if scope_descriptions[scope]}
        <p class="text-xs text-muted-foreground">{scope_descriptions[scope]}</p>
      {/if}
    </div>

    <div class="space-y-1.5">
      <div class="flex items-center gap-1">
        <Label for="options_pid" class="text-xs sm:text-sm">Match Pids</Label>
        <InfoHover>
          <p class="text-sm font-medium mb-1">Argument Procs</p>
          <p class="text-xs text-muted-foreground mb-2">
            Either a list of process identifier (pids) for local processes or one of the following atoms:
          </p>
          <ul class="text-xs text-muted-foreground list-disc pl-4 space-y-1">
            <li><strong>all</strong> — All currently existing processes and all that will be created in the future.</li>
            <li><strong>existing</strong> — All currently existing processes.</li>
            <li><strong>new</strong> — All processes that will be created in the future.</li>
          </ul>
          <a
            href="https://www.erlang.org/doc/apps/kernel/trace.html#process/4"
            target="_blank"
            rel="noopener noreferrer"
            class="text-xs text-blue-500 hover:underline mt-2 inline-block"
          >
            Erlang Docs: trace:process/4
          </a>
        </InfoHover>
      </div>
      <Switch
        id="options_pid"
        items={pid_items}
        value={pid}
        onValueChange={(value) => live.pushEvent("set-pid", value)}
      />
      {#if pid_descriptions[pid]}
        <p class="text-xs text-muted-foreground">{pid_descriptions[pid]}</p>
      {/if}
    </div>
  </div>

  {#if pid === "pid" && pids.length !== 0}
    <div class="flex flex-wrap gap-2" transition:fade>
      {#each pids as pid_item, index (pid_item)}
        <ItemWithX onClick={() => {}} onRemove={() => removePid(index)}>
          {pid_item}
        </ItemWithX>
      {/each}
    </div>
  {/if}

  {#if pid === "pid"}
    <form
      phx-change="validate-pid"
      phx-submit="add-pid"
      class="grid grid-cols-[1fr,auto] gap-2"
      transition:fade
    >
      <Input name="pid" id="options_pid_input" placeholder="A.B.C" required />
      <Button
        class="flex items-center gap-2"
        disabled={!add_pid_enable}
        type="submit"
      >
        <Plus class="size-4" /> Add
      </Button>
    </form>
  {/if}
</div>
