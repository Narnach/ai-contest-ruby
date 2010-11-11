class Sniperbot < AI
  include Toolbox
  include ShipsAvailable
  bot 'sniperbot'
  # v1: Wait and shoot. Win by exhausting the enemy.
  # v2: Go on the offensive when I have more ships than my enemy has
  # v3: Optimize targets of opportunity finding
  # v4: Added ReinforceStrategy v2
  # v5: Added SupplyTheFrontStrategy
  # v6: Added NumericalSuperiorityStrategy
  # v7: Adjusted target finding algorithms
  # v8: Treat planets that get invaded as if they were my own: defend them and supply them
  version 8

  def do_turn
    super
    # Set defenders for my own planets and send aid to help planets under attack
    reinforce_strategy
    # Attack targets that can be conquered by a low amount of ships, for example by striking right after my opponent captures a neutral planet
    sniper_strategy
    # Attack targets that are a good investment: nearby, reachable and not well defended
    opportunity_strategy
    # When there are ships left, send them to a planet closer to the front-lines
    supply_the_front_strategy
    # Based on where we are numbers-wise, grab more planets or attack the enemy
    numerical_superiority_strategy
  end

  protected

  module SniperStrategy
    def sniper_strategy
      sniper_targets.each do |target|
        log "Sniper target: planet #{target.planet_id}"
        try_to_send_ships_to_snipe(target)
      end
    end

    # Find all potentially sniper-able planets
    def potential_sniper_targets
      easiest_planets_to_capture & @pw.enemy_fleets.map{|fleet| [fleet.destination_planet, fleet.source_planet]}.flatten.uniq.map{|planet_id| @pw.planets[planet_id]}
    end

    # The best sniper targets are planets that will be conquered by the enemy's fleets,
    # so send my ships after the battle has been won by my enemy.
    # They will be weakened, I will be strong.
    def sniper_targets
      potential_sniper_targets.select do |planet|
        # Predict future accounting for all current fleets
        max_travel_time = @pw.fleets_underway_to(planet).map{|fleet| fleet.turns_remaining}.max
        predictions = predict_future_population(planet, max_travel_time)

        # Only go for planets that the enemy will eventually win
        next unless predictions.last.enemy?

        next if planet.enemy?
        if planet.mine?
          # Recapture
        elsif planet.enemy?
          # Don't go for planets that are getting reinforced. Don't fight the enemy head-on.
          next
        else # neutral
          # Snipe
        end
        true
      end
    end

    def try_to_send_ships_to_snipe(target)
      @pw.my_closest_planets(target).each do |source|
        travel_time = @pw.travel_time(source, target)
        predictions = predict_future_population(target, travel_time)

        # Only attack planets that the enemy controls when we could reach them
        next unless predictions.last.enemy?

        # Only attack when this planet could take out the target
        ships_needed = predictions.last.num_ships + 1
        next unless ships_available_on(source) >= ships_needed
        attack_with(source, target, ships_needed)
      end
    end
  end
  include SniperStrategy

  module OpportunityStrategy
    def opportunity_strategy
      easiest_planets_to_capture.each do |target|
        log "Opportunity target: planet #{target.planet_id}"
        try_attack_of_opportunity_on(target)
      end
    end

    def try_attack_of_opportunity_on(target)
      @pw.my_closest_planets(target).each do |source|
        travel_time = @pw.travel_time(source, target)
        predictions = predict_future_population(target, travel_time)

        # Don't reinforce my own future planets
        next if predictions.last.mine?

        # Only attack when this planet could take out the target
        ships_needed = predictions.last.num_ships + 1

        # Capture the planet when we have enough non-defending ships available
        next unless ships_available_on(source) >= ships_needed
        attack_with(source, target, ships_needed)
      end
    end
  end
  include OpportunityStrategy

  # Taken from Toolbot: improve it and share.
  module ReinforceStrategy
    # Check for threats to our planets and reinforce them.
    # Predict future for all my planets, time to look ahead: max of closest enemy planet, inbound fleets and 1 (for no enemies)
    # * If future owner is not me, set defenders to all on the planet and look for help
    # * Closest enemy: Assume they attack with their whole garisson. After the attack, how many ships would I have left? That is the amount of available ships.
    def reinforce_strategy
      in_need_of_help = Array.new
      @pw.my_planets.each do |planet|
        distance = 1
        possibly_required_defenders = []

        if furthest_inbound_fleet = @pw.fleets_underway_to(planet).sort_by{|fleet| fleet.turns_remaining}.last
          distance = furthest_inbound_fleet.turns_remaining if furthest_inbound_fleet.turns_remaining > distance
        end
        if closest_enemy = @pw.closest_enemy_planets(planet).first
          distance_to_closest_enemy = @pw.travel_time(planet, closest_enemy)
          distance = distance_to_closest_enemy if distance_to_closest_enemy > distance
        end

        predictions = predict_future_population(planet, distance)

        if predictions.all? {|future| future.mine?}
          available_ships = predictions.map{|future| future.num_ships}.min
          possibly_required_defenders << (ships_for_defense_of(planet) - available_ships)
        else
          possibly_required_defenders << ships_for_defense_of(planet)
          in_need_of_help << planet
        end

        if closest_enemy
          available_ships = predictions[distance_to_closest_enemy].num_ships - closest_enemy.num_ships
          available_ships = 0 if available_ships < 0
          # Discount all ships available for defense on planets closer than the closest enemy.
          # This should prevent 'freezing' behaviour when my total population is larger, but individual planets are smaller than my closest enemy.
          ships_on_nearby_friendly_planets = @pw.nearby_planets(planet, distance_to_closest_enemy, @pw.my_planets).inject(0) do |ships, friendly_planet|
            ships + ships_available_on(friendly_planet)
          end
          available_ships += ships_on_nearby_friendly_planets
          possibly_required_defenders << (ships_for_defense_of(planet) - [available_ships, ships_available_on(planet)].min)
        end

        defenders = possibly_required_defenders.max
        next if defenders <= 0
        log "Planet #{planet.planet_id} assigns #{defenders} out of #{ships_available_on(planet)} ships to defense"
        assign_defenders(planet, defenders)
      end

      in_need_of_help.sort_by{|planet| -planet.growth_rate}.each do |target|
        log "Planet #{target.planet_id} is in need of help"
        inbound_fleets = @pw.fleets_underway_to(target)
        max_distance = inbound_fleets.map{|f| f.turns_remaining}.max
        predictions = predict_future_population(target, max_distance)
        help_required = predictions.select{|future| future.enemy?}.map{|future| future.num_ships}.max + 1
        @pw.my_closest_planets(target).each do |planet|
          break if help_required <= 0
          ships_to_send = [ships_available_on(planet), help_required].min
          next if ships_to_send <= 0
          attack_with(planet, target, ships_to_send)
          help_required -= ships_to_send
        end
      end
      log "After assigning defenders, my planets have %i ships available for attack" % @pw.my_planets.inject(0){|ships,planet| ships + ships_available_on(planet)}
    end
  end
  include ReinforceStrategy

  module SupplyTheFrontStrategy
    def do_turn
      @suppliable_planets = nil
      super
    end

    def supply_the_front_strategy
      log "Supplying the front lines"
      @pw.my_planets.each do |source|
        next if ships_available_on(source) <= 0
        source_index = my_planets_by_distance_to_enemy(suppliable_planets).index(source)
        next unless target = suppliable_planets.sort_by{|planet| @pw.distance(planet, source)}.find do |planet|
          next if planet == source
          planet_index = my_planets_by_distance_to_enemy(suppliable_planets).index(planet)
          if closest_enemy_planet = @pw.closest_enemy_planets(source).first
            planet_index < source_index && @pw.travel_time(planet, source) < @pw.travel_time(source, closest_enemy_planet)
          else
            planet_index < source_index
          end
        end
        attack_with(source, target, ships_available_on(source))
      end
      log "After supplying the front, my planets have %i ships available for attack" % @pw.my_planets.inject(0){|ships,planet| ships + ships_available_on(planet)}
    end

    def suppliable_planets
      @suppliable_planets ||= (
        future_owned_planets = @pw.my_fleets.map{ |fleet|
          fleet_planet = @pw.planets[fleet.destination_planet]
          # predictions = predict_future_population(fleet_planet, fleet.turns_remaining)
          # predictions.last.mine? ? fleet_planet : nil
        }.compact
        (@pw.my_planets + future_owned_planets).uniq
      )
    end
  end
  include SupplyTheFrontStrategy

  module NumericalSuperiorityStrategy
    def numerical_superiority_strategy
      advantage = @my_population - @enemy_population
      return unless advantage > 0
      if @my_growth > @enemy_growth
        log "Using numerical superiority to weaken the enemy"
        attack_with_fleet(advantage, easiest_planets_to_capture(@pw.enemy_planets, :pruning=>false))
      else
        log "Using numerical superiority to capture nearby planets"
        attack_with_fleet(advantage, easiest_planets_to_capture)
      end
    end

    def attack_with_fleet(total_ships_to_send, targets)
      targets.each do |target|
        return if total_ships_to_send <= 0
        @pw.my_closest_planets(target).each do |source|
          return if total_ships_to_send <= 0
          next if ships_available_on(source) <= 0
          ships_to_send = [ships_available_on(source), total_ships_to_send].min
          attack_with(source, target, ships_to_send)
          total_ships_to_send -= ships_to_send
        end
      end
    end
  end
  include NumericalSuperiorityStrategy
end
