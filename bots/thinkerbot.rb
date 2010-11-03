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
    def do_turn
      super
    end

    def masterplan_strategy
      # 1. Set goals to capture all enemy planets
      # 2. Set goals to capture obvious targets
      # 3. Set goals to capture convenient targets
      # 4. Ask all planets how they can support each goal
      # 5. Determine which combination of planet-support to all possible goals will yield the most desirable outcome
      #    1. Future predictions of current planets, fleets and proposed fleets: which combination of goals yields to the most desirable output?
      #    2. Future prediction as in 1, but account for the enemy sniping my targets
      #    3. Future prediction as in 2, but account for the enemy also going after nearby targets
      #
      # * Assign roles to planets
      #   * Safe supply planet: no targets nearby, so send all ships not required for immediate defense
      #   * Border planet: no interesting targets are nearby, but it is near enough to enemies that it requires an active defense force.
      #   * Staging planet: Supply planets should send their ships here.
      #   * Target of opportunity: non-owned planet that is not expected to receive significant reinforcements. After capture it is expected to become a safe supply planet.
      #   * Enemy stronghold: expect heavy resistance. Expect all nearby planets to lend support to this planet when attacking.
      #   * Behind enemy lines: you don't have a chance of capturing these planets, as you can never reinforce them.
      # * Future-predict forked-attack scenarios. When you attack two far away targets and the enemy can only defend one, you should capture at least one.
    end
  end
  include MasterplanStrategy
end
