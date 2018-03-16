local AlchemistClss = class()
local CombatJob = require 'stonehearth.jobs.combat_job'
local CraftingJob = require 'stonehearth.jobs.crafting_job'
radiant.mixin(AlchemistClass, CombatJob)
radiant.mixin(AlchemistClass, CraftingJob)
return AlchemistClass