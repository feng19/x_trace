<script>
  import { onMount } from 'svelte';
  import { toast } from "svelte-sonner";

  let { content } = $props();
  let textarea;

  onMount(() => {
    textarea.select();
    document.execCommand('copy');
    toast.success('Copied');
  });
</script>

<textarea bind:value={content} bind:this={textarea}></textarea>
