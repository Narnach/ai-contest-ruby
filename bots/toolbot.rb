# Toolbot has a collection of simple strategies it can execute. It cycles through them in order.
class Toolbot < AI
  include Toolbox
  include ShipsAvailable
  bot 'toolbot'
  # v1: Experimental, one-strategy bot
  # v2: Pick different strategies depending on who has advantage
  version 2

  def initialize
    super
    @strategies ||= self.class.included_modules.select { |mod| mod.name =~ /Strategy$/ }.map { |mod| mod.name.split("::").last.underscore }
    log "Available strategies: #{@strategies.join(", ")}"
  end

  def do_turn
    super
    log "Reinforce"
    if @my_ships > @enemy_ships && @my_growth > @enemy_growth
      log "We have more ships and growth, so go for all-out attack"
      cap_strategy
      omni_cap_strategy
      reinforce_strategy
    elsif @my_population > @enemy_population
      log "We have more ships on our planets than they have, so attack them first"
      reinforce_strategy
      cap_strategy
      omni_cap_strategy
    else
      log "We do not have an advantage, so play conservative"
      reinforce_strategy
      omni_cap_strategy
    end
  end

  # Attack the closest enemy planet
  module CapStrategy
    MAX_CAP_PLANETS = 3
    MAX_SUPPORT_PLANETS = 3

    def cap_strategy
      @pw.enemy_planets.sort_by{|planet| planet.num_ships}[0...MAX_CAP_PLANETS].each do |target|
        @pw.my_closest_planets(target)[0...MAX_SUPPORT_PLANETS].each do |source|
          distance = @pw.travel_time(source, target)
          ships_needed = ships_needed_to_capture(target, distance)
          ships_to_send = [ships_available_on(source), ships_needed].min
          next if ships_to_send <= 0
          self.attack_with(source, target, ships_to_send)
        end
      end
    end
  end
  include CapStrategy

  # Make a list of targets, then find the closest friendly planets and send ships out from it
  module OmniCapStrategy
    PROXIMITY = 5
    TOP_X = 5

    def omni_cap_strategy
      all_my_ships = @pw.my_planets.inject(0) {|ships, planet| ships_available_on(planet) + ships}
      scores = Hash.new { |hash, key| hash[key] = 0 }
      sums_of_distances = Hash.new { |hash, key| hash[key] = 0 }
      # Find all planets weighed on distance to all friendly planets, growth and hostile fleet count
      sorted_planets = @pw.not_my_planets.sort_by do |planet|
        # positive points for my own planets, negatives for enemy. 0 for neutral.
        # more points for being closer, less for further
        distance_factor = @pw.closest_planets(planet)[0...PROXIMITY].inject(0) do |score, nearby_planet|
          d = @pw.travel_time(planet, nearby_planet)
          case nearby_planet.owner
          when 0
            points = -100 / d
          when 1
            points = 1000 / d
          when 2
            points = -1000 / d
          end
          score + points
        end
        sums_of_distances[planet.planet_id]=distance_factor

        grow_factor = planet.growth_rate * 100
        ship_factor = all_my_ships > 0 ? 1.0 * (all_my_ships - planet.num_ships) / all_my_ships : 0
        ship_factor = 0 if ship_factor < 0
        score = ((distance_factor + grow_factor) * ship_factor).to_i
        scores[planet.planet_id] = score
        -score
      end

      sorted_planets[0...TOP_X].each_with_index do |target, index|
        log "Target ##{index+1}: planet #{target.planet_id} (O:#{target.owner}, G:#{target.growth_rate}, S:#{target.num_ships}, D:#{sums_of_distances[target.planet_id]}) score #{scores[target.planet_id]}"
        next if @pw.my_planets.inject(0) {|ships, planet| planet.num_ships + ships} <= target.num_ships
        @pw.my_closest_planets(target).each do |planet|
          available = ships_available_on(planet)
          next if available <= 0
          distance = @pw.travel_time(planet, target)
          ships_needed = ships_needed_to_capture(target, distance)
          next if ships_needed <= 0
          next if ships_needed >= all_my_ships
          ships_to_send = [available, ships_needed].min
          all_my_ships -= ships_to_send
          next if ships_to_send <= 0
          self.attack_with(planet, target, ships_to_send)
        end
      end
    end
  end
  include OmniCapStrategy

  module ReinforceStrategy
    # Check for threats to our planets and reinforce them.
    def reinforce_strategy
      @pw.my_planets.each do |planet|
        ships_to_send = ships_needed_to_capture(planet)
        next if ships_to_send <= 0
        log "Planet #{planet.planet_id} needs the help of #{ships_to_send} ships to not fall into enemy hands."
        @pw.my_closest_planets(planet).each do |helping_planet|
          break if ships_to_send <= 0
          helping_ships = [ships_available_on(helping_planet), ships_to_send].min
          next if helping_ships <= 0
          self.attack_with(helping_planet, planet, helping_ships)
          ships_to_send -= helping_ships
        end
      end
    end
  end
  include ReinforceStrategy

  module HunterStrategy
    # All destinations of enemy fleets get N+1 extra inbound ships
    # * Neutral planet targets are delayed by 1 turn to snipe
    # * Enemy planet targets we can over-shoot by defending fleet size + growth factor
    # * Friendly planet targets we only have to match them.
    def hunter_strategy
    end
  end
  include HunterStrategy
end