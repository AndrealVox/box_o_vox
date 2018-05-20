local FarmerClass = class()
local BaseJob = require 'jobs.base_job'
radiant.mixin(FarmerClass, BaseJob)

-- Farmers gain XP when they harvest things. The amount of XP depends on the crop
function FarmerClass:_create_listeners()
   self._on_harvest_listener = radiant.events.listen(self._sv._entity, 'stonehearth:harvest_crop', self, self._on_harvest)
end

function FarmerClass:_remove_listeners()
   if self._on_harvest_listener then
      self._on_harvest_listener:destroy()
      self._on_harvest_listener = nil
   end
end

function FarmerClass:_on_harvest(args)
   local crop = args.crop_uri
   local xp_to_add = self._xp_rewards["base_exp_per_harvest"]
   if self._xp_rewards[crop] then
      xp_to_add = self._xp_rewards[crop] 
   end
   self._job_component:add_exp(xp_to_add)
end
return FarmerClass
