local Entity = _radiant.om.Entity
local Point3 = _radiant.csg.Point3

local NinjaAttackByMovingToTargetableLocation = class()

NinjaAttackByMovingToTargetableLocation.name = 'NinjaAttack by moving to targetable location'
NinjaAttackByMovingToTargetableLocation.does = 'stonehearth:combat:attack'
NinjaAttackByMovingToTargetableLocation.args = {
   target = Entity
}
NinjaAttackByMovingToTargetableLocation.version = 2
NinjaAttackByMovingToTargetableLocation.priority = 3
NinjaAttackByMovingToTargetableLocation.weight = 1

local ai = stonehearth.ai

return ai:create_compound_action(NinjaAttackByMovingToTargetableLocation)
   :execute('stonehearth:combat:abort_on_leash_changed')
   :execute('stonehearth:combat:move_to_targetable_location', {
      target = ai.ARGS.target
   })
   :execute('stonehearth:bump_allies', {
      distance = 2,
   })
   :execute('box_o_vox:combat:execute_ninja_attack', {
      target = ai.ARGS.target,
   })
