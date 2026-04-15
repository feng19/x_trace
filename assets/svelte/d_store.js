import { writable } from "svelte/store";

function createStore() {
  const store = writable({
    disabled: true,
    selected: null,
    log: null,
    log_count: 0,
    auto_scroll: true,
    setting_tab: "trace-settings",
  });

  return {
    subscribe: store.subscribe,
    update: store.update,
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
    setLog: (log) => {
      if (log) {
        store.update((obj) => ({
          ...obj,
          auto_scroll: false,
          selected: log.time,
        }));
      } else {
        store.update((obj) => ({ ...obj, auto_scroll: true, selected: null }));
      }
    },
  };
}

export const dashboardStore = createStore();
