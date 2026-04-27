import { writable } from "svelte/store";

function createStore() {
  const store = writable({
    disabled: true,
    selected: null,
    log: null,
    log_count: 0,
    auto_scroll: true,
    expand_all: false,
    expanded_count: 0,
    setting_mode: false,
    selecting_mode: false,
    selected_log_times: new Set(),
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
    setExpandAll: (value) => {
      if (value) {
        store.update((s) => ({ ...s, expand_all: true }));
      } else {
        store.update((s) => ({
          ...s,
          expand_all: false,
          expanded_count: 0,
          selected: null,
          auto_scroll: true,
        }));
      }
    },
    setExpandedCount: (count) => {
      store.update((s) => ({ ...s, expanded_count: count }));
    },
    updateExpandedCount: (diff) => {
      store.update((s) => ({ ...s, expanded_count: s.expanded_count + diff }));
    },
    toggleSettingMode: () => {
      store.update((s) => ({ ...s, setting_mode: !s.setting_mode }));
    },
    setSettingMode: (value) => {
      store.update((s) => ({ ...s, setting_mode: value }));
    },
    setSelectingMode: (value) => {
      store.update((s) => ({
        ...s,
        selecting_mode: value,
        selected_log_times: value ? s.selected_log_times : new Set(),
      }));
    },
    toggleLogSelection: (time) => {
      store.update((s) => {
        const next = new Set(s.selected_log_times);
        if (next.has(time)) {
          next.delete(time);
        } else {
          next.add(time);
        }
        return { ...s, selected_log_times: next };
      });
    },
    selectAllLogs: (times) => {
      store.update((s) => ({
        ...s,
        selected_log_times: new Set(times),
      }));
    },
    deselectAllLogs: () => {
      store.update((s) => ({
        ...s,
        selected_log_times: new Set(),
      }));
    },
  };
}

export const dashboardStore = createStore();
