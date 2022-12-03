# frozen_string_literal: true

module PeriodicJob
  class Job
    attr_reader :interval
    attr_reader :job_id
    attr_reader :block
    attr_reader :run_after
    attr_reader :error_handler
    attr_reader :before
    attr_reader :after

    def initialize(interval, job_id, block, error_handler, before, after)
      @interval = interval
      @job_id = job_id
      @block = block
      @error_handler = error_handler
      @before = before
      @after = after
      schedule
    end

    def checkpoint
      Checkpoint[@job_id]
    end

    def tick
      if checkpoint.advance_if_older_than @run_after
        run
        schedule
      end
    end

    private

    def run
      protected_before
      protected_call
      protected_after
    end

    def protected_before
      begin
        @before&.call @job_id
      rescue => e
        error_handler&.call e, @job_id
      end
    end

    def protected_call
      begin
        @block.call @job_id
      rescue => e
        @error_handler&.call e, @job_id
      end
    end

    def protected_after
      begin
        @after&.call @job_id
      rescue => e
        @error_handler&.call e, @job_id
      end
    end

    def schedule
      checkpoint.advance_if_older_than 0 if checkpoint.age.nil?
      @run_after = checkpoint.age + @interval
    end
  end
end
