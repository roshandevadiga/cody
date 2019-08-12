# frozen_string_literal: true

class CommandInvocation < ApplicationRecord
  # Record an invocation of a command. This is a convenience method that wraps
  # creation of the record in an exception handler so that exceptions can still
  # be reaised and reported, but do not cause the program to stop.
  def self.record_invocation(attributes)
    begin
      self.create!(attributes)
    rescue
      Raven.capture_exception($ERROR_INFO)
    end
  end
end
