import { writable, get } from "svelte/store";
import { toast } from "svelte-sonner";

const SELECTED_ID_STORAGE_KEY = "x-trace-selected-setting-id";

function loadSelectedId() {
  try {
    return localStorage.getItem(SELECTED_ID_STORAGE_KEY) || null;
  } catch (_) {}
  return null;
}

function saveSelectedId(id) {
  try {
    if (id === null) {
      localStorage.removeItem(SELECTED_ID_STORAGE_KEY);
    } else {
      localStorage.setItem(SELECTED_ID_STORAGE_KEY, id);
    }
  } catch (_) {}
}

function createStore() {
  const store = writable({ selected: loadSelectedId(), items: [] });

  function validateSelected(items) {
    const { selected } = get(store);
    if (selected && !items.some((v) => v.id === selected)) {
      store.update((obj) => ({ ...obj, selected: null }));
      saveSelectedId(null);
    }
  }

  function load() {
    if (window.__TAURI__) {
      const { readTextFile, BaseDirectory } = window.__TAURI__.fs;
      readTextFile("settings.json", { baseDir: BaseDirectory.AppData }).then(
        (content) => {
          if (content.length > 0) {
            const items = JSON.parse(content);
            store.update((obj) => ({ ...obj, items }));
            validateSelected(items);
          }
        }
      );
    } else {
      let all_settings = localStorage.getItem("x-trace-settings");
      if (all_settings) {
        const items = JSON.parse(all_settings);
        store.update((obj) => ({ ...obj, items }));
        validateSelected(items);
      }
    }
  }

  function dump() {
    let content = JSON.stringify(get(store).items);
    if (window.__TAURI__) {
      const { writeTextFile, BaseDirectory } = window.__TAURI__.fs;
      writeTextFile("settings.json", content, {
        baseDir: BaseDirectory.AppData,
      });
    } else {
      localStorage.setItem("x-trace-settings", content);
    }
  }

  return {
    subscribe: store.subscribe,
    select: (id) => {
      console.log("select id:", id);
      store.update((obj) => ({ ...obj, selected: id }));
      saveSelectedId(id);
    },
    load: load,
    dump: dump,
    remove: (item) => {
      const { selected } = get(store);
      const newSelected = selected === item.id ? null : selected;
      store.update((obj) => ({
        ...obj,
        selected: newSelected,
        items: obj.items.filter((v) => v.id != item.id),
      }));
      if (newSelected !== selected) saveSelectedId(newSelected);
      dump();
    },
    append: (item) => {
      let { selected, items } = get(store);
      items = items.filter((v) => item.encoded !== v.encoded);
      item.saved_at = new Date().toISOString();
      store.update((obj) => ({
        ...obj,
        selected: item.id,
        items: [item, ...items],
      }));
      saveSelectedId(item.id);
      dump();
    },
    updateSelected: (item) => {
      let { selected, items } = get(store);
      if (!selected) return false;
      let index = items.findIndex((v) => v.id === selected);
      if (index === -1) return false;
      item.saved_at = new Date().toISOString();
      item.id = selected;
      // Preserve the name from the new item, keep the selected id
      items[index] = { ...items[index], ...item };
      store.update((obj) => ({
        ...obj,
        items: [...items],
      }));
      dump();
      return true;
    },
    download: () => {
      console.log("create setting file...");
      const link = document.createElement("a");
      const content = JSON.stringify(get(store).items);
      const file = new Blob([content], { type: "application/json" });
      link.href = URL.createObjectURL(file);
      const now = new Date();
      const ts = now.getFullYear().toString() +
        String(now.getMonth() + 1).padStart(2, "0") +
        String(now.getDate()).padStart(2, "0") + "_" +
        String(now.getHours()).padStart(2, "0") +
        String(now.getMinutes()).padStart(2, "0") +
        String(now.getSeconds()).padStart(2, "0");
      link.download = `xtrace_settings_${ts}.json`;
      link.click();
      URL.revokeObjectURL(link.href);
    },
    tauri_download: () => {
      const { save } = window.__TAURI__.dialog;
      save({
        filters: [{ name: "Json", extensions: ["json"] }],
      }).then((path) => {
        console.log(path);
        const { writeTextFile } = window.__TAURI__.fs;
        writeTextFile(path, JSON.stringify(get(store).items)).then(
          () => {
            toast.success("Saved");
          },
          () => {
            toast.error("Save Failed");
          }
        );
      });
    },
    import_file: (file) => {
      let reader = new FileReader();
      reader.onload = function () {
        // console.log("content:", this.result);
        let items = get(store).items;
        let import_items = JSON.parse(this.result);
        import_items.map((item) => {
          // console.log(item);
          let index = items.findIndex((x) => item.encoded === x.encoded);
          if (index == -1) {
            items = [item, ...items];
          }
        });
        store.update((obj) => ({ ...obj, items: items }));
        dump();
      };
      reader.readAsText(file);
    },
  };
}

export const settingsLocalStorage = createStore();
