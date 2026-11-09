# Copy into test/support/ai_fake.rb.
#
# Scripted model for tests. It lives in test/support on purpose: nothing under app/ may answer a public
# visitor with canned text. When an installation has no key, Ai.client returns Ai::Unavailable and the
# assistant says it is unavailable — which is honest, whereas a scripted reply would be a lie.
class AiFake
  attr_reader :calls

  # triage: Hash returned for the JSON triage call; answer: String returned for the chooser call;
  # error: raised on every call (an instance of Ai::Timeout, Ai::Malformed, ...).
  def initialize(triage: {}, answer: "", error: nil)
    @triage = triage
    @answer = answer
    @error = error
    @calls = []
  end

  def available? = @error.nil?

  def complete(messages:, json: false, **)
    @calls << { messages: messages, json: json }
    raise @error if @error

    # The assistant calls twice per turn: triage first, then the chooser. The fake tells them apart the
    # way the contract does — the chooser prompt carries the <KNOWLEDGE> candidate block.
    return JSON.generate(@triage) if json && !chooser_prompt?(messages)

    @answer
  end

  def last_prompt = @calls.last&.dig(:messages)&.map { |message| message[:content] }&.join("\n").to_s

  private
    # The real block opens the tag and breaks the line; the triage-side sentence only names the tag
    # inside prose, so a substring check would misclassify every triage call as a chooser call.
    def chooser_prompt?(messages)
      Array(messages).any? { |message| message[:content].to_s.include?("<KNOWLEDGE>\n") }
    end
end
