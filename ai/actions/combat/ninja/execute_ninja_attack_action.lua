local AssaultContext = require 'stonehearth.services.server.combat.assault_context'
local BatteryContext = require 'stonehearth.services.server.combat.battery_context'
local Entity = _radiant.om.Entity
local Point3 = _radiant.csg.Point3
local rng = _radiant.math.get_default_rng()
local log = radiant.log.create_logger('combat')

local SECONDS_PER_GAMELOOP = 0.05

local ExecuteNinjaAttack = class()

ExecuteNinjaAttack.name = 'execute ninja_attack'
ExecuteNinjaAttack.does = 'stonehearth:combat:attack_melee_adjacent'
ExecuteNinjaAttack.args = {
    target = Entity,
    face_target = {
        type = 'boolean',
        default = true,
    }
}
ExecuteNinjaAttack.version = 2
ExecuteNinjaAttack.priority = 1
ExecuteNinjaAttack.weight = 1

function ExecuteNinjaAttack:start_thinking(ai, entity, args)
    local weapon = stonehearth.combat:get_main_weapon(entity)
    
    if not weapon or not weapon:is_valid() then
        return
    end
    
    self._weapon_data = radiant.entities.get_entity_data(weapon, 'stonehearth:combat:weapon_data')
    self._equipment_data = stonehearth.combat:get_equipment_data(entity, 'box_o_vox:ninja_equipment_data')
    
    self._ninja_attack_types = stonehearth.combat:get_combat_actions(entity, 'box_o_vox:combat:ninja_attacks')
    self._ninja_speed = entity:get_component('stonehearth:attributes'):get_attribute('speed')
    
    if not next(self._ninja_attack_types) then
        -- no ninja_attack types
        log:error('no ninja_attacks types')
        return
    end
    self._mob = entity:add_component('mob')
    self._target = args.target
    self._ai = ai
    self:_get_projectile_offsets(self._weapon_data)
    self:_choose_ninja_attack_action(ai, entity, args)
end

function ExecuteNinjaAttack:_choose_ninja_attack_action(ai, entity, args)
    
    self._ninja_attack_info = stonehearth.combat:choose_attack_action(entity, self._ninja_attack_types)
    
    if self._ninja_attack_info then
        ai:set_think_output()
        return true
    end
    
    self._think_timer = stonehearth.combat:set_timer("ExecuteNinjaAttack waiting for cooldown", 1000,
    function()
        self._think_timer = nil
        self:_choose_ninja_attack_action(ai, entity, args)
        end)
end

function ExecuteNinjaAttack:stop_thinking(ai, entity, args)
    if self._think_timer then
        self._think_timer:destroy()
        self._think_timer = nil
    end
    
    self._ninja_attack_types = nil
end

function ExecuteNinjaAttack:run(ai, entity, args)
    local target = args.target
    ai:set_status_text_key('box_o_vox:ai.action.status_text.ninja_attacking', {target = target})
    
    
    if radiant.entities.is_standing_on_ladder(entity) then
        ai:abort('Cannot ninja_attack while standing on ladder')
    end
    
    local weapon = stonehearth.combat:get_main_weapon(entity)
    if not weapon or not weapon:is_valid() then
        log:warning('%s no longer has valid weapon')
        ai:abort('ninja_attacker no longer has a valid weapon')
    end
    
    local ninja_range_ideal = self._ninja_attack_info.range
    local ninja_range_max = ninja_range_ideal+1.1
    log:error('%s, %s ninja attack range', self._ninja_attack_info.range, ninja_range_ideal)
    local distance = radiant.entities.distance_between(entity, target)
        log:error('%s distance', distance)
    if  distance > ninja_range_max then 
        log:warning('%s unable to get within maximum range (%f) of %s', entity, ninja_range_ideal, target)
        ai:abort('Target out of range')
        return
    end
    if args.face_target then
        radiant.entities.turn_to_face(entity, target)
    end
    
    ai:execute('stonehearth:bump_against_entity', {entity = target, distance = distance})
    log:error('bumb radius %s', ninja_range_ideal)
    
    stonehearth.combat:start_cooldown(entity, self._ninja_attack_info)
    
    ai:unprotect_argument(target)
    
    self._attack_timers = {}
    if self._ninja_attack_info.impact_times then
        for _, time in ipairs(self._ninja_attack_info.impact_times) do
            self:_add_attack_timer(entity, target, time)
        end
    else
        self:_add_attack_timer(entity, target, self._ninja_attack_info.time_to_impact)
    end
    
 
   ai:execute('stonehearth:run_effect', { effect = self._ninja_attack_info.effect })

end

