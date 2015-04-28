require './basefleetgirl'
#to go around the URI check


class FleetGirl < BaseFleetGirl 

	def get_fleet_info(fleet_id)
		data = get_init_data
		ships = data["fleetVo"][fleet_id-1]["ships"]
		ships.map { |id| data["userShipVO"].find { |x| x["id"] == id} }
	end

	def combat_by_path(fleet_id, mission_id, path, formations)
		base_node_id = "#{mission_id}02".to_i
		supply_fleet(fleet_id)
		fleet_info = get_fleet_info(fleet_id)

		max_hps = fleet_info.map { |x| x["battlePropsMax"]["hp"]}
		hps = fleet_info.map { |x| x["battleProps"]["hp"]}

		return if pve_start(fleet_id, mission_id) == false
		0.upto(path.length-1) do |i|
			0.upto(fleet_info.length-1) do |k|
				return if hps[k] < 0.5 * max_hps[k]
			end
			node_id = get_next_node
			#binding.pry
			return true if node_id - base_node_id != path[i].ord - "A".ord
			#only go for night war at the last battle
			night_war = path.length-i==1 ? 1 : 0
			r = pve_battle fleet_id, node_id, formations[i], night_war
			hps = r["warResult"]["selfShipResults"].map { |x| x["hp"] } if r.nil? == false
			p hps
			p max_hps
			0.upto(fleet_info.length-1) do |k|
				return false if hps[k] < 0.5 * max_hps[k]
			end
			sleep 12
		end
		pve_end
		true
	end
	def combat(fleet_id=1, mission_id=204, supply=true, night_war=0)
		supply_fleet(fleet_id) if supply

		if pve_start(fleet_id, mission_id)
			node_id = get_next_node
			r = get "pve/deal/#{node_id}/#{fleet_id}/2"
			night_war = r["warReport"]["canDoNightWar"] if night_war==1
			get "pve/getWarResult/#{night_war}"
			#pry.binding
			#puts JSON.parse(r)
			get "pve/pveEnd/"
		end
	end


	def get_damaged_ships(r=nil)
		r = get "initData" if r.nil?
		r["userShipVO"].select { |x| x["battleProps"]["hp"] < x["battlePropsMax"]["hp"] and x["status"] != 2}.map{ |x| x["id"]}
	end

	def repair()
		#sleep 30
		data = get "api/initData"

		damaged = get_damaged_ships data

		repair_dock = data["repairDockVo"].select { |x| x["locked"] == 0 and x["shipId"].nil? }

		while repair_dock.length > 0 and damaged.length > 0
			dock = repair_dock.shift
			ship = damaged.shift

			get "boat/repair/#{ship}/#{dock["id"]}"

			data = JSON.parse(get "api/initData")
			damaged = data["userShipVO"].select { |x| x["battleProps"]["hp"] < x["battlePropsMax"]["hp"] and x["status"] == 0}.map{ |x| x["id"]}
			repair_dock = data["repairDockVo"].select { |x| x["locked"] == 0 and x["endTime"] < Time.now.to_i }
		end
	end

	def fleet_status(fleet_number)
		r = get "api/initData"
		ships = r["fleetVo"][fleet_number-1]["ships"]
		r["userShipVO"].select{ |x| ships.include? x["id"]}
	end

	def heavy_damaged?(fleet_number=1)
		status = fleet_status(fleet_number)
		p status.map { |x| (x["battleProps"]["hp"].to_f / x["battlePropsMax"]["hp"]).round(2) }
		status.any? { |x| x["battleProps"]["hp"] < 0.5*x["battlePropsMax"]["hp"]}
	end

	def pvp_all()
		get_pvp_list.each do |opponent|
			pvp_battle opponent
		end
	end
# def pvp():
#     print json_with_cookie("pvp/getChallengeList/")
#     fleetIds = map(lambda x: x["uid"], json_with_cookie("pvp/getChallengeList/")["list"])
#     for fleetId in fleetIds:
#         print json_with_cookie("pvp/challenge/%s/%d/%d" % (fleetId, 1, 1)) # fleetId, myfleetID, formation
#         print json_with_cookie("pvp/getWarResult/0")

	def find_pupils()
		get("api/initData")["userShipVO"].select { |x| x["level"] == 1 and x["fleetId"] == 0 and x["exp"] == 0 and x["isLocked"] == 0}
	end

	def dark()
		fleet_id = 1

		pupils = find_pupils

		5.downto(1) do |index|
      remove_ship fleet_id, index
		end

		if pupils.length > 6
			tmps = pupils[6..-1].map { |x| x['id'] }
      dismantle_ships tmps, 1
		end

		pupils = pupils[0..5]
#may replace itself
		pupils[0..-2].each do |x|
      change_ship fleet_id, x["id"], 0
			5.times { combat 1, 101, false, 1 }
		end

    change_ship fleet_id, pupils[-1]['id'], 0
		tmps = pupils[0..-2].map { |x| x['id'] }
    dismantle_ships tmps, 1
	end

	def good_night()
		1.upto(4) do |i|
			supply_fleet i
		end
		r = get_init_data
    repair_dock = r["repairDockVo"]

    ships = get_damaged_ships(r)
    explore_info = r["pveExploreVo"]["levels"]
    free_fleets = @explore_plan.keys - explore_info.map { |x| x["fleetId"].to_i }
    
    free_fleets.each do |fleet_id|
        r = explore_start fleet_id
        explore_info = r["pveExploreVo"]["levels"]
    end

    while true
        explore_info.dup.each do |x|
            if x["endTime"] < Time.now.to_i
                r = explore_end x["fleetId"].to_i, x["exploreId"]
                r = explore_start x["fleetId"].to_i
                explore_info = r["pveExploreVo"]["levels"]
            end
        end
        repair_dock.dup.each do |dock|
            break if ships.empty?
            next if dock["locked"] == 1
            if dock["endTime"].nil? or dock["endTime"] < Time.now.to_i
                r = repair_end dock["shipId"], dock["id"] if dock.has_key? "shipId"
                r = repair_start ships.shift, dock["id"]
                repair_dock = r["repairDockVo"]
            end
        end
        sleep 30
    end
  end
end


