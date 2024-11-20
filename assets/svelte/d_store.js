import { writable } from "svelte/store";

function createStore() {
  const store = writable({
    disabled: true,
    selected: null,
    log: null,
    log_count: 0,
    auto_scroll: true,
    right_panel_show: true,
    filter_panel_show: false,
    setting_tab: "trace-settings",
    right_panel: null,
    selected_map_filter: null,
    selected_record_filter: null,
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
    toggleFilterPanel: () => {
      store.update((store) => ({
        ...store,
        filter_panel_show: !store.filter_panel_show,
      }));
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
        selected_map_filter: null,
        selected_record_filter: null,
      }));
    },
    setSelectedMapFilter: (filter) => {
      store.update((store) => ({
        ...store,
        right_panel_show: true,
        right_panel: "map-filter",
        selected_map_filter: filter,
      }));
    },
    setSelectedRecordFilter: (filter) => {
      store.update((store) => ({
        ...store,
        right_panel_show: true,
        right_panel: "record-filter",
        selected_record_filter: filter,
      }));
    },
    setLog: (log) => {
      if (log) {
        store.update((obj) => ({
          ...obj,
          auto_scroll: false,
          right_panel_show: true,
          selected: log.time,
          log: log,
        }));
      } else {
        store.update((obj) => ({ ...obj, auto_scroll: true, selected: null }));
      }
    },
  };
}

export const dashboardStore = createStore();
