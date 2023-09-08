import {FitAddon} from "../vendor/xterm-addon-fit"

const xterm_hook = {
  mounted() {
    let hook = this
    let term = new Terminal({
      lineHeight: 1.2,
      disableStdin: true,
      cursorBlink: true,
      cursorStyle: 'underline',
      fontSize: 16,
      fontFamily: '"Menlo for Powerline", Menlo, Consolas, "Liberation Mono", Courier, monospace'
    })
    const fitAddon = new FitAddon()
    term.loadAddon(fitAddon)
    term.open(this.el)

    fitAddon.fit()
    cc.pushEvent("term-cols", {cols: term.cols})

    term.focus()
    window.term = term
    window.addEventListener("resize", () => {
      fitAddon.fit()
      cc.pushEvent("term-cols", {cols: term.cols})
    })

    this.handleEvent("outputs", function(e) {
      let data = e.data
      // console.log(data)
      if (data && data.indexOf('\n') !== -1) {
        if (data.endsWith('\n')) {
          data.slice(0, data.length - 1).split('\n').forEach(value => term.writeln(value));
        } else {
          data.split('\n').forEach(value => term.writeln(value));
        }
      } else {
        term.writeln(data)
      }
    })
    this.handleEvent("clear", _e => term.clear())

    this.handleEvent("download", function(_e) {
      term.selectAll()
      let text = term.getSelection().trim()
      term.clearSelection()
      const file = new File([text], "x_trace.log", {type: "text/plain"});
      download(file)
    })
  }
};

function download(downfile) {
  const tmpLink = document.createElement("a")
  const objectUrl = URL.createObjectURL(downfile)

  tmpLink.href = objectUrl
  tmpLink.download = downfile.name
  document.body.appendChild(tmpLink)
  tmpLink.click()

  document.body.removeChild(tmpLink)
  URL.revokeObjectURL(objectUrl)
}

export default xterm_hook;