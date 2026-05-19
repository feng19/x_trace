<script>
  import { Input } from "$lib/components/ui/input";
  import { Label } from "$lib/components/ui/label/index.js";

  let { rate_limiting } = $props();

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

<div class="px-1 sm:px-2 space-y-4">
  <div class="rounded-md border bg-muted/50 px-3 py-2 text-xs sm:text-sm text-muted-foreground">
    {#if rate_limiting.milliseconds && rate_limiting.milliseconds !== ""}
      Rate-limiting at <strong class="text-foreground">{rate_limiting.max}</strong> messages per <strong class="text-foreground">{rate_limiting.milliseconds}</strong> milliseconds, instead of an absolute value.
    {:else}
      The limit was set to <strong class="text-foreground">{rate_limiting.max}</strong> trace message at most, and X-Trace let us know when that limit was reached.
    {/if}
  </div>

  <form id="max-settings" phx-change="set-rate-limiting" class="space-y-4">
    <div class="space-y-1.5">
      <Label for="max_input" class="text-xs sm:text-sm">Max</Label>
      <Input id="max_input" name="max" type="number" value={rate_limiting.max} min="1" max="1000" />
      <input
        type="range"
        min="10"
        max="1000"
        step="10"
        value={Math.round(rate_limiting.max / 10) * 10 || 10}
        oninput={handleSliderInput('max_input')}
        class="w-full h-1.5 rounded-full accent-primary cursor-pointer appearance-none bg-muted"
      />
    </div>

    <div class="space-y-1.5">
      <Label for="max_milliseconds_input" class="text-xs sm:text-sm">Milliseconds</Label>
      <Input id="max_milliseconds_input" name="milliseconds" type="number" value={rate_limiting.milliseconds} min="100" max="10000" />
      <input
        type="range"
        min="500"
        max="10000"
        step="500"
        value={Math.round((rate_limiting.milliseconds || 500) / 500) * 500 || 500}
        oninput={handleSliderInput('max_milliseconds_input')}
        class="w-full h-1.5 rounded-full accent-primary cursor-pointer appearance-none bg-muted"
      />
    </div>
  </form>
</div>
