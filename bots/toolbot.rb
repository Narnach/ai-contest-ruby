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
        log "Planet I:%3i O:%1i P:%4i G:%2i" % [planet.planet_id, planet.owner, planet.num_ships, planet.growth_rate]
      end
    end

    def ships_needed_to_capture(target, turns)
      needed = target.num_ships + 1
      needed += (turns * target.growth_rate) unless target.neutral?
      needed -= net_ships_underway_to(target)
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
    end

    def reset_ships_available
      @ships_available = Hash.new { |hash, key| hash[key] = 0 }
      @pw.my_planets.each {|planet| @ships_available[planet.planet_id] = planet.num_ships }
    end

    def can_attack?(source, num_ships)
      @ships_available[source.planet_id] >= num_ships
    end

    def attack_with(source, target, num_ships)
      if self.can_attack?(source, num_ships)
        log "Attacking #{target.planet_id} with #{num_ships} ships from #{source.planet_id}. Distance is #{@pw.travel_time(source, target)}."
        @ships_available[source.planet_id] -= num_ships
        @pw.issue_order(source.planet_id, target.planet_id, num_ships)
      else
        log "!!! BUG !!! Wanted to send #{num_ships} from #{source.planet_id} to #{target.planet_id}, while there are only #{@ships_available[source.planet_id]} available!"
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
        log "Planet #{source.planet_id} can send #{@ships_available[source.planet_id]} ships out to capture planets"
        @pw.closest_planets(source).each do |target|
          next if target.mine?
          distance = @pw.travel_time(source, target)
          ships_needed = ships_needed_to_capture(target, distance)
          next if ships_needed <= 0
          if can_attack?(source, ships_needed)
            self.attack_with(source, target, ships_needed)
          else
            log "Not enough ships to send to #{target.planet_id}. Have #{attack_fleet}, need #{ships_needed}"
          end
        end
      end
    end
  end
  include CapStrategy

  # Make a list of targets, then find the closest friendly planets and send ships out from it
  module OmniCapStrategy
    RESERVES = 0.25

    def omni_cap_strategy
      @pw.my_planets.each do |source|
        attack_fleet = source.num_ships - (source.num_ships * RESERVES).to_i
        log "Planet #{source.planet_id} can send #{attack_fleet} ships out to capture planets"
        @pw.closest_planets(source).each do |target|
          next if target.mine?
          distance = @pw.travel_time(source, target)
          ships_needed = ships_needed_to_capture(target, distance)
          next if ships_needed <= 0
          if attack_fleet >= ships_needed
            log "Sending out #{attack_fleet} ships to capture #{target.planet_id}, distance is #{distance}"
            @pw.issue_order(source.planet_id, target.planet_id, ships_needed)
            attack_fleet -= ships_needed
            break if attack_fleet == 0
          else
            log "Not enough ships to send to #{target.planet_id}. Have #{attack_fleet}, need #{ships_needed}"
          end
        end
      end
    end
  end
  # include OmniCapStrategy

  module SnipeStrategy
    def snipe_strategy
      # TODO: Scan enemy fleets headed towards a non-enemy planet and send out a fleet that will defeat them after they arrive.
    end
  end
  # include SnipeStrategy
end