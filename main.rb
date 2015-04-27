require "./fleetgirl"

def good_night
    yume = FleetGirl.new
    yume.login

    r = yume.get "api/initData"
    repair_dock = r["repairDockVo"]

    ships = yume.get_damaged_ships(r)
    explore_info = r["pveExploreVo"]["levels"]
    free_fleets = yume.explore_plan.keys - explore_info.map { |x| x["fleetId"].to_i }
    
    free_fleets.each do |fleet_id|
        r = yume.explore_start fleet_id
        explore_info = r["pveExploreVo"]["levels"]
    end

    while true
        explore_info.dup.each do |x|
            if x["endTime"] < Time.now.to_i
                r = yume.explore_end x["fleetId"].to_i, x["exploreId"]
                r = yume.explore_start x["fleetId"].to_i
                explore_info = r["pveExploreVo"]["levels"]
            end
        end

        repair_dock.dup.each do |dock|
            break if ships.empty?
            next if dock["locked"] == 1
            if dock["endTime"].nil? or dock["endTime"] < Time.now.to_i
                r = yume.repair_end dock["shipId"], dock["id"] if dock.has_key? "shipId"
                r = yume.repair_start ships.shift, dock["id"]
                repair_dock = r["repairDockVo"]
            end
        end
        sleep 30
    end
end

def try_combat
    yume = FleetGirl.new
    yume.login
    #yume.combat_by_path 1, 304, ["A", "C", "E", "I", "J"], [3, 3, 3, 3, 1]
    while yume.hevay_damaged?(1) == false
        yume.combat_by_path 1, 201, ["B", "D", "F"], [2, 2 , 2]
    end

end#"pveExploreVo"=>{"levels"=>[{"exploreId"=>"10003", "fleetId"=>"1", "startTime"=>1429769491, "endTime"=>1429771291}, {"exploreId"=>"20004", "fleetId"=>"4", "startTime"=>1429767341, "endTime"=>1429778141}, {"exploreId"=>"20002", "fleetId"=>"3", "startTime"=>1429767290, "endTime"=>1429769990}, {"exploreId"=>"20001", "fleetId"=>"2", "startTime"=>1429764545, "endTime"=>1429771745}]


good_night
 # try_combat
# good_night
# yume = FleetGirl.new
# yume.login
# yume.dump_fleet_info
# yume = FleetGirl.new
# yume.login
# # yume = FleetGirl.new
# # yume.login
# # yume.pvp
# # sleep 10
# # yume.get "api/initData"
# yume = FleetGirl.new
# yume.login
# yume.pvp

# while yume.hevay_damaged? == false
#     yume.combat 1, 204, true, 1
# end
# good_night
