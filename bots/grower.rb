class Grower < AI
  include Toolbox
  include ShipsAvailable
  attr_reader :target
  bot 'grower'
  # v1: Naieve, agressive
  # v2: From scratch: Calculating, agressive
  # v3: v2 + simple defense strategy
  # v4: v3 + supply lines
  version 4

  def do_turn
    super
    @needs_defense = []

    defend
    supply
    attack
  end

  def defend
    log "Assigning defenders"
    @pw.my_planets.each do |planet|
      futures = predict_future_population(planet)
      if futures.all?{|future| future.mine?}
        defenders = planet.num_ships - futures.map{|future| future.num_ships}.min
        assign_defenders(planet, defenders)
      else
        assign_defenders(planet, planet.num_ships)
        @needs_defense << planet if futures.last.enemy?
      end
    end
  end
  
  def supply
    log "Supplying planets"
    # for every friendly
    @pw.my_planets.each do |source|
      next if ships_available_on(source) <= 0
      # find the closest enemy planet
      next unless enemy = @pw.closest_enemy_planets(source).first
      distance = @pw.travel_time(source, enemy)
      # find the closest friendly that is closer to that enemy than me
      next unless friendly = @pw.my_closest_planets(source).find{|planet| @pw.travel_time(planet, enemy) < distance}
      distance_to_friendly = @pw.travel_time(source, friendly)
      # if there are no non-owned planets closer than the friendly planet
      next if @pw.nearby_planets(source, distance_to_friendly, @pw.not_my_planets).any?
      # send all available ships to the friendly planet
      attack_with(source, friendly, ships_available_on(source))
    end
  end

  def attack
    log "Attacking the enemy"
    easiest_planets_to_capture(@needs_defense + @pw.not_my_planets, :pruning=>false).each do |target|
      @pw.my_closest_planets(target).each do |source|
        distance = @pw.travel_time(target, source)
        inbound_fleets = @pw.fleets_underway_to(target) + fleets_dispatched[target.planet_id]
        turns = [inbound_fleets.map(&:turns_remaining).max, distance].compact.max
        futures = predict_future_population(target, turns)
        next if futures.last.mine?
        ships_to_send = futures.last.num_ships + 1
        if futures[distance..-1].all?{|future| future.enemy?}
          ships_to_send = futures[distance].num_ships + 1
        end
        next if ships_to_send <= 0
        next if ships_to_send > ships_available_on(source)
        attack_with(source, target, ships_to_send)
      end
    end
  end
end