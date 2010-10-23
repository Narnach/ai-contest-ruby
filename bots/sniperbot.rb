class Sniperbot < AI
  include Toolbox
  include ShipsAvailable
  bot 'sniperbot'
  # v1: Wait and shoot. Win by exhausting the enemy.
  version 1

  def do_turn
    super
    sniper_targets.each do |target|
      log "Sniper target: planet #{target.planet_id}"
      try_to_send_ships_to_snipe(target)
    end
  end

  protected

  def potential_targets
    @pw.enemy_fleets.map{|fleet| fleet.destination_planet}.uniq.map{|planet_id| @pw.planets[planet_id]}
  end

  # The best sniper targets are planets that will be conquered by the enemy,
  # so send my ships after the battle has been won by my enemy.
  # They will be weakened, I will be strong.
  def sniper_targets
    potential_targets.select do |planet|
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

      # Don't attack before the enemy has captured the planet
      next unless predictions.last.enemy?

      # Only attack when this planet could take out the target
      ships_needed = predictions.last.num_ships + 1
      next unless ships_available_on(source) >= ships_needed
      attack_with(source, target, ships_needed)
    end
  end
end