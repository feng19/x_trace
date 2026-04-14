import { writable } from "svelte/store";

function createStore() {
  const store = writable({
    disabled: true,
    selected: null,
    log: null,
    log_count: 0,
    auto_scroll: true,
    right_panel_show: true,
    setting_tab: "trace-settings",
    right_panel: null,
  });

  return {
    subscribe: store.subscribe,
    update: store.update,
    showSettingPanel: () => {
      store.update((store) => ({ ...store, right_panel_show: true }));
    },
    hideSettingPanel: () => {
      store.update((store) => ({ ...store, right_panel_show: false }));
    },
    setLogCount: (count) => {
      store.update((store) => ({ ...store, log_count: count }));
    },
    updateLogCount: (diff) => {
      store.update((store) => ({
        ...store,
        log_count: store.log_count + diff,
      }));
    },
    setSettingTab: (value) => {
      store.update((store) => ({ ...store, setting_tab: value }));
    },
    setRightPanel: (panel) => {
      store.update((store) => ({
        ...store,
        right_panel_show: true,
        right_panel: panel,
      }));
    },
    setLog: (log) => {
      if (log) {
        store.update((obj) => ({
          ...obj,
          auto_scroll: false,
          right_panel_show: true,
          selected: log.time,
          log: { ...log, details: null, details_loading: true },
        }));
      } else {
        store.update((obj) => ({ ...obj, auto_scroll: true, selected: null }));
      }
    },
    setLogDetails: (details) => {
      store.update((obj) => ({
        ...obj,
        log: obj.log ? { ...obj.log, details, details_loading: false } : obj.log,
      }));
    },
  };
}

export const dashboardStore = createStore();