function ExecuteNinjaAttack:_apply_aoe_damage(attacker, original_target_id, melee_range_max)
   local aggro_table = attacker:add_component('stonehearth:target_tables')
                                       :get_target_table('aggro')

   if not aggro_table then
      return
   end

   local aoe_target_limit = self._ninja_attack_info.aoe_target_limit or 10

   local aoe_range = self._ninja_attack_info.aoe_range or self._ninja_attack_info.range
   local num_targets = 0
   local aoe_attack_info = self._ninja_attack_info.aoe_effect
   for id, entry in pairs(aggro_table:get_entries()) do
      if id ~= original_target_id then
         -- only apply aoe to targets that aren't the original target
         local target = entry.entity
         if target and target:is_valid() then -- targets can be invalid in the aggro table.
            local distance = radiant.entities.distance_between(attacker, target)
            if distance <= aoe_range then
               local total_damage = stonehearth.combat:calculate_melee_damage(attacker, target, aoe_attack_info)
               local aggro_override = stonehearth.combat:calculate_aggro_override(total_damage, aoe_attack_info)
               local battery_context = BatteryContext(attacker, target, total_damage, aggro_override)
               stonehearth.combat:inflict_debuffs(attacker, target, aoe_attack_info)
               stonehearth.combat:battery(battery_context)
               num_targets = num_targets + 1
            end
            if num_targets >= aoe_target_limit then
               break
            end
         end
      end
   end
end
function ExecuteNinjaAttack:stop(ai, entity, args)
    if self._ninja_attack_impact_timer then
        self._ninja_attack_impact_timer:destroy()
        self._ninja_attack_impact_timer = nil
    end
    self:destroy_ninja_attack_effect()
end

function ExecuteNinjaAttack:_add_attack_timer(entity, target, time_to_attack)
   local attack_timer = stonehearth.combat:set_timer("NinjaAttack", time_to_attack, function()
      self:_attack(entity, target, self._ninja_attack_info)

   end)
   table.insert(self._attack_timers, attack_timer)
end


function ExecuteNinjaAttack:destroy_ninja_attack_effect()
    if self._in_progress_ninja_attack then
        self._in_progress_ninja_attack:stop()
        self._in_progress_ninja_attack = nil
    end
end

function ExecuteNinjaAttack:_attack(attacker, target, skill_info)
    if not target:is_valid() then
        return
    end
    if skill_info.range > 5 then
        self:_ranged_attack(attacker, target, self._weapon_data)
        return
    else   
        if self._gameloop_trace then
            return
        end
       local vector = self:_get_vector_to_target(target)
       self._gameloop_trace = radiant.on_game_loop('ninja combat movement', function()
             if not self._target:is_valid() then
               return
             end

             local vector = self:_get_vector_to_target(target)
             local distance = vector:length()
             local move_distance = self:_get_distance_per_gameloop(self._ninja_speed)

             -- projectile moves speed units every gameloop
             if distance <= move_distance then
                self:_destroy_gameloop_trace()
                return
             end

         vector:normalize()
         vector:scale(move_distance)

         local ninja_location = self._mob:get_world_location()
         local new_ninja_location = ninja_location + vector

         self._mob:move_to(new_ninja_location)
      end)
        
        local impact_time = radiant.gamestate.now() --+ self._ninja_attack_info.time_to_impact
        self._assault_context = AssaultContext('melee', attacker, target, impact_time)
        stonehearth.combat:begin_assault(self._assault_context)

   -- can't ai:execute this. it needs to run in parallel with the attack animation
        self._hit_effect = radiant.effects.run_effect(
            target, 'stonehearth:effects:hit_sparks:hit_effect', self._ninja_attack_info.time_to_impact)
        vector = self:_get_vector_to_target(target)
        local distance_to_target = vector:length()
        
         local out_of_range = distance_to_target <= self._ninja_attack_info.range

         if out_of_range or self._assault_context.target_defending then
            self._hit_effect:stop()
            self._hit_effect = nil
         else

            local total_damage = stonehearth.combat:calculate_melee_damage(attacker, target, self._ninja_attack_info)
            local target_id = target:get_id()
            local aggro_override = stonehearth.combat:calculate_aggro_override(total_damage, self._ninja_attack_info)
            local battery_context = BatteryContext(attacker, target, total_damage, aggro_override)

            stonehearth.combat:inflict_debuffs(attacker, target, self._ninja_attack_info)
            stonehearth.combat:battery(battery_context)

            if self._ninja_attack_info.aoe_effect then
               self:_apply_aoe_damage(attacker, target_id, self._ninja_attack_info.range, self._ninja_attack_info)
            end
         end
    end

   stonehearth.combat:end_assault(self._assault_context)
   self._assault_context = nil
end


