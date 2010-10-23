class Sniperbot < AI
  include Toolbox
  include ShipsAvailable
  bot 'sniperbot'
  # v1: Wait and shoot. Win by exhausting the enemy.
  # v2: Go on the offensive when I have more ships than my enemy has
  # v3: Optimize targets of opportunity finding
  version 3

  def do_turn
    super
    sniper_strategy
    opportunity_strategy
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
        closest_planet = @pw.my_closest_planets(target).first
        min_travel_time = @pw.travel_time(target, closest_planet)
        # Only attack if we have planets nearby
        next min_travel_time < 10
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
        next unless ships_available_on(source) >= (ships_needed * 4)
        attack_with(source, target, ships_needed)
      end
    end
  end
  include OpportunityStrategy
end
