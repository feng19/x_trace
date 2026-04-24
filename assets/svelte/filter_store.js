import { writable, get } from "svelte/store";

const STORAGE_KEY = "x-trace-filter-keys";
const FOLD_LEVEL_STORAGE_KEY = "x-trace-fold-level";
const SHOW_DETAILS_PID_KEY = "x-trace-show-details-pid";
const SHOW_DETAILS_TIME_KEY = "x-trace-show-details-time";
const HIDDEN_TYPES_STORAGE_KEY = "x-trace-hidden-types";

function loadFilteredKeys() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return [];
}

function saveFilteredKeys(keys) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(keys));
  } catch (_) {}
}

function loadFoldLevel() {
  try {
    const raw = localStorage.getItem(FOLD_LEVEL_STORAGE_KEY);
    if (raw !== null) {
      const val = parseInt(raw, 10);
      if (!isNaN(val) && val >= 0 && val <= 10) return val;
    }
  } catch (_) {}
  return 2; // default fold level
}

function saveFoldLevel(level) {
  try {
    localStorage.setItem(FOLD_LEVEL_STORAGE_KEY, String(level));
  } catch (_) {}
}

function loadShowDetailsPid() {
  try {
    const raw = localStorage.getItem(SHOW_DETAILS_PID_KEY);
    if (raw !== null) return raw === "true";
  } catch (_) {}
  return false; // default: not shown
}

function saveShowDetailsPid(val) {
  try {
    localStorage.setItem(SHOW_DETAILS_PID_KEY, String(val));
  } catch (_) {}
}

function loadShowDetailsTime() {
  try {
    const raw = localStorage.getItem(SHOW_DETAILS_TIME_KEY);
    if (raw !== null) return raw === "true";
  } catch (_) {}
  return false; // default: not shown
}

function saveShowDetailsTime(val) {
  try {
    localStorage.setItem(SHOW_DETAILS_TIME_KEY, String(val));
  } catch (_) {}
}

