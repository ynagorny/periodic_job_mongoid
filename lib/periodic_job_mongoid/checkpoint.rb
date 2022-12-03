# frozen_string_literal: true

module PeriodicJob
  class Checkpoint
    include Mongoid::Document
    include Mongoid::Timestamps::Short

    # checkpoints reached this far in the future will be considered erroneous and will be treated as unreached
    FUTURE_CUTOFF_TIME = 10.minutes

    field :name, type: StringifiedSymbol
      validates_presence_of :name

    field :reached_at, type: Time

    def age
      Time.now - reached_at if reached_at
    end

    def advance_if_older_than(max_age)
      time_now = Time.now.utc
      result = self.class.where(id: self.id)
        .and(self.class
          .or(
            { reached_at: nil },
            { :reached_at.lte => time_now - max_age },
            { :reached_at.gte => time_now + FUTURE_CUTOFF_TIME },
            ).selector
        ).find_one_and_update({'$set' => { reached_at: time_now }})

      !result.nil?
    end

    def self.[](name)
      return nil if name.to_s.strip.empty?
      Checkpoint.find_or_create_by name: name
    end
  end
end
