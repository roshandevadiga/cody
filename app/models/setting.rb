# frozen_string_literal: true

class Setting < ApplicationRecord
  belongs_to :repository, required: false

  validates :key, presence: true, uniqueness: { scope: :repository_id }
  validates :value, presence: true

  def read
    Transit::Reader.new(:json, StringIO.new(self.value)).read
  end

  def set(value)
    io = StringIO.new(String.new, "w+")
    Transit::Writer.new(:json, io).write(value)
    self.value = io.string
  end

  class << self
    def lookup(key)
      return nil unless exists?(key: key)
      raw = find_by(key: key).value
      Transit::Reader.new(:json, StringIO.new(raw)).read
    end

    def assign(key, value)
      io = StringIO.new(String.new, "w+")
      Transit::Writer.new(:json, io).write(value)
      s = find_or_initialize_by(key: key)
      s.value = io.string
      s.save!
      s
    end
  end
end