function loadHiddenTypes() {
  try {
    const raw = localStorage.getItem(HIDDEN_TYPES_STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return [];
}

function saveHiddenTypes(types) {
  try {
    localStorage.setItem(HIDDEN_TYPES_STORAGE_KEY, JSON.stringify(types));
  } catch (_) {}
}

/**
 * Global filter store for ElixirDataViewer key filtering and search.
 *
 * Manages:
 * - filteredKeys: keys currently hidden across all viewers
 * - availableKeys: all detected keys from all registered viewers
 * - viewers: Map of registered ElixirDataViewer instances
 * - searchQuery / searchTotalMatches / searchCaseSensitive: global search state
 */
function createFilterStore() {
  const store = writable({
    filteredKeys: loadFilteredKeys(),
    availableKeys: [],
    // Fold level state
    foldLevel: loadFoldLevel(),
    // Details display toggles
    showDetailsPid: loadShowDetailsPid(),
    showDetailsTime: loadShowDetailsTime(),
    // Type filter state
    hiddenTypes: loadHiddenTypes(),
    availableTypes: [],
    // PID filter state (session-only, not persisted)
    // When non-empty, only show logs matching these PIDs
    filterPids: [],
    // Search state
    searchQuery: "",
    searchTotalMatches: 0,
    searchCaseSensitive: false,
    searchActiveViewerId: null,
  });

  // Internal viewer registry (not reactive — no need to trigger UI updates)
  const viewers = new Map();

  // Ordered list of viewer IDs for navigation
  function getViewerIds() {
    return Array.from(viewers.keys());
  }

  function rebuildAvailableKeys() {
    const allKeys = new Set();
    for (const viewer of viewers.values()) {
      try {
        for (const key of viewer.getAvailableKeys()) {
          allKeys.add(key);
        }
      } catch (_) {
        // viewer may have been destroyed
      }
    }
    const sorted = Array.from(allKeys).sort();
    store.update((s) => ({ ...s, availableKeys: sorted }));
  }

  /**
   * Get the scroll viewport element inside #logs-container-s (bits-ui ScrollArea).
   * Returns the viewport element or null.
   */
  function getScrollViewport() {
    try {
      const root = document.getElementById("logs-container-s");
      // bits-ui ScrollArea renders a viewport div as a direct child
      return root?.querySelector("[data-scrollarea-viewport]") ?? null;
    } catch (_) {
      return null;
    }
  }

  /**
   * Execute `fn` while preserving the scroll position of the main log scroll area.
   * Also suppresses search-match auto-scroll on each viewer's render().
   */
  function withScrollPreserved(fn) {
    const viewport = getScrollViewport();
    const scrollTop = viewport ? viewport.scrollTop : 0;

    // Suppress search-match auto-scroll during render for all viewers
    for (const viewer of viewers.values()) {
      try { viewer.suppressScrollOnRender = true; } catch (_) {}
    }

    fn();

    // Restore scroll position synchronously (before browser paints)
    if (viewport) {
      viewport.scrollTop = scrollTop;
    }
  }

  function syncAllViewers() {
    const { filteredKeys } = get(store);
    withScrollPreserved(() => {
      for (const viewer of viewers.values()) {
        try {
          viewer.setFilterKeys(filteredKeys);
        } catch (_) {
          // viewer may have been destroyed
        }
      }
    });
  }

  /**
   * Recalculate total matches across all viewers and update store.
   */
  function recalcSearchMatches() {
    let total = 0;
    for (const viewer of viewers.values()) {
      try {
        total += viewer.getSearchState().getMatchCount();
      } catch (_) {}
    }
    store.update((s) => ({ ...s, searchTotalMatches: total }));
  }

  /**
   * Apply the current search query to a single viewer.
   */
  function applySearchToViewer(viewer) {
    const { searchQuery, searchCaseSensitive } = get(store);
    if (searchQuery) {
      try {
        viewer.search(searchQuery, { caseSensitive: searchCaseSensitive, scroll: false });
      } catch (_) {}
    }
  }

  /**
   * Find the next viewer (by insertion order) that has search matches,
   * starting from the given viewer ID. direction: 1 = forward, -1 = backward.
   */
  function findViewerWithMatches(fromId, direction) {
    const ids = getViewerIds();
    if (ids.length === 0) return null;
    let startIdx = fromId ? ids.indexOf(fromId) : (direction === 1 ? 0 : ids.length - 1);
    if (startIdx < 0) startIdx = direction === 1 ? 0 : ids.length - 1;

    for (let i = 0; i < ids.length; i++) {
      const idx = (startIdx + direction * (i + 1) + ids.length * ids.length) % ids.length;
      const id = ids[idx];
      const viewer = viewers.get(id);
      try {
        if (viewer && viewer.getSearchState().getMatchCount() > 0) {
          return id;
        }
      } catch (_) {}
    }
    return null;
  }

  return {
    subscribe: store.subscribe,

    /**
     * Register an ElixirDataViewer instance. Merges its available keys
     * and applies the current filter + search.
     */
    registerViewer(id, viewer) {
      viewers.set(id, viewer);
      rebuildAvailableKeys();
      // Apply current filter to the new viewer
      const { filteredKeys, foldLevel } = get(store);
      if (filteredKeys.length > 0) {
        try {
          viewer.setFilterKeys(filteredKeys);
        } catch (_) {}
      }
      // Apply current fold level
      try {
        viewer.foldToLevel(foldLevel);
      } catch (_) {}
      // Apply current search to the new viewer
      applySearchToViewer(viewer);
      recalcSearchMatches();
    },

    /**
     * Unregister a viewer (e.g., when its DOM node is destroyed).
     */
    unregisterViewer(id) {
      const { searchActiveViewerId } = get(store);
      viewers.delete(id);
      rebuildAvailableKeys();
      // If the active search viewer was removed, clear active
      if (searchActiveViewerId === id) {
        store.update((s) => ({ ...s, searchActiveViewerId: null }));
      }
      recalcSearchMatches();
    },

    /**
     * Refresh available keys from a specific viewer (e.g., after content change).
     */
    refreshViewer(id, viewer) {
      viewers.set(id, viewer);
      rebuildAvailableKeys();
      // Re-apply filter to updated viewer
      const { filteredKeys, foldLevel } = get(store);
      if (filteredKeys.length > 0) {
        try {
          viewer.setFilterKeys(filteredKeys);
        } catch (_) {}
      }
      // Re-apply fold level
      try {
        viewer.foldToLevel(foldLevel);
      } catch (_) {}
      // Re-apply search to updated viewer
      applySearchToViewer(viewer);
      recalcSearchMatches();
    },

    /**
     * Add a key to the filter list. Updates all viewers.
     */
    addKey(key) {
      store.update((s) => {
        if (s.filteredKeys.includes(key)) return s;
        const updated = [...s.filteredKeys, key];
        saveFilteredKeys(updated);
        return { ...s, filteredKeys: updated };
      });
      syncAllViewers();
    },

    /**
     * Remove a key from the filter list. Updates all viewers.
     */
    removeKey(key) {
      store.update((s) => {
        const updated = s.filteredKeys.filter((k) => k !== key);
        saveFilteredKeys(updated);
        return { ...s, filteredKeys: updated };
      });
      syncAllViewers();
    },

    /**
     * Clear all filtered keys. Updates all viewers.
     */
    clearKeys() {
      store.update((s) => ({ ...s, filteredKeys: [] }));
      saveFilteredKeys([]);
      withScrollPreserved(() => {
        for (const viewer of viewers.values()) {
          try {
            viewer.clearFilter();
          } catch (_) {}
        }
      });
    },

    /**
     * Get the number of registered viewers.
     */
    getViewerCount() {
      return viewers.size;
    },

    /**
     * Set fold level for all registered viewers.
     * @param {number} level - Fold level (0–10).
     */
    setFoldLevel(level) {
      const clamped = Math.max(0, Math.min(10, level));
      store.update((s) => ({ ...s, foldLevel: clamped }));
      saveFoldLevel(clamped);
      withScrollPreserved(() => {
        for (const viewer of viewers.values()) {
          try {
            viewer.foldToLevel(clamped);
          } catch (_) {}
        }
      });
    },

    /**
     * Get the current fold level.
     */
    getFoldLevel() {
      return get(store).foldLevel;
    },

    /**
     * Toggle whether PID is shown in log details.
     * @param {boolean} val
     */
    setShowDetailsPid(val) {
      store.update((s) => ({ ...s, showDetailsPid: val }));
      saveShowDetailsPid(val);
    },

    /**
     * Toggle whether Time is shown in log details.
     * @param {boolean} val
     */
    setShowDetailsTime(val) {
      store.update((s) => ({ ...s, showDetailsTime: val }));
      saveShowDetailsTime(val);
    },

    // ─── Type Filter API ──────────────────────────────────────────────────

    /**
     * Update the list of available types (derived from log items).
     * @param {string[]} types - Sorted unique type strings.
     */
    setAvailableTypes(types) {
      store.update((s) => ({ ...s, availableTypes: types }));
    },

    /**
     * Toggle a type's visibility. If currently hidden, show it; if visible, hide it.
     * @param {string} type
     */
    toggleType(type) {
      store.update((s) => {
        const idx = s.hiddenTypes.indexOf(type);
        let updated;
        if (idx >= 0) {
          updated = s.hiddenTypes.filter((t) => t !== type);
        } else {
          updated = [...s.hiddenTypes, type];
        }
        saveHiddenTypes(updated);
        return { ...s, hiddenTypes: updated };
      });
    },

    /**
     * Show all types (clear hiddenTypes).
     */
    showAllTypes() {
      store.update((s) => ({ ...s, hiddenTypes: [] }));
      saveHiddenTypes([]);
    },

    /**
     * Hide all types (set hiddenTypes to all availableTypes).
     */
    hideAllTypes() {
      const { availableTypes } = get(store);
      const all = [...availableTypes];
      store.update((s) => ({ ...s, hiddenTypes: all }));
      saveHiddenTypes(all);
    },

    // ─── PID Filter API ───────────────────────────────────────────────────

    /**
     * Add a PID to the include-filter list.
     * When filterPids is non-empty, only matching logs are shown.
     * @param {string} pid
     */
    addFilterPid(pid) {
      store.update((s) => {
        if (s.filterPids.includes(pid)) return s;
        return { ...s, filterPids: [...s.filterPids, pid] };
      });
    },

    /**
     * Remove a PID from the include-filter list.
     * @param {string} pid
     */
    removeFilterPid(pid) {
      store.update((s) => ({
        ...s,
        filterPids: s.filterPids.filter((p) => p !== pid),
      }));
    },

    /**
     * Clear all PID filters (show all PIDs again).
     */
    clearFilterPids() {
      store.update((s) => ({ ...s, filterPids: [] }));
    },

    // ─── Search API ───────────────────────────────────────────────────────

    /**
     * Search across all registered viewers.
     * @param {string} query - The search term.
     * @param {boolean} [caseSensitive] - Optional override; defaults to current state.
     */
    searchAll(query, caseSensitive) {
      const cs = caseSensitive ?? get(store).searchCaseSensitive;
      store.update((s) => ({ ...s, searchQuery: query, searchCaseSensitive: cs, searchActiveViewerId: null }));

      if (!query) {
        // Clear all viewers
        for (const viewer of viewers.values()) {
          try { viewer.clearSearch(); } catch (_) {}
        }
        store.update((s) => ({ ...s, searchTotalMatches: 0 }));
        return;
      }

      for (const viewer of viewers.values()) {
        try {
          viewer.search(query, { caseSensitive: cs, scroll: false });
        } catch (_) {}
      }
      recalcSearchMatches();
    },

    /**
     * Clear search across all viewers.
     */
    clearSearchAll() {
      for (const viewer of viewers.values()) {
        try { viewer.clearSearch(); } catch (_) {}
      }
      store.update((s) => ({
        ...s,
        searchQuery: "",
        searchTotalMatches: 0,
        searchActiveViewerId: null,
      }));
    },

    /**
     * Toggle case sensitivity and re-search.
     */
    toggleCaseSensitive() {
      const s = get(store);
      const newCs = !s.searchCaseSensitive;
      store.update((s) => ({ ...s, searchCaseSensitive: newCs }));
      if (s.searchQuery) {
        // Re-search with new case sensitivity
        for (const viewer of viewers.values()) {
          try {
            viewer.search(s.searchQuery, { caseSensitive: newCs, scroll: false });
          } catch (_) {}
        }
        recalcSearchMatches();
      }
    },

    /**
     * Navigate to the next search match across all viewers.
     * Moves within the current active viewer first, then advances to the next.
     */
    searchNext() {
      const { searchQuery, searchActiveViewerId } = get(store);
      if (!searchQuery) return;

      const ids = getViewerIds();
      if (ids.length === 0) return;

      // If no active viewer, find the first one with matches
      if (!searchActiveViewerId) {
        const firstId = findViewerWithMatches(null, 1);
        if (!firstId) return;
        const viewer = viewers.get(firstId);
        try {
          // Reset to first match
          const state = viewer.getSearchState();
          state.currentIndex = -1;
          const match = state.next();
          if (match) {
            viewer.render();
            this._scrollViewerMatchIntoView(firstId);
          }
        } catch (_) {}
        store.update((s) => ({ ...s, searchActiveViewerId: firstId }));
        return;
      }

      // Try advancing within current viewer
      const currentViewer = viewers.get(searchActiveViewerId);
      if (currentViewer) {
        try {
          const state = currentViewer.getSearchState();
          const currentIdx = state.getCurrentIndex();
          const matchCount = state.getMatchCount();

          if (currentIdx < matchCount - 1) {
            // More matches in this viewer
            state.next();
            currentViewer.render();
            this._scrollViewerMatchIntoView(searchActiveViewerId);
            return;
          }
        } catch (_) {}
      }

      // Move to next viewer with matches
      const nextId = findViewerWithMatches(searchActiveViewerId, 1);
      if (!nextId) return;
      const nextViewer = viewers.get(nextId);
      try {
        const state = nextViewer.getSearchState();
        state.currentIndex = -1;
        state.next();
        nextViewer.render();
        this._scrollViewerMatchIntoView(nextId);
      } catch (_) {}
      store.update((s) => ({ ...s, searchActiveViewerId: nextId }));
    },

    /**
     * Navigate to the previous search match across all viewers.
     */
    searchPrev() {
      const { searchQuery, searchActiveViewerId } = get(store);
      if (!searchQuery) return;

      const ids = getViewerIds();
      if (ids.length === 0) return;

      // If no active viewer, find the last one with matches
      if (!searchActiveViewerId) {
        const lastId = findViewerWithMatches(null, -1);
        if (!lastId) return;
        const viewer = viewers.get(lastId);
        try {
          const state = viewer.getSearchState();
          // Set to end so prev() wraps to last match
          state.currentIndex = state.getMatchCount();
          state.prev();
          viewer.render();
          this._scrollViewerMatchIntoView(lastId);
        } catch (_) {}
        store.update((s) => ({ ...s, searchActiveViewerId: lastId }));
        return;
      }

      // Try going back within current viewer
      const currentViewer = viewers.get(searchActiveViewerId);
      if (currentViewer) {
        try {
          const state = currentViewer.getSearchState();
          const currentIdx = state.getCurrentIndex();

          if (currentIdx > 0) {
            state.prev();
            currentViewer.render();
            this._scrollViewerMatchIntoView(searchActiveViewerId);
            return;
          }
        } catch (_) {}
      }

      // Move to previous viewer with matches
      const prevId = findViewerWithMatches(searchActiveViewerId, -1);
      if (!prevId) return;
      const prevViewer = viewers.get(prevId);
      try {
        const state = prevViewer.getSearchState();
        state.currentIndex = state.getMatchCount();
        state.prev();
        prevViewer.render();
        this._scrollViewerMatchIntoView(prevId);
      } catch (_) {}
      store.update((s) => ({ ...s, searchActiveViewerId: prevId }));
    },

    /**
     * Scroll the current search match of a viewer into the page viewport.
     * @private
     */
    _scrollViewerMatchIntoView(viewerId) {
      const viewer = viewers.get(viewerId);
      if (!viewer) return;
      // Let the viewer render, then scroll the highlight into view
      requestAnimationFrame(() => {
        try {
          const container = viewer.container;
          if (!container) return;
          // First scroll the viewer's own container to show the match
          viewer.scrollToCurrentMatch();
          // Then scroll the viewer container itself into the page viewport
          const matchEl = container.querySelector(".edv-search-current");
          if (matchEl) {
            matchEl.scrollIntoView({ block: "center", behavior: "smooth" });
          } else {
            container.scrollIntoView({ block: "center", behavior: "smooth" });
          }
        } catch (_) {}
      });
    },
  };
}

export const filterStore = createFilterStore();
