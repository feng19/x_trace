<script>
  import { Toaster } from "$lib/components/ui/sonner";
  import { toast } from "svelte-sonner";

  export let live;

  live.handleEvent("flash", (e) => {
    opts = {description: e.description}
    switch(e.kind) {
      case 'info':
        toast.info(e.msg, opts);
        break;
      case 'success':
        toast.success(e.msg, opts);
        break;
      case 'warning':
        toast.warning(e.msg, opts);
        break;
      case 'error':
        toast.error(e.msg, opts);
        break;
    }
  })

  live.disconnected = () => {
    if (live.liveSocket.isConnected()) {
      toast.error("Something went wrong!", {
        description: "Hang in there while we get back on track",
        duration: Infinity
      });
    } else {
      toast.error("We can't find the internet", {
        description: "Attempting to reconnect",
        duration: Infinity
      });
    }
  }

  live.reconnected = () => {
    toast.dismiss();
    toast.info("reconnected");
  }
</script>

<Toaster richColors closeButton />