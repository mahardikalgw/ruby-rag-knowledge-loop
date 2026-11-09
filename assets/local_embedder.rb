module Ai
  # Local, dependency-free embeddings for seeding and demos.
  #
  # A hashing trick over the same normalised terms the lexical search uses: each term sets one bucket
  # (term hash mod dimensions) and the vector is L2-normalised, so cosine distance compares term overlap.
  # Deterministic for the same text, no network, no key. Semantic quality is deliberately limited — it is
  # functionally a sparse lexical vector — which is why production uses Ai::Embedder instead.
  class LocalEmbedder
    def initialize(dimensions: Ai.embedding_dimensions)
      @dimensions = dimensions
    end

    def available? = true
    def model_name = "local-hash"

    def embed(text)
      counts = Array.new(@dimensions, 0.0)
      Knowledge::Search.terms(text.to_s).each do |term|
        counts[Zlib.crc32(term) % @dimensions] += 1.0
      end

      norm = Math.sqrt(counts.sum { |value| value * value })
      return counts if norm.zero?

      counts.map { |value| value / norm }
    end

    def embed_many(texts) = texts.map { |text| embed(text) }
  end
end
