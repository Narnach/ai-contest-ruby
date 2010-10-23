class Sniperbot < AI
  include Toolbox
  include ShipsAvailable
  bot 'sniperbot'
  # v1: Wait and shoot. Win by exhausting the enemy.
  # v2: Go on the offensive when I have more ships than my enemy has
  # v3: Optimize targets of opportunity finding
  # v4: Added ReinforceStrategy v2
  version 4

  def do_turn
    super
    reinforce_strategy
    sniper_strategy
    opportunity_strategy
    supply_the_front_strategy
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

    def potential_opportunity_targets
      @pw.not_my_planets.select { |planet|
        next true unless closest_enemy = @pw.closest_enemy_planets(planet).first
        distance_to_enemy = @pw.travel_time(planet, closest_enemy)
        regeneration_until_enemy_arrives = planet.growth_rate * distance_to_enemy
        next planet.num_ships < regeneration_until_enemy_arrives
      }.sort_by{|planet| planet.num_ships}
    end

    def opportunity_targets
      potential_opportunity_targets.select do |target|
        next false unless closest_planet = @pw.my_closest_planets(target).first
        turns_to_closest_friendly = @pw.travel_time(target, closest_planet)
        # Only attack if we have planets nearby
        turns_to_closest_enemy = @pw.travel_time(target, @pw.closest_enemy_planets(target).first)
        next true if turns_to_closest_friendly > turns_to_closest_enemy
        min_travel_time < 10
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
    # * TODO: Closest planet: Assume they attack with their whole garisson. After the attack, how many ships would I have left? That is the amount of available ships.
    def reinforce_strategy
      in_need_of_help = Array.new
      @pw.my_planets.each do |planet|
        distance = 1
        possibly_required_defenders = []

        if furthest_inbound_fleet = @pw.fleets_underway_to(planet).sort{|fleet| fleet.turns_remaining}.last
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
      my_planets_by_distance_to_enemy = @pw.my_planets.sort_by{|planet| @pw.distance(planet, @pw.closest_enemy_planets(planet).first)}
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
end
