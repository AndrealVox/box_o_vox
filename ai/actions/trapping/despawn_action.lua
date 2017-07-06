local despawn = class()

despawn.name = 'despawn'
despawn.does = 'stonehearth:idle:bored'
despawn.args = {
   hold_position = {    -- is the unit allowed to move around in the action?
      type = 'boolean',
      default = false,
   }
}
despawn.version = 2
despawn.priority = 1

-- despawn when all work is done and entity has nothing to do
function despawn:start_thinking(ai, entity, args)
   ai:set_think_output()
end

function despawn:run(ai, entity, args)
   ai:execute('stonehearth:destroy_entity')
end

return despawn
