local NinjaClass = class()
local CombatJob = require 'stonehearth.jobs.combat_job'

radiant.mixin(NinjaClass, CombatJob)

function NinjaClass:initialize()
    CombatJob.initialize(self)
end

return NinjaClass
