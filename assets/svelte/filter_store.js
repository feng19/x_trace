import { writable, get } from "svelte/store";

const STORAGE_KEY = "x-trace-filter-keys";

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

/**
 * Global filter store for ElixirDataViewer key filtering.
 *
 * Manages:
 * - filteredKeys: keys currently hidden across all viewers
 * - availableKeys: all detected keys from all registered viewers
 * - viewers: Map of registered ElixirDataViewer instances
 */
function createFilterStore() {
  const store = writable({
    filteredKeys: loadFilteredKeys(),
    availableKeys: [],
  });

  // Internal viewer registry (not reactive — no need to trigger UI updates)
  const viewers = new Map();

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

  function syncAllViewers() {
    const { filteredKeys } = get(store);
    for (const viewer of viewers.values()) {
      try {
        viewer.setFilterKeys(filteredKeys);
      } catch (_) {
        // viewer may have been destroyed
      }
    }
  }

  return {
    subscribe: store.subscribe,

    /**
     * Register an ElixirDataViewer instance. Merges its available keys
     * and applies the current filter.
     */
    registerViewer(id, viewer) {
      viewers.set(id, viewer);
      rebuildAvailableKeys();
      // Apply current filter to the new viewer
      const { filteredKeys } = get(store);
      if (filteredKeys.length > 0) {
        try {
          viewer.setFilterKeys(filteredKeys);
        } catch (_) {}
      }
    },

    /**
     * Unregister a viewer (e.g., when its DOM node is destroyed).
     */
    unregisterViewer(id) {
      viewers.delete(id);
      rebuildAvailableKeys();
    },

    /**
     * Refresh available keys from a specific viewer (e.g., after content change).
     */
    refreshViewer(id, viewer) {
      viewers.set(id, viewer);
      rebuildAvailableKeys();
      // Re-apply filter to updated viewer
      const { filteredKeys } = get(store);
      if (filteredKeys.length > 0) {
        try {
          viewer.setFilterKeys(filteredKeys);
        } catch (_) {}
      }
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
      for (const viewer of viewers.values()) {
        try {
          viewer.clearFilter();
        } catch (_) {}
      }
    },

    /**
     * Get the number of registered viewers.
     */
    getViewerCount() {
      return viewers.size;
    },
  };
}

export const filterStore = createFilterStore();
