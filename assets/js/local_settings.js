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
      if (this.select_index == -1) {
        console.log("new setting")
        this.items.push(settings)
        this.select_index = this.items.length - 1
      } else {
        console.log("replace setting")
        this.items[this.select_index] = settings
      }
      this.dump()
    })
  }
}

export default local_settings;