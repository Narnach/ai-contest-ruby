class Thinkerbot < AI
  include Toolbox
  include ShipsAvailable
  bot 'thinkerbot'
  # v1: Come up with a masterplan. Only comments for now.
  version 1

  def do_turn
    super
    # Recalculate masterplan and assign targets based on this.
    masterplan_strategy
  end

  protected

  # The masterplan: which planets to conquer, in what order and where to go afterwards.
  # Differentiates itself from other strategies in that it will not try to micro-manage planets.
  # It instead uses a query-response between planets and the planner to determine if there is enough support for each sub-strategy it has.
  # This strategy will consider multiple strategies and pick the one it deems best.
  module MasterplanStrategy
    class AttackTarget
      attr_accessor :target

      def initialize(target)
        @target=target
      end

      def future
        @future ||= predict_future_population(target, max_distance)
      end

      def plans
        @plans ||= Array.new
      end

      def max_distance
        @max_distance ||= (
          d = @pw.travel_time(closest_inhabited_planets.last, target)
          if inbound_fleets.any?
            d = [d,closest_inbound_fleets.last.turns_remaining].max
          end
          d
        )
      end

      def closest_inhabited_planets
        @closest_inhabited_planets ||=@pw.closest_planets(target, @pw.my_planets + @pw.enemy_planets)
      end

      def closest_inbound_fleets
        @closest_inbound_fleets ||= @pw.fleets_underway_to(target).sort_by{|fleet| fleet.turns_remaining}
      end
    end

    class AttackPlan
      attr_accessor :source, :attack_target
      def initialize(source, attack_target)
        @source, @attack_target = source, attack_target
      end
    end

    def do_turn
      super
      @attack_targets = []
      @attack_plans = Hash.new { |hash, key| hash[key] = Array.new }
    end

    def masterplan_strategy
      determine_attack_targets
      ask_for_sources
      exclude_impossible_targets
      match_sources_to_targets
      attack_possible_targets
    end

    protected

    def determine_attack_targets
      @attack_targets = @pw.not_my_planets.map do |planet|
        AttackTarget.new(planet)
      end
    end

    def ask_for_sources
      @pw.my_planets.each do |planet|
        @attack_targets.each do |attack_target|
          attack_target.plans << AttackPlan.new(source, attack_target)
        end
      end
    end

    def exclude_impossible_targets
    end

    def match_sources_to_targets
    end

    def attack_possible_targets
    end
  end
  include MasterplanStrategy
end
