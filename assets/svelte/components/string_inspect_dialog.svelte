<script>
  import * as Dialog from "$lib/components/ui/dialog/index.js";
  import * as Tabs from "$lib/components/ui/tabs/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Copy, Check } from "lucide-svelte/icons";
  import { elixirStringToPuts } from "../elixir_string_utils.js";
  import { marked } from "marked";

  export let open = false;
  export let rawString = "";

  let copied = false;
  let copyTimeout;

  $: putsResult = elixirStringToPuts(rawString);
  $: markdownHtml = renderMarkdown(putsResult);

  function renderMarkdown(text) {
    if (!text) return "";
    try {
      return marked(text, { breaks: true, gfm: true });
    } catch (_) {
      return `<pre>${escapeHtml(text)}</pre>`;
    }
  }

  function escapeHtml(str) {
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function copyToClipboard(text) {
    navigator.clipboard.writeText(text).catch(() => {
      const el = document.createElement("textarea");
      el.value = text;
      el.style.position = "fixed";
      el.style.opacity = "0";
      document.body.appendChild(el);
      el.select();
      document.execCommand("copy");
      document.body.removeChild(el);
    });
    copied = true;
    clearTimeout(copyTimeout);
    copyTimeout = setTimeout(() => { copied = false; }, 2000);
  }

  let activeTab = "raw";

  $: currentCopyText = activeTab === "raw" ? rawString : putsResult;
</script>

<Dialog.Root bind:open>
  <Dialog.Content class="max-w-4xl flex flex-col max-h-[85vh]">
    <Dialog.Header class="flex-shrink-0">
      <Dialog.Title>String Inspector</Dialog.Title>
      <Dialog.Description>
        Click on a tab to view the string in different formats.
      </Dialog.Description>
    </Dialog.Header>

    <Tabs.Root bind:value={activeTab} class="flex-1 flex flex-col min-h-0">
      <div class="flex items-center justify-between flex-shrink-0">
        <Tabs.List>
          <Tabs.Trigger value="raw">Raw String</Tabs.Trigger>
          <Tabs.Trigger value="puts">IO.puts</Tabs.Trigger>
          <Tabs.Trigger value="markdown">Markdown</Tabs.Trigger>
        </Tabs.List>
        <Button
          variant="ghost"
          size="icon"
          class="h-8 w-8"
          on:click={() => copyToClipboard(currentCopyText)}
        >
          {#if copied}
            <Check class="size-4 text-green-500" />
          {:else}
            <Copy class="size-4" />
          {/if}
        </Button>
      </div>

      <Tabs.Content value="raw" class="flex-1 min-h-0 mt-2">
        <div class="h-full overflow-y-auto max-h-[60vh]">
          <pre class="text-sm p-4 rounded-md bg-muted font-mono whitespace-pre-wrap break-all">{rawString}</pre>
        </div>
      </Tabs.Content>

      <Tabs.Content value="puts" class="flex-1 min-h-0 mt-2">
        <div class="h-full overflow-y-auto max-h-[60vh]">
          <pre class="text-sm p-4 rounded-md bg-muted font-mono whitespace-pre-wrap break-all">{putsResult}</pre>
        </div>
      </Tabs.Content>

      <Tabs.Content value="markdown" class="flex-1 min-h-0 mt-2">
        <div class="h-full overflow-y-auto max-h-[60vh]">
          <div class="prose prose-sm dark:prose-invert max-w-none p-4 rounded-md bg-muted">
            {@html markdownHtml}
          </div>
        </div>
      </Tabs.Content>
    </Tabs.Root>
  </Dialog.Content>
</Dialog.Root>
