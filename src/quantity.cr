module Quantity
  extend self

  def estimate_gb(quantity : String) : Int32
    si_prefixes = Number::SI_PREFIXES[1].map &.to_s.upcase
    prefix = quantity.gsub(/^.*\d|i$/, "")

    num = quantity.to_f(strict: false)
    index = si_prefixes.index(prefix.upcase)

    raise "Invalid prefix #{prefix}" unless index

    multiplier = 10.0 ** (3 * (index - 3))

    (num * multiplier).clamp(1..Int32::MAX).to_i
  end
end
