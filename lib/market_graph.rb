# frozen_string_literal: true

module MarketGraph
  module_function

  def derive_pairs(pair_index)
    wanted_pairs = [
      %w[USD TRY],
      %w[TRY USD],
      %w[EUR TRY],
      %w[TRY EUR],
      %w[XAU TRY],
      %w[XAG TRY],
      %w[BTC TRY],
      %w[ETH TRY]
    ]

    wanted_pairs.each_with_object({}) do |(from, to), memo|
      conversion = convert(pair_index, from:, to:, amount: 1)
      memo["#{from}_#{to}"] = conversion[:rate] if conversion
    end
  end

  def convert(pair_index, from:, to:, amount: 1)
    from = from.to_s.upcase
    to = to.to_s.upcase
    return { from:, to:, path: [from], rate: 1.0, result: amount.to_f } if from == to

    graph = build_graph(pair_index)
    queue = [[from, 1.0, [from]]]
    visited = { from => true }

    until queue.empty?
      current, rate, path = queue.shift
      graph.fetch(current, {}).each do |neighbor, edge_rate|
        next if visited[neighbor]

        next_rate = rate * edge_rate
        next_path = path + [neighbor]
        return { from:, to:, path: next_path, rate: next_rate, result: amount.to_f * next_rate } if neighbor == to

        visited[neighbor] = true
        queue << [neighbor, next_rate, next_path]
      end
    end

    nil
  end

  def build_graph(pair_index)
    pair_index.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |(pair, details), graph|
      base, quote = pair.split('_', 2)
      rate = details[:price].to_f
      next unless rate.positive?

      graph[base][quote] = rate
      graph[quote][base] = 1.0 / rate
    end
  end
end
