<script>
  import { slide } from 'svelte/transition';
  import { Input } from "$lib/components/ui/input";
  import { Label } from "$lib/components/ui/label/index.js";
  import Info from "lucide-svelte/icons/info";

  export let rate_limiting;

  function handleSliderInput(targetId) {
    return function(e) {
      const input = document.getElementById(targetId);
      if (input) {
        const nativeSetter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
        nativeSetter.call(input, e.target.value);
        input.dispatchEvent(new Event('input', { bubbles: true }));
      }
    }
  }
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
  <form id="max-settings" phx-change="set-rate-limiting" class="grid grid-rows-2 gap-2 sm:gap-4">
    <div>
      <Label for="max_input" class="text-xs sm:text-sm">Max</Label>
      <Input id="max_input" name="max" type="number" value={rate_limiting.max} min="1" max="1000" />
      <input
        type="range"
        min="10"
        max="1000"
        step="10"
        value={Math.round(rate_limiting.max / 10) * 10 || 10}
        on:input={handleSliderInput('max_input')}
        class="w-full mt-1 h-2 accent-primary cursor-pointer"
      />
    </div>

    <div>
      <Label for="max_milliseconds_input" class="text-xs sm:text-sm">Milliseconds</Label>
      <Input id="max_milliseconds_input" name="milliseconds" type="number" value={rate_limiting.milliseconds} min="100" max="10000" />
      <input
        type="range"
        min="500"
        max="10000"
        step="500"
        value={Math.round((rate_limiting.milliseconds || 500) / 500) * 500 || 500}
        on:input={handleSliderInput('max_milliseconds_input')}
        class="w-full mt-1 h-2 accent-primary cursor-pointer"
      />
    </div>
  </form>
</div>
