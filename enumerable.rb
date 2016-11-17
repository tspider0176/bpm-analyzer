module Enumerable
  def zip_with(*others, &block)
    zip(*others).map &block
  end
end
