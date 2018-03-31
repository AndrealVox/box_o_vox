box_o_vox = {
   constants = require 'constants'
}
local log = radiant.log.create_logger('log')
log:error("Box o' Vox Server: Alpha 23 mod")

function box_o_vox:_on_required_loaded()
  local CustomGameCreationService = require('services.server.game_creation.game_creation_service')
    local GameCreationService = radiant.mods.require('stonehearth.services.server.game_creation.game_creation_service')
    radiant.mixin(GameCreationService, CustomGameCreationService)
end

radiant.events.listen_once(radiant,'radiant:required_loaded', box_o_vox, box_o_vox._on_required_loaded)

return box_o_vox