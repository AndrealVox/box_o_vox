local Entity = _radiant.om.Entity
local Point3 = _radiant.csg.Point3

local NinjaAttackByPathingToTarget = class()

NinjaAttackByPathingToTarget.name = 'ninja attack by pathing to target'
NinjaAttackByPathingToTarget.does = 'stonehearth:combat:attack'
NinjaAttackByPathingToTarget.args = {
    target = Entity
}
NinjaAttackByPathingToTarget.version = 2
NinjaAttackByPathingToTarget.priority = 2
NinjaAttackByPathingToTarget.weight = 1

local ai = stonehearth.ai

return ai:create_compound_action(NinjaAttackByPathingToTarget)
   :execute('stonehearth:combat:abort_on_leash_changed')
   :execute('stonehearth:combat:chase_entity_until_targetable', {
      target = ai.ARGS.target
   })
   :execute('stonehearth:bump_allies', {
      distance = 2,
   })
    :execute('box_o_vox:combat:execute_ninja_attack', {
        target = ai.ARGS.target,
    })