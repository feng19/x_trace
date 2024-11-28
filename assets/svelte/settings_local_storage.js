import { writable, get } from "svelte/store";
import { toast } from "svelte-sonner";

function createStore() {
  const store = writable({ selected: null, items: [] });
  let dump = () => {
    localStorage.setItem("x-trace-settings", JSON.stringify(get(store).items));
  };

  return {
    subscribe: store.subscribe,
    select: (id) => {
      console.log("select id:", id);
      store.update((obj) => ({ ...obj, selected: id }));
    },
    load: () => {
      let all_settings = localStorage.getItem("x-trace-settings");
      if (all_settings) {
        store.update((obj) => ({ ...obj, items: JSON.parse(all_settings) }));
      }
    },
    dump: dump,
    remove: (item) => {
      store.update((obj) => ({
        ...obj,
        items: obj.items.filter((v) => v.id != item.id),
      }));
      dump();
    },
    append: (item) => {
      let { selected, items } = get(store);
      items = items.filter((v) => item.encoded !== v.encoded);
      store.update((obj) => ({
        ...obj,
        selected: item.id,
        items: [item, ...items],
      }));
      dump();
    },
    download: () => {
      console.log("create setting file...");
      const link = document.createElement("a");
      const content = JSON.stringify(get(store).items);
      const file = new Blob([content], { type: "application/json" });
      link.href = URL.createObjectURL(file);
      link.download = "x_trace_settings.json";
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
