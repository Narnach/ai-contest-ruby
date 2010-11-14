class Bullybot < AI
  include Toolbox
  include ShipsAvailable
  bot 'bullybot'
  # v1: send 1 fleet at a time
  # v2: send 1 fleet per planet to the closest and weakest planet
  version 2

  def do_turn
    super
    # If we have a fleet in flight, do nothing
    @pw.my_planets.each do |source|
      # Skip planets with an outbound fleet
      next if @pw.my_fleets.find{|fleet| fleet.source_planet == source.planet_id}
      # Pick weakest other planet
      target = @pw.not_my_planets.sort_by{|planet| planet.num_ships}.first
      # Attempt to find an equally close planet nearby
      target = @pw.closest_planets(source, @pw.not_my_planets).find{|planet| planet.num_ships == target.num_ships}
      # Send half the source planet's ships away
      attack_with(source, target, source.num_ships / 2)
    end
  end
end