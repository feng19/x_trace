const local_settings = {
  select_index: -1,
  items: [],
  init() {
    let all_settings = localStorage.getItem('x-trace-settings')
    // console.log(all_settings)

    if (all_settings) {
      let items = JSON.parse(all_settings)
      this.items = items
    }

    document.getElementById("ls-upload").addEventListener("change", (event) => {
      let input = event.target
      if(input.files.length) {
        console.log("import settings files:", input.files)
        this.import_settings(input.files[0])
      }
      input.value = ""
    }, true)
  },
  dump() {
    localStorage.setItem('x-trace-settings', JSON.stringify(this.items))
  },
  remove(index) {
    console.log("remove", index)
    this.items = this.items.filter((_v, i) => i != index)
    this.select_index = -1
    this.dump()
  },
  select(index) {
    if (this.select_index == index) {
      console.log("unselect index:", index)
      this.select_index = -1
    } else {
      console.log("select index:", index)
      this.select_index = index
    }
  },
  apply(index) {
    console.log("apply index:", index)
    this.select_index = index
    cc.pushEvent('apply-settings', this.items[index].data)
  },
  save_current_setting() {
    cc.pushEvent('save-settings', {}, (settings) => {
      console.log("save-settings", settings)
      let item_node
      if (this.select_index == -1) {
        let old_index = this.items.findIndex((item) => item.data === settings.data)
        console.log("old_index:", old_index)
        if (old_index != -1) {
          console.log("duplicate setting, index:", this.select_index)
          this.select_index = old_index
          item_node = document.getElementById("ls-" + this.select_index)
        } else {
          console.log("new setting, index:", this.select_index)
          this.items.push(settings)
          this.select_index = this.items.length - 1
          item_node = document.getElementById("bottom-panel")
        }
      } else {
        console.log("replace setting, index:", this.select_index)
        this.items[this.select_index] = settings
        item_node = document.getElementById("ls-" + this.select_index)
      }
      this.dump()
      let wrapper = document.getElementById("menu")
      wrapper.scrollTo(0, item_node.offsetTop)
    })
  },
  download_settings() {
    console.log("create setting file...")
    const link = document.createElement("a")
    const content = JSON.stringify(this.items)
    const file = new Blob([content], { type: 'application/json' })
    link.href = URL.createObjectURL(file)
    link.download = "x_trace_settings.json"
    link.click()
    URL.revokeObjectURL(link.href)
  },
  import_settings(file) {
    let hook = this
    let reader = new FileReader()
    reader.onload = function() {
      // console.log("content:", this.result)
      let items = JSON.parse(this.result)
      items.map((item) => {
        let index = hook.items.findIndex((x) => item.data === x.data)
        if (index == -1) {
          hook.items.push(item)
        }
      })
      hook.dump()
    }
    reader.readAsText(file)
  }
}

export default local_settings;