# frozen_string_literal: true

module PeriodicJob
  class Scheduler

    def initialize
      @jobs = []
    end

    def every(interval, job_id, &block)
      @jobs << Job.new(interval, job_id, block, @error_handler, @before, @after)
    end

    def tick
      @jobs.each &:tick
    end

    def error_handler(&block)
      @error_handler = block
    end

    def before(&block)
      @before = block
    end
    
    def after(&block)
      @after = block
    end

  end
end
