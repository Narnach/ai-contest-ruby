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
  version 6

  def do_turn
    super
    reinforce_strategy
    sniper_strategy
    opportunity_strategy
    supply_the_front_strategy
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
      @pw.enemy_fleets.map{|fleet| fleet.destination_planet}.uniq.map{|planet_id| @pw.planets[planet_id]}
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
      opportunity_targets.each do |target|
        log "Opportunity target: planet #{target.planet_id}"
        try_attack_of_opportunity_on(target)
      end
    end

    def opportunity_targets
      planets = @pw.not_my_planets.select {|planet|
        next unless my_closest_planet = @pw.my_closest_planets(planet).first
        next unless closest_enemy_planet = @pw.closest_enemy_planets(planet).first
        next false if @pw.distance(planet, my_closest_planet) - @pw.distance(planet, closest_enemy_planet) > 0
        planet.growth_rate >= 1
      }
      planets.sort_by do |planet|
        if closest_enemy_planet = @pw.closest_enemy_planets(planet).first
          nearest_fleet = closest_enemy_planet.num_ships
          regen_until_enemy_arrives = @pw.travel_time(closest_enemy_planet, planet) * planet.growth_rate
        else
          nearest_fleet = 0
          regen_until_enemy_arrives = 0
        end
        (planet.num_ships + nearest_fleet - regen_until_enemy_arrives) / planet.growth_rate
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

        # Send a maximum of 25% of the standing fleet to capture targets of opportunity
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
        elsif predictions.last.mine?
          # Ownerships will flip back and forth, so keep all ships as defense force
          possibly_required_defenders << ships_for_defense_of(planet)
        else
          possibly_required_defenders << ships_for_defense_of(planet)
          in_need_of_help << planet
        end

        if closest_enemy
          available_ships = predictions[distance_to_closest_enemy].num_ships - closest_enemy.num_ships
          available_ships = 0 if available_ships < 0
          possibly_required_defenders << (ships_for_defense_of(planet) - [available_ships, ships_available_on(planet)].min)
        end

        defenders = possibly_required_defenders.max
        next if defenders <= 0
        log "Planet #{planet.planet_id} assigns #{defenders} our of #{ships_available_on(planet)} ships to defense"
        assign_defenders(planet, defenders)
      end

      in_need_of_help.each do |target|
        log "Planet #{target.planet_id} is in need of help"
        # Explicit code to send aid seems not yet required, as Sniperbot keeps winning against all my other bots.
        # Sniping and opportunity checking code also fills in to aid where it is economical.
      end
    end
  end
  include ReinforceStrategy

  module SupplyTheFrontStrategy
    def supply_the_front_strategy
      @pw.my_planets.each do |source|
        next if ships_available_on(source) <= 0
        source_index = my_planets_by_distance_to_enemy.index(source)
        next unless target = @pw.my_closest_planets(source).find do |planet|
          planet_index = my_planets_by_distance_to_enemy.index(planet)
          planet_index < source_index
        end
        log "Supplying the front line"
        attack_with(source, target, ships_available_on(source))
      end
    end
  end
  include SupplyTheFrontStrategy

  module NumericalSuperiorityStrategy
    def numerical_superiority_strategy
      return unless @my_population > @enemy_population
      if @my_growth > @enemy_growth
        attack_enemy_planets
      else
        capture_nearby_planets
      end
    end

    def planets_worth_capturing
      planets = @pw.not_my_planets.select {|planet|
        my_closest_planet = @pw.my_closest_planets(planet).first
        next unless my_closest_planet
        closest_enemy_planet = @pw.closest_enemy_planets(planet).first
        next unless closest_enemy_planet
        next false if @pw.distance(planet, my_closest_planet) - @pw.distance(planet, closest_enemy_planet) > 0
        planet.growth_rate >= 1
      }
      planets.sort_by {|planet| planet.num_ships / planet.growth_rate}
    end

    def capture_nearby_planets
      advantage = @my_population - @enemy_population
      planets_worth_capturing.each do |target|
        return if advantage <= 0
        @pw.my_closest_planets(target).each do |source|
          return if advantage <= 0
          next if ships_available_on(source) <= 0
          ships_to_send = [ships_available_on(source), advantage].min
          log "Using numerical superiority to capture nearby planets"
          attack_with(source, target, ships_to_send)
          advantage -= ships_to_send
        end
      end
    end

    def attack_enemy_planets
      advantage = @my_population - @enemy_population
      my_planets_by_distance_to_enemy.each do |source|
        break if advantage <= 0
        next if ships_available_on(source) <= 0
        ships_to_send = [ships_available_on(source), advantage].min
        target = @pw.closest_enemy_planets(source).first
        log "Using numerical superiority to weaken the enemy"
        attack_with(source, target, ships_to_send)
        advantage -= ships_to_send
      end
    end
  end
  include NumericalSuperiorityStrategy
end
