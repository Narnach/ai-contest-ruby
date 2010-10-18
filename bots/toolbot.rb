# Toolbot has a collection of simple strategies it can execute. It cycles through them in order.
class Toolbot < AI
  bot 'toolbot'

  def initialize
    super
    @strategies ||= self.class.included_modules.select { |mod| mod.name =~ /Strategy$/ }.map { |mod| mod.name.split("::").last.underscore }
    log "Available strategies: #{@strategies.join(", ")}"
  end

  def do_turn
    super
    strategy = @strategies[@turn % @strategies.size]
    log "Picking strategy: #{strategy}"
    self.send(strategy)
  end

  module Toolbox
    protected

    def do_turn
      super
      self.log_planets
    end

    def log_planets
      @pw.planets.each do |planet|
        log "Planet id %3i O:%1i P:%4i G:%2i" % [planet.planet_id, planet.owner, planet.num_ships, planet.growth_rate]
      end
    end

    def ships_needed_to_capture(target, turns)
      needed = target.num_ships + 1
      needed += (turns * target.growth_rate) unless target.neutral?
      needed -= net_ships_underway_to(target)
      needed -= @fleets_dispatched[target.planet_id].inject(0){|num_ships, fleet| num_ships + fleet.num_ships}
      needed
    end

    def net_ships_underway_to(target)
      @pw.fleets_underway_to(target).inject(0) {|ships, fleet| fleet.owner == 1 ? ships + fleet.num_ships : ships - fleet.num_ships}
    end
  end
  include Toolbox

  module ShipsAvailable
    def do_turn
      super
      self.reset_ships_available
      self.reset_fleets_dispatched
    end

    def reset_ships_available
      @ships_available = Hash.new { |hash, key| hash[key] = 0 }
      @pw.my_planets.each {|planet| @ships_available[planet.planet_id] = planet.num_ships }
    end

    def reset_fleets_dispatched
      @fleets_dispatched = Hash.new { |hash, key| hash[key] = Array.new }
    end

    def can_attack?(source, num_ships)
      @ships_available[source.planet_id] >= num_ships
    end

    def ships_available_on(source)
      @ships_available[source.planet_id]
    end

    def dispatch_fleet(source, target, num_ships)
      distance = @pw.travel_time(source, target)
      @fleets_dispatched[target.planet_id] << Fleet.new(source.owner, num_ships, source.planet_id, target.planet_id, distance, distance)
    end

    def attack_with(source, target, num_ships)
      if self.can_attack?(source, num_ships)
        log "Attacking planet #{target.planet_id} with #{num_ships} ships from planet #{source.planet_id}. Distance is #{@pw.travel_time(source, target)}."
        @ships_available[source.planet_id] -= num_ships
        @pw.issue_order(source.planet_id, target.planet_id, num_ships)
        dispatch_fleet(source, target, num_ships)
      else
        log "!!! BUG !!! Wanted to send #{num_ships} from #{source.planet_id} to #{target.planet_id}, while there are only #{ships_available_on(source)} available!"
      end
    end
  end
  include ShipsAvailable

  # Each of our planets tries to capture the closest non-owned planet. Leaves a small reserve in place and takes incoming ships into account.
  module CapStrategy
    RESERVES = 0.25

    def do_turn
      super
      @pw.my_planets.each do |planet|
        @ships_available[planet.planet_id] -= (planet.num_ships * RESERVES).to_i
       end
    end

    def cap_strategy
      @pw.my_planets.each do |source|
        log "Planet #{source.planet_id} can send #{ships_available_on(source)} ships out to capture planets"
        @pw.closest_planets(source).each do |target|
          next if target.mine?
          distance = @pw.travel_time(source, target)
          ships_needed = ships_needed_to_capture(target, distance)
          next if ships_needed <= 0
          ships_to_send = [ships_available_on(source), ships_needed].min
          self.attack_with(source, target, ships_to_send)
        end
      end
    end
  end
  # include CapStrategy

  # Make a list of targets, then find the closest friendly planets and send ships out from it
  module OmniCapStrategy
    PROXIMITY = 5
    TOP_X = 3

    def omni_cap_strategy
      all_my_ships = @pw.my_planets.inject(0) {|ships, planet| planet.num_ships + ships}
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
        ship_factor = 1.0 * (all_my_ships - planet.num_ships) / all_my_ships
        ship_factor = 0 if ship_factor < 0
        score = ((distance_factor + grow_factor) * ship_factor).to_i
        scores[planet.planet_id] = score
        -score
      end

      sorted_planets[0...TOP_X].each_with_index do |target, index|
        log "Target ##{index+1}: planet #{target.planet_id} (G:#{target.growth_rate}, S:#{target.num_ships}, D:#{sums_of_distances[target.planet_id]}) score #{scores[target.planet_id]}"
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
          self.attack_with(planet, target, ships_to_send)
        end
      end
    end
  end
  include OmniCapStrategy

  module SnipeStrategy
    def snipe_strategy
      # TODO: Scan enemy fleets headed towards a non-enemy planet and send out a fleet that will defeat them after they arrive.
    end
  end
  # include SnipeStrategy
end