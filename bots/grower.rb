class Grower < AI
  include Toolbox
  include ShipsAvailable
  attr_reader :target
  bot 'grower'
  # v1: Naieve, agressive
  # v2: Calculating, agressive
  # v3: v2 + simple defense strategy
  version 3

  def do_turn
    super
    @needs_defense = []

    defend
    attack
  end

  def defend
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

  def attack
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