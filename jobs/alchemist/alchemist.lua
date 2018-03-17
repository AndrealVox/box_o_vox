
local CombatJob = require 'stonehearth.jobs.combat_job'
local CraftingJob = require 'stonehearth.jobs.crafting_job'

local AlchemistClass = class()
radiant.mixin(AlchemistClass, CombatJob)
radiant.mixin(AlchemistClass, CraftingJob)

--- Public functions, required for all classes

function AlchemistClass:initialize()
   CraftingJob.initialize(self)
   self._sv._accumulated_town_protection_time = 0
end

--Always do these things
function AlchemistClass:activate()
   CombatJob.activate(self)
   CraftingJob.activate(self)
end

-- Call when it's time to promote someone to this class
function AlchemistClass:promote(json_path)
   CombatJob.promote(self, json_path)
   local crafter_component = self._sv._entity:add_component("stonehearth:crafter")
   crafter_component:set_json(self._job_json.crafter)
   self.__saved_variables:mark_changed()
end

function AlchemistClass:_create_listeners()
   CraftingJob._create_listeners(self)
   CombatJob._create_listeners(self)
end

function AlchemistClass:_remove_listeners()
    
   CraftingJob._remove_listeners(self)
   CombatJob._remove_listeners(self)
end


-- Call when it's time to demote
function AlchemistClass:demote()
   CombatJob.demote(self)
   CraftingJob.demote(self)
end

-- Called when destroying this entity
-- Note we could get destroyed without being demoted
-- So remove ourselves from town just in case
function AlchemistClass:destroy()
   CombatJob.destroy(self)
   CraftingJob.destroy(self)
end

return AlchemistClass