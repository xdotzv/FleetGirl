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
                r = yume.explore_start x["fleetId"].to_i, x["exploreId"]
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

good_night