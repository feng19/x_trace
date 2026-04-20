<script>
  import * as Dialog from "$lib/components/ui/dialog/index.js";
  import * as Tabs from "$lib/components/ui/tabs/index.js";
  import { ScrollArea } from "$lib/components/ui/scroll-area/index.js";
  import { Button } from "$lib/components/ui/button/index.js";
  import { Input } from "$lib/components/ui/input/index.js";
  import { Copy, Check, Search, ChevronUp, ChevronDown, CaseSensitive } from "lucide-svelte/icons";
  import { elixirStringToPuts } from "../elixir_string_utils.js";
  import { onMount, afterUpdate, tick } from "svelte";
  import { mode } from "../dark_mode.js";

  export let open = false;
  export let rawString = "";

  let copied = false;
  let copyTimeout;

  // markdown-it + Lumis state
  let md = null;
  let lumisReady = false;
  let currentLightTheme = null;
  let currentDarkTheme = null;

  // Search state
  let searchQuery = "";
  let caseSensitive = false;
  let currentMatchIndex = 0;
  let matchCount = 0;
  let searchInputEl;

  // Content container refs for scrolling
  let rawContentEl;
  let putsContentEl;
  let markdownContentEl;

  onMount(async () => {
    try {
      const [
        MarkdownIt,
        markdownItLumisModule,
        { htmlInline },
        elixir,
        erlang,
        javascript,
        json,
        plaintext,
        bash,
        githubLight,
        githubDark,
      ] = await Promise.all([
        import("markdown-it").then((m) => m.default || m),
        import("@lumis-sh/markdown-it-lumis"),
        import("@lumis-sh/lumis/formatters"),
        import("@lumis-sh/lumis/langs/elixir").then((m) => m.default || m),
        import("@lumis-sh/lumis/langs/erlang").then((m) => m.default || m),
        import("@lumis-sh/lumis/langs/javascript").then((m) => m.default || m),
        import("@lumis-sh/lumis/langs/json").then((m) => m.default || m),
        import("@lumis-sh/lumis/langs/plaintext").then((m) => m.default || m),
        import("@lumis-sh/lumis/langs/bash").then((m) => m.default || m),
        import("@lumis-sh/themes/github_light").then((m) => m.default || m),
        import("@lumis-sh/themes/github_dark").then((m) => m.default || m),
      ]);

      currentLightTheme = githubLight;
      currentDarkTheme = githubDark;

      const markdownItLumis =
        markdownItLumisModule.default || markdownItLumisModule;

      const mdInstance = new MarkdownIt({ html: false, breaks: true, linkify: true });

      const lumisPlugin = await markdownItLumis({
        formatter: (language) => {
          const isDark =
            document.documentElement.classList.contains("dark");
          const theme = isDark ? currentDarkTheme : currentLightTheme;
          return htmlInline({ language, theme });
        },
        languages: [elixir, erlang, javascript, json, plaintext, bash],
      });

      lumisPlugin(mdInstance);
      md = mdInstance;
      lumisReady = true;
    } catch (err) {
      console.error("Failed to initialize markdown-it + Lumis:", err);
      // Fallback: use plain markdown-it without Lumis highlighting
      try {
        const MarkdownIt = await import("markdown-it").then(
          (m) => m.default || m,
        );
        md = new MarkdownIt({ html: false, breaks: true, linkify: true });
        lumisReady = true;
      } catch (err2) {
        console.error("Failed to initialize markdown-it:", err2);
      }
    }
  });

  $: putsResult = elixirStringToPuts(rawString);
  // Re-render whenever putsResult, lumisReady, or $mode changes
  $: markdownHtml = renderMarkdown(putsResult, lumisReady, $mode);

  const COPY_ICON_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="14" height="14" x="8" y="8" rx="2" ry="2"/><path d="M4 16c-1.1 0-2-.9-2-2V4c0-1.1.9-2 2-2h10c1.1 0 2 .9 2 2"/></svg>`;
  const CHECK_ICON_SVG = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>`;

  function addCopyButtonsToCodeBlocks(html) {
    return html.replace(
      /<pre((?:\s[^>]*)?)>/g,
      `<div class="code-block-wrapper"><button class="code-copy-btn" title="Copy code">${COPY_ICON_SVG}</button><pre$1>`
    ).replace(/<\/pre>/g, '</pre></div>');
  }

  function renderMarkdown(text, ready, _modeValue) {
    if (!text) return "";
    if (!ready || !md) {
      return `<pre>${escapeHtml(text)}</pre>`;
    }
    try {
      return addCopyButtonsToCodeBlocks(md.render(text));
    } catch (_) {
      return `<pre>${escapeHtml(text)}</pre>`;
    }
  }

  function handleMarkdownClick(e) {
    const btn = e.target.closest('.code-copy-btn');
    if (!btn) return;
    const wrapper = btn.closest('.code-block-wrapper');
    if (!wrapper) return;
    const pre = wrapper.querySelector('pre');
    if (!pre) return;
    const text = pre.textContent || '';
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
    btn.classList.add('copied');
    btn.innerHTML = CHECK_ICON_SVG;
    setTimeout(() => {
      btn.classList.remove('copied');
      btn.innerHTML = COPY_ICON_SVG;
    }, 2000);
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

  // --- Search logic ---

  // Get the text content for the current tab
  function getSearchText() {
    if (activeTab === "raw") return rawString;
    if (activeTab === "puts") return putsResult;
    // For markdown, search on the putsResult (source text)
    return putsResult;
  }

  // Find all match positions in a string
  function findMatches(text, query, isCaseSensitive) {
    if (!query || !text) return [];
    const flags = isCaseSensitive ? "g" : "gi";
    const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const regex = new RegExp(escaped, flags);
    const matches = [];
    let m;
    while ((m = regex.exec(text)) !== null) {
      matches.push({ start: m.index, end: m.index + m[0].length });
    }
    return matches;
  }

  // Reactive: compute matches whenever search params or tab changes
  $: searchText = getSearchText();
  // Need to be reactive to activeTab, searchQuery, caseSensitive
  $: matches = searchQuery ? findMatches(getSearchTextReactive(activeTab, rawString, putsResult), searchQuery, caseSensitive) : [];
  $: matchCount = matches.length;
  $: if (matchCount > 0 && currentMatchIndex >= matchCount) {
    currentMatchIndex = 0;
  }
  $: if (matchCount === 0) {
    currentMatchIndex = 0;
  }

  // Helper to make search text reactive to tab changes
  function getSearchTextReactive(tab, raw, puts) {
    if (tab === "raw") return raw;
    return puts;
  }

  // Build highlighted HTML for plain text tabs (raw, puts)
  function buildHighlightedHtml(text, query, isCaseSensitive, currentIdx) {
    if (!query || !text) return escapeHtml(text || "");
    const matchPositions = findMatches(text, query, isCaseSensitive);
    if (matchPositions.length === 0) return escapeHtml(text);

    let result = "";
    let lastEnd = 0;
    for (let i = 0; i < matchPositions.length; i++) {
      const { start, end } = matchPositions[i];
      // Append text before this match
      result += escapeHtml(text.slice(lastEnd, start));
      // Append the match with highlight
      const cls = i === currentIdx ? "search-highlight search-highlight-current" : "search-highlight";
      const dataAttr = `data-match-index="${i}"`;
      result += `<mark class="${cls}" ${dataAttr}>${escapeHtml(text.slice(start, end))}</mark>`;
      lastEnd = end;
    }
    // Append remaining text
    result += escapeHtml(text.slice(lastEnd));
    return result;
  }

  // Reactive highlighted HTML for raw and puts tabs
  $: highlightedRawHtml = buildHighlightedHtml(rawString, searchQuery, caseSensitive, activeTab === "raw" ? currentMatchIndex : -1);
  $: highlightedPutsHtml = buildHighlightedHtml(putsResult, searchQuery, caseSensitive, activeTab === "puts" ? currentMatchIndex : -1);

  // Navigation
  function goToNextMatch() {
    if (matchCount === 0) return;
    currentMatchIndex = (currentMatchIndex + 1) % matchCount;
    scrollToCurrentMatch();
  }

  function goToPrevMatch() {
    if (matchCount === 0) return;
    currentMatchIndex = (currentMatchIndex - 1 + matchCount) % matchCount;
    scrollToCurrentMatch();
  }

  async function scrollToCurrentMatch() {
    await tick();
    let container;
    if (activeTab === "raw") container = rawContentEl;
    else if (activeTab === "puts") container = putsContentEl;
    else container = markdownContentEl;

    if (!container) return;
    const currentMark = container.querySelector("mark.search-highlight-current");
    if (currentMark) {
      currentMark.scrollIntoView({ block: "center", behavior: "smooth" });
    }
  }

  function clearSearch() {
    searchQuery = "";
  }

  // Handle keyboard shortcuts on the dialog
  function handleDialogKeydown(e) {
    // Ctrl+F / Cmd+F to focus search
    if ((e.ctrlKey || e.metaKey) && e.key === "f") {
      e.preventDefault();
      e.stopPropagation();
      searchInputEl?.focus();
      searchInputEl?.select();
    }
  }

  // Handle keyboard in search input
  function handleSearchKeydown(e) {
    if (e.key === "Enter") {
      e.preventDefault();
      if (e.shiftKey) {
        goToPrevMatch();
      } else {
        goToNextMatch();
      }
    }
    if (e.key === "Escape") {
      e.preventDefault();
      clearSearch();
      searchInputEl?.blur();
    }
  }

  // Markdown tab: DOM-based highlighting via Svelte action
  function highlightDom(node, params) {
    let originalNodes = null;

    function clearHighlights() {
      if (originalNodes) {
        // Restore original content
        while (node.firstChild) node.removeChild(node.firstChild);
        for (const n of originalNodes) {
          node.appendChild(n.cloneNode(true));
        }
        originalNodes = null;
      }
    }

    function applyHighlights(query, isCaseSensitive, currentIdx) {
      clearHighlights();
      if (!query) return;

      // Save original DOM
      originalNodes = [];
      for (const child of node.childNodes) {
        originalNodes.push(child.cloneNode(true));
      }

      const flags = isCaseSensitive ? "g" : "gi";
      const escaped = query.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
      const regex = new RegExp(escaped, flags);
      let globalIdx = 0;

      function walkTextNodes(el) {
        const childNodes = Array.from(el.childNodes);
        for (const child of childNodes) {
          if (child.nodeType === Node.TEXT_NODE) {
            const text = child.textContent;
            if (!regex.test(text)) continue;
            regex.lastIndex = 0;

            const frag = document.createDocumentFragment();
            let lastIdx = 0;
            let match;
            while ((match = regex.exec(text)) !== null) {
              // Text before match
              if (match.index > lastIdx) {
                frag.appendChild(document.createTextNode(text.slice(lastIdx, match.index)));
              }
              // The match
              const mark = document.createElement("mark");
              mark.className = globalIdx === currentIdx
                ? "search-highlight search-highlight-current"
                : "search-highlight";
              mark.setAttribute("data-match-index", globalIdx);
              mark.textContent = match[0];
              frag.appendChild(mark);
              globalIdx++;
              lastIdx = match.index + match[0].length;
            }
            // Remaining text
            if (lastIdx < text.length) {
              frag.appendChild(document.createTextNode(text.slice(lastIdx)));
            }
            el.replaceChild(frag, child);
          } else if (child.nodeType === Node.ELEMENT_NODE && child.tagName !== "MARK") {
            walkTextNodes(child);
          }
        }
      }

      walkTextNodes(node);
    }

    applyHighlights(params.query, params.caseSensitive, params.currentMatchIndex);

    return {
      update(newParams) {
        applyHighlights(newParams.query, newParams.caseSensitive, newParams.currentMatchIndex);
      },
      destroy() {
        clearHighlights();
      }
    };
  }

  // When dialog closes, reset search
  $: if (!open) {
    searchQuery = "";
    currentMatchIndex = 0;
  }

  // When search query changes, reset to first match
  $: if (searchQuery !== undefined) {
    currentMatchIndex = 0;
  }

  // When tab changes, reset match index
  $: if (activeTab) {
    currentMatchIndex = 0;
  }

  // Scroll to match after highlight updates
  $: if (searchQuery && matchCount > 0) {
    // Trigger scroll after DOM updates
    tick().then(() => scrollToCurrentMatch());
  }
</script>

<!-- svelte-ignore a11y-no-static-element-interactions -->
<Dialog.Root bind:open>
  <Dialog.Content class="max-w-4xl 2xl:max-w-6xl flex flex-col max-h-[85vh] 2xl:max-h-[90vh]" on:keydown={handleDialogKeydown}>
    <Dialog.Header class="flex-shrink-0">
      <Dialog.Title>String Inspector</Dialog.Title>
      <Dialog.Description>
        Click on a tab to view the string in different formats.
      </Dialog.Description>
    </Dialog.Header>

    <Tabs.Root bind:value={activeTab} class="flex-1 flex flex-col min-h-0">
      <div class="flex items-center gap-2 flex-shrink-0">
        <Tabs.List class="shrink-0">
          <Tabs.Trigger value="raw">Raw String</Tabs.Trigger>
          <Tabs.Trigger value="puts">IO.puts</Tabs.Trigger>
          <Tabs.Trigger value="markdown">Markdown</Tabs.Trigger>
        </Tabs.List>
        <div class="flex items-center gap-1 flex-1 min-w-0 border rounded-md px-2 py-0 bg-background">
          <Search class="size-3.5 text-muted-foreground shrink-0" />
          <input
            bind:this={searchInputEl}
            bind:value={searchQuery}
            on:keydown={handleSearchKeydown}
            type="text"
            placeholder="Search..."
            class="flex-1 bg-transparent text-sm outline-none placeholder:text-muted-foreground min-w-0"
          />
          {#if searchQuery}
            <span class="text-xs text-muted-foreground whitespace-nowrap">
              {matchCount > 0 ? `${currentMatchIndex + 1} / ${matchCount}` : "0 / 0"}
            </span>
          {/if}
          <Button
            variant="ghost"
            size="icon"
            class="h-6 w-6 shrink-0 {caseSensitive ? 'bg-accent text-accent-foreground' : ''}"
            on:click={() => { caseSensitive = !caseSensitive; }}
            title="Match Case"
          >
            <CaseSensitive class="size-3.5" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            class="h-6 w-6 shrink-0"
            on:click={goToPrevMatch}
            disabled={matchCount === 0}
            title="Previous Match (Shift+Enter)"
          >
            <ChevronUp class="size-3.5" />
          </Button>
          <Button
            variant="ghost"
            size="icon"
            class="h-6 w-6 shrink-0"
            on:click={goToNextMatch}
            disabled={matchCount === 0}
            title="Next Match (Enter)"
          >
            <ChevronDown class="size-3.5" />
          </Button>
        </div>
        <Button
          variant="ghost"
          size="icon"
          class="h-8 w-8 shrink-0"
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
        <div class="h-full overflow-y-auto max-h-[60vh] 2xl:max-h-[74vh]" bind:this={rawContentEl}>
          <pre class="text-sm p-2 rounded-md bg-muted font-mono whitespace-pre-wrap break-all">{@html highlightedRawHtml}</pre>
        </div>
      </Tabs.Content>

      <Tabs.Content value="puts" class="flex-1 min-h-0 mt-2">
        <div class="h-full overflow-y-auto max-h-[60vh] 2xl:max-h-[74vh]" bind:this={putsContentEl}>
          <pre class="text-sm p-2 rounded-md bg-muted font-mono whitespace-pre-wrap break-all">{@html highlightedPutsHtml}</pre>
        </div>
      </Tabs.Content>

      <!-- svelte-ignore a11y-click-events-have-key-events -->
      <!-- svelte-ignore a11y-no-static-element-interactions -->
      <Tabs.Content value="markdown" class="flex-1 min-h-0 mt-2">
        <div class="h-full overflow-y-auto max-h-[60vh] 2xl:max-h-[74vh]" bind:this={markdownContentEl}>
          <div
            class="prose prose-sm dark:prose-invert max-w-none p-2 rounded-md bg-muted markdown-content"
            use:highlightDom={{ query: searchQuery, caseSensitive, currentMatchIndex: activeTab === "markdown" ? currentMatchIndex : -1 }}
            on:click={handleMarkdownClick}
          >
            {#if !lumisReady}
              <div class="flex items-center gap-2 text-muted-foreground text-sm">
                <svg class="animate-spin h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                  <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                  <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                </svg>
                Initializing syntax highlighter…
              </div>
            {/if}
            {@html markdownHtml}
          </div>
        </div>
      </Tabs.Content>
    </Tabs.Root>
  </Dialog.Content>
</Dialog.Root>

<style>
  /* Code block overflow fix */
  :global(.markdown-content pre) {
    max-width: 100%;
    white-space: pre-wrap;
    word-wrap: break-word;
    word-break: break-all;
    overflow-wrap: break-word;
  }
  :global(.markdown-content code) {
    overflow-wrap: break-word;
  }
  :global(.markdown-content pre code) {
    white-space: pre-wrap;
    overflow-wrap: break-word;
    word-break: break-all;
  }

  /* Code block wrapper with copy button */
  :global(.code-block-wrapper) {
    position: relative;
  }
  :global(.code-copy-btn) {
    position: absolute;
    top: 0.5rem;
    right: 0.5rem;
    z-index: 10;
    display: flex;
    align-items: center;
    justify-content: center;
    width: 2rem;
    height: 2rem;
    border-radius: 0.375rem;
    border: 1px solid hsl(var(--border));
    background-color: hsl(var(--background));
    color: hsl(var(--muted-foreground));
    cursor: pointer;
    opacity: 0;
    transition: opacity 0.15s ease, background-color 0.15s ease, color 0.15s ease;
  }
  :global(.code-block-wrapper:hover .code-copy-btn) {
    opacity: 1;
  }
  :global(.code-copy-btn:hover) {
    background-color: hsl(var(--accent));
    color: hsl(var(--accent-foreground));
  }
  :global(.code-copy-btn.copied) {
    opacity: 1;
    color: #22c55e;
  }

  :global(mark.search-highlight) {
    background-color: #fbbf24;
    color: inherit;
    border-radius: 2px;
    padding: 0;
  }
  :global(.dark mark.search-highlight) {
    background-color: #b45309;
    color: inherit;
  }
  :global(mark.search-highlight-current) {
    background-color: #f97316;
    color: white;
  }
  :global(.dark mark.search-highlight-current) {
    background-color: #ea580c;
    color: white;
  }
</style>
