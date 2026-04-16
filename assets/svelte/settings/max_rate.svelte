<script>
  import { slide } from 'svelte/transition';
  import { Input } from "$lib/components/ui/input";
  import { Label } from "$lib/components/ui/label/index.js";
  import Info from "lucide-svelte/icons/info";

  export let rate_limiting;
</script>

<div class="px-1 sm:px-2">
  {#if rate_limiting.milliseconds && rate_limiting.milliseconds !== "" }
  <pre class="text-wrap text-xs sm:text-sm" transition:slide={{duration: 200}}>
  Rate-limiting at {rate_limiting.max} messages per {rate_limiting.milliseconds} milliseconds, instead of an absolute value.
  </pre>
  {:else}
  <pre class="text-wrap text-xs sm:text-sm" transition:slide={{duration: 200}}>
  The limit was set to {rate_limiting.max} trace message at most, and X-Trace let us know when that limit was reached.
  </pre>
  {/if}
  <form id="max-settings" phx-change="set-rate-limiting" class="grid grid-cols-2 gap-2 sm:gap-4">
    <div>
      <Label for="max_input" class="text-xs sm:text-sm">Max</Label>
      <Input id="max_input" name="max" type="number" value={rate_limiting.max} min="1" max="1000" />
    </div>

    <div>
      <Label for="max_milliseconds_input" class="text-xs sm:text-sm">Milliseconds</Label>
      <Input id="max_milliseconds_input" name="milliseconds" type="number" value={rate_limiting.milliseconds} min="100" max="10000" />
    </div>
  </form>
</div>
