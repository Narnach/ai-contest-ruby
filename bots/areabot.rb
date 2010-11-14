# Use Area of Influence strategy
#
# * Model the universe as areas of influence (AoI).
#   * Besides picking high-growth planets, also try to prioritize the planets that increase my AoI.
#   * Planets within my AoI are always safe to capture, so they can be delayed by a little bit.
#   * Picking off enemy planets that are over-extended should be prioritized highest, then capturing AoI-enlarging ones.
#   * When there are no targets left within my own sphere of influence, then it is either time to start attacking my enemy or I have lost.
#   * AoI can be modeled simply by using distances, but how many ships each player can get to each planet in X turns is also a very good model. This indicates defensibility of positions.
#     * AoI modeling with ships can also aid in determining how many ships each planet has available: the potential amount of ships should never become negative. This can aid in determining targets: let ships 'flow' from positive to negative planets. Combined with predictions of actual ships counts, growths and fleets, this makes a good forecasting model.
#
class Areabot < AI
  include Toolbox
  include ShipsAvailable
  bot 'areabot'
  # v1: Use distance-based area modeling. Only try to conquer planets within my own area of influence.
  # Todo:
  # * Use ship-based area modeling. How many ships can potentially be sent where?
  # * Use ship-based area modeling in future forecasts. When sending out a fleet, how will this impact the potential amount of ships on other planets?
  version 1

  def do_turn
    super
    distance_area_strategy
  end

  protected

  module DistanceAreaStrategy
    def do_turn
      super
      self.assign_gamestate
      self.assign_distance_scores
      self.analyze_map
      @targets = []
    end

    def distance_area_strategy
      planets_closer_to_me_than_to_enemy.sort_by{|planet| planet.influence_score}.each do |target|
        target.closest_planets(@pw.my_planets).each do |source|
          distance = @pw.travel_time(source, target)
          ships_needed = ships_needed_to_capture(target, distance)
          ships_available = ships_available_on(source)
          next if ships_needed < ships_available
          ships_to_send = [ships_needed, ships_available].min
          next if ships_to_send <= 0
          attack_with(source, target, ships_to_send)
        end
      end
    end

    protected

    def assign_gamestate
      @pw.planets.each do |planet|
        planet.gamestate = @pw
      end
    end

    def assign_distance_scores
      @pw.planets.each do |planet|
        unless closest_friendly = @pw.my_closest_planets(planet).first
          planet.influence_score = 100
          next
        end
        unless closest_enemy = @pw.closest_enemy_planets(planet).first
          planet.influence_score = -100
          next
        end
        friendly_distance = @pw.travel_time(planet, closest_friendly)
        enemy_distance = @pw.travel_time(planet, closest_enemy)
        diff = friendly_distance - enemy_distance
        planet.influence_score = diff
        planet.enemy_distance = enemy_distance
        planet.friendly_distance = friendly_distance
      end
    end

    def analyze_map
      log "Planets closer to me than to enemy:"
      planets_closer_to_me_than_to_enemy.each do |planet|
        if planet.enemy?
          log "Planet #{planet.planet_id} is an enemy, but is over-extended. Very valuable target because the enemy can't take it back in time."
        elsif planet.mine?
          log "Planet #{planet.planet_id} is mine and safely inside my Area of Influence."
        else
          next log("Planet #{planet.planet_id} has no close friendly planets, this means I have no planets.") unless planet.influence_score == 100
          next log("Planet #{planet.planet_id} has no close enemy planets, this means they have no planets.") unless planet.influence_score == -100
          if planet.influence_score == 0
            distance_indication = "equally far from both players"
          elsif planet.influence_score < 0
            distance_indication = "#{planet.influence_score.abs} turns closer to my planets"
          else
            distance_indication = "#{planet.influence_score} turns closer to my enemy's planets"
          end
          log "Planet #{planet.planet_id} is #{distance_indication}, at distance #{planet.friendly_distance} from me and #{planet.enemy_distance} from the enemy."
        end
      end
    end

    def planets_not_under_influence_of_enemy
      @pw.planets.select do |planet|
        planet.influence_score <= 0
      end
    end

    def planets_closer_to_me_than_to_enemy
      @pw.planets.select do |planet|
        planet.influence_score < 0
      end
    end
  end
  include DistanceAreaStrategy
end

class Planet
  attr_accessor :influence_score, :friendly_distance, :enemy_distance
  attr_accessor :gamestate
  # attr_accessor :defenders, :dispatched_ships

  def closest_planets(planets=self.gamestate.planets)
    self.gamestate.closest_planets(self, planets)
  end

  # def available_ships
  #   self.num_ships - self.defenders - self.dispatched_ships
  # end
  #
  # def defenders
  #   @defenders ||= 0
  # end
  #
  # def dispatched_ships
  #   @dispatched_ships ||= 0
  # end
end