class Grower < AI
  include Toolbox
  include ShipsAvailable
  attr_reader :target
  bot 'grower'
  # v1: Naieve, agressive
  # v2: Calculating, agressive
  version 2

  def do_turn
    super

    easiest_planets_to_capture.each do |target|
      @pw.my_closest_planets(target).each do |source|
        distance = @pw.travel_time(target, source)
        futures = predict_future_population(target, distance)
        next if futures.last.mine?
        ships_to_send = futures.last.num_ships + 1
        next if ships_to_send <= 0
        next if ships_to_send > ships_available_on(source)
        attack_with(source, target, ships_to_send)
      end
    end
  end
end