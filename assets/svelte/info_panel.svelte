<script>
  import { Badge } from "$lib/components/ui/badge/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { SquareTerminal, Copy } from "lucide-svelte/icons";
  import { cn } from "$lib/utils.js";
  import CopyClipBoard from "$lib/components/copy_clipboard.svelte";
  import InfoHover from "$lib/components/info_hover.svelte";

  export let node_info;
  export let trace_settings;
  let t_specs_height;

  const copy = () => {
    const app = new CopyClipBoard({
      target: document.getElementById("clipboard"),
      props: { content: trace_settings.cli },
    });
    app.$destroy();
  };
</script>

<div class="p-4 space-y-4">
  <div class="grid grid-cols-2 gap-2">
    <div class="font-bold">Self Node</div>
    <div>
      <Badge variant="outline">
        {node_info.is_self ? "Yes" : "No"}
      </Badge>
    </div>

    <div class="font-bold flex items-center gap-2">
      <span>Code mode</span>
      <InfoHover>
        <pre
          class="text-wrap">The runtime system can be started in either embedded or interactive mode.</pre>
        <br />
        <pre
          class="text-wrap">In embedded mode, all code is loaded during system start-up according to the boot script.</pre>
        <br />
        <pre
          class="text-wrap">In interactive mode, code is dynamically loaded when first referenced.</pre>
      </InfoHover>
    </div>
    <div>
      <Badge variant="outline">
        {node_info.code_mode}
      </Badge>
    </div>
  </div>

  <div>
    <span class="cursor-pointer font-bold">TSpecs:</span><br />
    <ScrollArea
      class={cn(
        "overflow-y-auto overscroll-y-auto",
        t_specs_height > 192 && "h-48"
      )}
    >
      {#if trace_settings.t_specs == 0}
        [ ]
      {:else if trace_settings.t_specs == 1}
        <pre
          bind:clientHeight={t_specs_height}
          class="text-wrap text-sm">[{trace_settings.t_specs}]</pre>
      {:else}
        <pre bind:clientHeight={t_specs_height} class="text-wrap text-sm">[<br
          />&nbsp;&nbsp;{trace_settings.t_specs.join("\n  ")}<br />]</pre>
      {/if}
    </ScrollArea>
  </div>

  <div>
    <span class="cursor-pointer font-bold">Rate-Limiting:</span><br />
    <pre class="select-all text-sm">{trace_settings.max}</pre>
  </div>

  <div>
    <span class="cursor-pointer font-bold">Options:</span><br />
    <pre class="select-all text-wrap text-sm">{trace_settings.options}</pre>
  </div>

  <div class="grid grid-cols-2 gap-2">
    <Button
      variant="link"
      class="space-x-2"
      on:click={() => {
        window.dispatchEvent(
          new CustomEvent("x:print-cli", { detail: trace_settings.cli })
        );
      }}
    >
      <SquareTerminal class="size-4" />
      <span>Print Cli</span>
    </Button>
    <Button variant="link" class="space-x-2" on:click={copy}>
      <Copy class="size-4" />
      <span>Copy Cli</span>
    </Button>
  </div>
</div>
