require 'rest-client'
require 'digest'
require "json"
require "uri"
require "yaml"
require "pry"

#to go around the URI check
module URI
  class << self
    def parse_with_safety(uri)
      parse_without_safety uri.gsub('[', '%5B').gsub(']', '%5D')
    end

    alias parse_without_safety parse
    alias parse parse_with_safety
  end
end



class FleetGirl
	@@secret_key = "Mb7x98rShwWRoCXQRHQb"
	attr_accessor :explore_plan
	#@@android_login_host = "http://login.alpha.p7game.com/"

	def log(str)
		@log_file.puts str
		puts str
	end

	def initialize(config_file="config.yaml")
		config = YAML.load(File.open(config_file))
		config.each do |key, value|
			self.instance_variable_set "@#{key}".to_sym, value
		end
		@cookies = {}
		# @log_file = File.open("log_#{Time.now.to_i}", "w")
		@log_file = File.open("log", "w")
		@log_file.puts Time.now
	end

	def params(path)
		params = {}
		@params.each do |key, value|
			params[key.to_sym] = value
		end
		params[:t] = 233
		params[:e] = Digest::MD5.hexdigest path+"&t="+params[:t].to_s+@@secret_key
		params
	end

	#relative to @game_host 
	def get(path, *accept_eids)
		url = @game_host + path

		begin
			sleep @sleep_interval
			log "get " + url
			raw = RestClient.get url, :params => params(path), :cookies => @cookies
			@cookies.update raw.cookies
			r = JSON.parse(raw)
			log r
			if r["eid"] == -9997
				@cookies.clear
				login
				next
			end
		end until r["eid"].nil? or accept_eids.include? r["eid"]
		r
	end

	def try_get(path)
		sleep @@sleep_interval
		url = @game_host + path
		log "try get " + url
		r = RestClient.get url, :params => params(path), :cookies => @cookies 
		log r
		r
	end

	def login()
		url = "index/passportLogin/#{@user}/#{@pwd}"
		url = URI.encode(@login_host + url)
		log "get #{url}"
		r = RestClient.get url 		#r is a String but somehow has :cookies metho, maybe define method for an object
		log r
		@user_id = JSON.parse(r)["userId"]
		@cookies = r.cookies
		get "index/login/#{@user_id}"

		#try_get "api/initData"
		#try_get "active/getUserData"	
		#not necessary
	end
#for reference
# boat/supplyFleet/1/0
# pve/challenge129/104/1/0
# pve/next/
# pve/deal/10403/1/2
# pve/getWarResult/0
# pve/pveEnd
#-608 舰队组成不满足条件

	def explore_start(fleet_id, explore_id=nil)
		explore_id = @explore_plan[fleet_id] if explore_id.nil?
		get "explore/start/#{fleet_id}/#{explore_id}", -604
	end
	def explore_end(fleet_id, explore_id=nil)
		explore_id = @explore_plan[fleet_id.to_s] if explore_id.nil?
		get "explore/getResult/#{explore_id}", -602		
	end
	def repair_start(ship_id, dock_id)
		get "boat/repair/#{ship_id}/#{dock_id}"
	end
	def repair_end(ship_id, dock_id)
		get "boat/repairComplete/#{dock_id}/#{ship_id}"
	end


	#-411 full supply?
	def supply_fleet(fleet_id=1)
		get "boat/supplyFleet/#{fleet_id}/0", -411
	end

	def pve_start(fleet_id, mission_id)
		# -407  大破 无法出击
		r = get "pve/challenge129/#{mission_id}/#{fleet_id}/0", -407
		r["eid"] != -407
	end

	def pve_end()
		get "pve/pveEnd/"
	end

	def pve_battle(fleet_id, node_id, formation, night_war=0)
		r = get "pve/deal/#{node_id}/#{fleet_id}/#{formation}"
		return nil if r.has_key?("warReport") == false
		night_war = r["warReport"]["canDoNightWar"] if night_war==1
		get "pve/getWarResult/#{night_war}"
	end

	def get_next_node()
		get("pve/next/")["node"]
	end

	def get_init_data()
		get "api/initData"
	end

	def get_fleet_info(fleet_id)
		data = get_init_data
		ships = data["fleetVo"][fleet_id-1]["ships"]
		ships.map { |id| data["userShipVO"].find { |x| x["id"] == id} }
	end

	def combat_by_path(fleet_id, mission_id, path, formations)
		base_node_id = "#{mission_id}02".to_i
		supply_fleet fleet_id
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

	def hevay_damaged?(fleet_number=1)
		status = fleet_status(fleet_number)
		p status.map { |x| (x["battleProps"]["hp"].to_f / x["battlePropsMax"]["hp"]).round(2) }
		status.any? { |x| x["battleProps"]["hp"] < 0.5*x["battlePropsMax"]["hp"]}
	end

	def pvp()
		r = get "pvp/getChallengeList/"
		opponents = r["list"].map { |x| x["uid"] }

		opponents.each do |op|
			get "pvp/challenge/#{op}/1/5", -906 # myfleetID, formation
			get "pvp/getWarResult/1", -904
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

	def dark
		fleet_id = 1

		pupils = find_pupils

		5.downto(1) do |index|
			get "boat/removeBoat/#{fleet_id}/#{index}", -314
		end

		if pupils.length > 6
			s = pupils[6..-1].map { |x| x['id'] }.join(',')
			get "dock/dismantleBoat/[#{s}]/1" # 1 means dismantle arms also
		end

		pupils = pupils[0..5]

		pupils[0..-2].each do |x|
				get "boat/changeBoat/#{fleet_id}/#{x['id']}/0"
				5.times { combat 1, 101, false }
		end

		get "boat/changeBoat/#{fleet_id}/#{pupils[-1]['id']}/0"

		s = pupils[0..-2].map { |x| x['id'] }.join(',')

		get "dock/dismantleBoat/[#{s}]/1"
	end

	def dump_fleet_info
		fleet_info = get_init_data()["fleetVo"].map { |x| x["ships"] }
		File.open("fleet_info", "w") do |file|
			file.write(YAML.dump fleet_info)
		end 
	end
end


