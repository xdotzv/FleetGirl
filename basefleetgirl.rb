# -*- coding: utf-8 -*-
require 'rest-client'
require 'digest'
require "json"
require "uri"
require "yaml"


module URI
  class << self
    def parse_with_safety(uri)
      parse_without_safety uri.gsub('[', '%5B').gsub(']', '%5D')
    end

    alias parse_without_safety parse
    alias parse parse_with_safety
  end
end
  
class BaseFleetGirl
  @@secret_key = "Mb7x98rShwWRoCXQRHQb"

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

  def log(str)
    @log_file.puts str
    puts str
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

  def login()
    url = "index/passportLogin/#{@user}/#{@pwd}"
    url = @login_host + url
    log "get #{url}"
    r = RestClient.get url    #r is a String but somehow has :cookies metho, maybe define method for an object
    log r
    @user_id = JSON.parse(r)["userId"]
    @cookies = r.cookies
    get "index/login/#{@user_id}"
  end

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
    # -407 heavy damaged
    # -408 empty supply
    eids = [-407,-408]
    r = get "pve/challenge129/#{mission_id}/#{fleet_id}/0", *eids
    not eids.include? r["eid"]
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

  def get_init_data()
    get "api/initData"
  end
  
  def get_next_node()
    get("pve/next/")["node"]
  end
  
  def get_pvp_list()
    get("pvp/getChallengeList/")["list"].map { |x| x["uid"] }
  end

  def pvp_battle(opponent, fleet_id=1, formation=5)
    get "pvp/challenge/#{opponent}/#{fleet_id}/#{formation}", -906 # myfleetID, formation
    get "pvp/getWarResult/1", -904
  end

  def remove_ship(fleet_id, index)
    get "boat/removeBoat/#{fleet_id}/#{index}", -314, -104
  end
  
  #-312 same ship as the original one
  def change_ship(fleet_id, ship_id, index)
    get "boat/changeBoat/#{fleet_id}/#{ship_id}/#{index}", -312
  end
  
  def dismantle_ships(ship_ids, dismantle_arm)
    get "dock/dismantleBoat/[#{ship_ids.join(',')}]/#{dismantle_arm}"
  end
end
