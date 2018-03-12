local CraftingJob = require 'stonehearth.jobs.crafting_job'

local BotanistClass = class()
radiant.mixin(BotanistClass, CraftingJob)

return BotanistClass