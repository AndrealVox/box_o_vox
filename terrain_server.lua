box_o_vox = {}

function box_o_vox:_on_required_loaded()
	local custom_landscaper = require('services.server.world_generation.custom_landscaper')
	local landscaper = radiant.mods.require('stonehearth.services.server.world_generation.landscaper')
	radiant.mixin(landscaper, custom_landscaper)
end

radiant.events.listen_once(radiant, 'radiant:required_loaded', box_o_vox, box_o_vox._on_required_loaded)

return box_o_vox