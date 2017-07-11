local constants = require 'constants'
local Entity = _radiant.om.Entity

local NinjaAttackAfterCooldown = class()
NinjaAttackAfterCooldown.name = 'NinjaAttack after cooldown'
NinjaAttackAfterCooldown.does = 'stonehearth:combat:attack_after_cooldown'
NinjaAttackAfterCooldown.args = {
    target = Entity
}
NinjaAttackAfterCooldown.version = 2
NinjaAttackAfterCooldown.priority = 1

local ai = stonehearth.ai
return ai:create_compound_action(NinjaAttackAfterCooldown)
    :execute('stonehearth:combat:wait_for_global_attack_cooldown')
    :execute('stonehearth:combat:attack', {target = ai.ARGS.target })