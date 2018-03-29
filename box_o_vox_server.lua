box_o_vox = {
   constants = require 'constants'
}
local log = radiant.log.create_logger('log')
log:error("Box o' Vox Server: Alpha 23 mod")

function box_o_vox:_on_required_loaded()
  --[[  local CustomPortraitRendererService = require('services.client.portrait_renderer.portrait_renderer_service')
    local PortraitRendererService = radiant.mods.require('stonehearth.services.client.portrait_renderer.portrait_renderer_service')
    radiant.mixin(PortraitRendererService, CustomPortraitRendererService)
    --]]
end

radiant.events.listen_once(radiant,'radiant:required_loaded', box_o_vox, box_o_vox._on_required_loaded)

return box_o_vox