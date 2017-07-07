box_o_vox = {}
local player_service_trace = nil

local function check_override_ui(players, player_id)
   -- Load ui mod
   if not player_id then
      player_id = 'player_1' -- TODO(Yshan) client should know what player id it is
   end
   
   local client_player = players[player_id]
   if client_player then
      if client_player.kingdom == "rayyas_children:kingdoms:rayyas_children" then
         -- hot load rayyas children ui mod
         --_radiant.res.apply_manifest("/box_o_vox/manifest.json")
		 client_player.kingdom = "stonehearth:kingdoms:ascendancy"
      end
   end
end

local function trace_player_service()
   _radiant.call('stonehearth:get_service', 'player')
      :done(function(r)
         local player_service = r.result
         check_override_ui(player_service:get_data().players)
         player_service_trace = player_service:trace('rayyas children ui change')
               :on_changed(function(o)
                     check_override_ui(player_service:get_data().players)
                  end)
         end)
end

radiant.events.listen(box_o_vox, 'radiant:init', function()
      trace_player_service()
   end)

return box_o_vox
