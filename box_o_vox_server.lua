box_o_vox = {
   constants = require 'constants'
}
local log = radiant.log.create_logger('log')
log:error("Box o' Vox Server: Alpha 24 mod")

function box_o_vox:_on_required_loaded()    
    local BeeTrapper = require('jobs.trapper')
    local BeeTrappingGrounds = require('components.trapping.trapping_grounds_component')

    local CustomGameCreationService = require('services.server.game_creation.game_creation_service')
    local GameCreationService = radiant.mods.require('stonehearth.services.server.game_creation.game_creation_service')
    radiant.mixin(GameCreationService, CustomGameCreationService)
    
    local CustomHeightMapRenderer = require('services.server.world_generation.custom_height_map_renderer')
    local HeightMapRenderer = radiant.mods.require('stonehearth.services.server.world_generation.height_map_renderer')
    radiant.mixin(HeightMapRenderer, CustomHeightMapRenderer)
end

radiant.events.listen_once(radiant,'radiant:required_loaded', box_o_vox, box_o_vox._on_required_loaded)

return box_o_vox