function ExecuteNinjaAttack:_ranged_attack(attacker, target, weapon_data)
   if not target:is_valid() then
      return
   end

   local projectile_speed = 30
   assert(projectile_speed)
   local projectile = self:_create_ninja_star(attacker, target)
   local projectile_component = projectile:add_component('stonehearth:projectile')
   local flight_time = projectile_component:get_estimated_flight_time()
   local impact_time = radiant.gamestate.now() + flight_time

   local assault_context = AssaultContext('melee', attacker, target, impact_time)
   stonehearth.combat:begin_assault(assault_context)

   -- save this because it will live on in the closure after the shot action has completed
   local attack_info = self._ninja_attack_info

   local impact_trace
   impact_trace = radiant.events.listen(projectile, 'stonehearth:combat:projectile_impact', function()
         if projectile:is_valid() and target:is_valid() then
            if not assault_context.target_defending then
               radiant.effects.run_effect(target, 'stonehearth:effects:hit_sparks:hit_effect')
               local total_damage = stonehearth.combat:calculate_ranged_damage(attacker, target, attack_info)
               local battery_context = BatteryContext(attacker, target, total_damage)
               stonehearth.combat:inflict_debuffs(attacker, target, attack_info)
               stonehearth.combat:battery(battery_context)
            end
         end

         if assault_context then
            stonehearth.combat:end_assault(assault_context)
            assault_context = nil
         end

         if impact_trace then
            impact_trace:destroy()
            impact_trace = nil
         end
      end)

   local destroy_trace
   destroy_trace = radiant.events.listen(projectile, 'radiant:entity:pre_destroy', function()
         if assault_context then
            stonehearth.combat:end_assault(assault_context)
            assault_context = nil
         end

         if destroy_trace then
            destroy_trace:destroy()
            destroy_trace = nil
         end
      end)
end


function ExecuteNinjaAttack:_create_ninja_star(attacker, target)-- default ninja_attack is ninja star
    local projectile_uri = 'box_o_vox:weapon:ninja_star' 
    local projectile_speed = 30
   -- default projectile is an arrow
   local projectile = radiant.entities.create_entity(projectile_uri, { owner = attacker })
   local projectile_component = projectile:add_component('stonehearth:projectile')
   projectile_component:set_speed(projectile_speed)
   projectile_component:set_target_offset(self._target_offset)
   projectile_component:set_target(target)

   local projectile_origin = self:_get_world_location(self._attacker_offset, attacker)
   radiant.terrain.place_entity_at_exact_location(projectile, projectile_origin)

   projectile_component:start()
   return projectile
end

function ExecuteNinjaAttack:_get_world_location(point, entity)
   local mob = entity:add_component('mob')
   local facing = mob:get_facing()
   local entity_location = mob:get_world_location()

   local offset = radiant.math.rotate_about_y_axis(point, facing)
   local world_location = entity_location + offset
   return world_location
end

function ExecuteNinjaAttack:_get_projectile_offsets(weapon_data, entity)
   self._attacker_offset = Point3(0, 0, 0) -- default numbers that match well with bows on humanoids
   self._target_offset = Point3(0, 0, 0)

   if not weapon_data then
      return
   end

   local projectile_start_offset = self._weapon_data.projectile_start_offset
   local projectile_end_offset = self._weapon_data.projectile_end_offset
   -- Get start and end offsets from weapon data if provided
   if projectile_start_offset then
      self._attacker_offset = Point3(projectile_start_offset.x,
                                     projectile_start_offset.y,
                                     projectile_start_offset.z)
   end
   if projectile_end_offset then
      self._target_offset = Point3(projectile_end_offset.x,
                                     projectile_end_offset.y,
                                     projectile_end_offset.z)
   end
end
function ExecuteNinjaAttack:_get_vector_to_target(target)
   local ninja_location = self._mob:get_world_location()
    if not self._target_location_first_check then
        self._target_location_first_check = target:add_component('mob'):get_world_location()
    else
        self._target_location_second_check = target:add_component('mob'):get_world_location()
        if self._target_location_second_check ~= self._target_location_first_check then
            self._target_location_first_check = self._target_location_second_check
        end
    end
        
   local target_point = self._target_location_first_check + self._target_offset
   local vector = target_point - ninja_location
    log:error("%s vector", vector)
   return vector
end

function ExecuteNinjaAttack:_get_distance_per_gameloop(speed)
   local game_speed = stonehearth.game_speed:get_game_speed()
   local distance = speed * SECONDS_PER_GAMELOOP * game_speed
   return distance
end

function ExecuteNinjaAttack:_destroy_gameloop_trace()
   if self._gameloop_trace then
      self._gameloop_trace:destroy()
      self._gameloop_trace = nil
   end
end


return ExecuteNinjaAttack