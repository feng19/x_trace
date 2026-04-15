<script>
  import SettingPanel from "./setting_panel.svelte";
  import ControlNav from "./control_nav.svelte";
  import { dashboardStore } from "./d_store.js";
  import { Separator } from "$lib/components/ui/select";

  export let live;
  export let op_status;
  export let settings = {};
</script>

<div class="sticky top-0 z-49 bg-white">
  <div class="px-2 h-[52px] flex items-center gap-2">
    <ControlNav {live} {op_status} isCollapsed side="bottom" />
  </div>
  <Separator />
</div>
<SettingPanel {live} {...settings} />
