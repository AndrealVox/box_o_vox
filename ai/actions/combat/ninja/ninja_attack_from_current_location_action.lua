local Entity = _radiant.om.Entity

local NinjaAttackFromCurrentLocation = class()

NinjaAttackFromCurrentLocation.name = 'ninja attack from current location'
NinjaAttackFromCurrentLocation.does = 'stonehearth:combat:attack'
NinjaAttackFromCurrentLocation.args = {
    target = Entity
}
NinjaAttackFromCurrentLocation.version = 2
NinjaAttackFromCurrentLocation.priority = 4
NinjaAttackFromCurrentLocation.weight = 1

local ai = stonehearth.ai
return ai:create_compound_action(NinjaAttackFromCurrentLocation)
    :execute('stonehearth:combat:check_entity_targetable', {
        target = ai.ARGS.target,
    })
    :execute('stonehearth:bump_allies', {
        distance = 2,
    })
    :execute('box_o_vox:combat:execute_ninja_attack',{
        target = ai.ARGS.target,
    })