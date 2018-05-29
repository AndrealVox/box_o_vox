local TrapperClass = require 'stonehearth.jobs.trapper'

function TrapperClass:should_tame(target)
  if target:get_uri() == "box_o_vox:bee" then
    return false
  end
  if not self:has_perk('trapper_natural_empathy_1') then
     -- If no charm pet perk, then remove
     return false
  end

  local trapper = self._sv._entity
  local num_pets = trapper:add_component('stonehearth:pet_owner'):num_pets()
  local max_num_pets = 1
  local attributes = trapper:get_component('stonehearth:attributes')
  if attributes then
     local compassion = attributes:get_attribute('compassion')
     if compassion >= stonehearth.constants.attribute_effects.COMPASSION_TRAPPER_TWO_PETS_THRESHOLD then
        max_num_pets = 2
     end
  end

  if num_pets >= max_num_pets then
     return false
  end

  -- percentage chance to tame the pet.
  local percent = rng:get_int(1, 100)
  if percent > self._sv._tame_beast_percent_chance then
     return false
  end

  return true
end

return TrapperClass