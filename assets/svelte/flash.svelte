<script>
  import { Toaster } from "$lib/components/ui/sonner";
  import { toast } from "svelte-sonner";
  import { onMount } from "svelte";

  let { live } = $props();

  onMount(() => {
    live.handleEvent("flash", (e) => {
      switch (e.kind) {
        case "info":
          toast.info(e.msg);
          break;
        case "success":
          toast.success(e.msg);
          break;
        case "warning":
          toast.warning(e.msg);
          break;
        case "error":
          toast.error(e.msg);
          break;
      }
    });

    live.disconnected = () => {
      if (live.liveSocket.isConnected()) {
        toast.error("Something went wrong!", {
          description: "Hang in there while we get back on track",
          duration: Infinity,
        });
      } else {
        toast.error("We can't find the internet", {
          description: "Attempting to reconnect",
          duration: Infinity,
        });
      }
    };

    live.reconnected = () => {
      toast.dismiss();
      toast.info("reconnected");
    };
  });
</script>

<Toaster richColors closeButton />
