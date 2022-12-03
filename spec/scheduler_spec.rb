# frozen_string_literal: true

RSpec.describe PeriodicJob::Scheduler, type: :model do
  let(:scheduler) { subject }
  let(:counts) { Hash.new 0 }

  describe 'calling job handler' do
    it 'calls job handler' do
      expect do |b|
        scheduler.every 0, :foo, &b
        scheduler.tick
      end.to yield_with_args :foo
    end

    it 'calls the job handler once the interval has passed' do
      expect do |b|
        scheduler.every 1, :foo, &b
        scheduler.tick
        Timecop.travel(1) { scheduler.tick }
      end.to yield_control.once
    end

    it 'schedules the next iteration from the end of the previous completes' do
      scheduler.every 0.100, :foo do
        counts[:foo] += 1
        sleep 0.100
      end

      run_until = Time.now + 0.490

      while Time.now < run_until do
        sleep 0.010
        scheduler.tick
      end

      # job will run first time at 100ms for 100ms, then 100ms elapses, then job runs for 100ms again - it should run 2 times within 490ms
      expect(counts).to eq foo: 2
    end

    it 'calls the job handler every time the interval has passed' do
      expect do |b|
        scheduler.every 1, :foo, &b
        Timecop.travel(1) { scheduler.tick }
        Timecop.travel(1.5) { scheduler.tick }
        Timecop.travel(2) { scheduler.tick }
        Timecop.travel(2.5) { scheduler.tick }
        Timecop.travel(3) { scheduler.tick }
        Timecop.travel(3.5) { scheduler.tick }
      end.to yield_control.thrice
    end

    it 'can handle several jobs at once' do
      scheduler.every 1, :foo do counts[:foo] += 1 end
      scheduler.every 2, :bar do counts[:bar] += 1 end

      Timecop.travel(1) { scheduler.tick }
      Timecop.travel(1.5) { scheduler.tick }
      Timecop.travel(2) { scheduler.tick }
      Timecop.travel(2.5) { scheduler.tick }
      Timecop.travel(3) { scheduler.tick }
      Timecop.travel(3.5) { scheduler.tick }

      expect(counts).to eq foo: 3, bar: 1
    end

    it 'different schedules on same channel share checkpoints' do
      scheduler2 = PeriodicJob::Scheduler.new

      scheduler.every 1.second, :foo do counts[:count1] += 1 end
      scheduler2.every 1.second, :foo do counts[:count2] += 1 end

      10.times do |time|
        Timecop.travel(time) do
          if time.even?
            scheduler.tick
            scheduler2.tick
          else
            scheduler2.tick
            scheduler.tick
          end
        end
      end

      expect(counts[:count1] + counts[:count2]).to eq 9
      expect(counts[:count1]).to be > 0
      expect(counts[:count2]).to be > 0
    end
  end

  describe 'error handling' do
    context 'no error handler defined' do
      it 'suppresses exceptions' do
        scheduler.every 0, :foo do
          counts[:foo] += 1
          raise 'Error'
        end

        scheduler.tick

        expect(counts).to eq foo: 1
      end
    end

    context 'with error handler defined' do
      before do
        scheduler.error_handler do |e, job_id|
          counts[[e.message, job_id]] += 1
        end
      end

      it 'calls the error handler' do
        scheduler.every 0, :foo do
          raise 'Error'
        end

        scheduler.tick

        expect(counts).to eq ['Error',:foo] => 1
      end

      it 'job continues to schedule after error' do
        scheduler.every 1, :foo do counts[:foo] += 1; raise 'ErrorFoo' end
        scheduler.every 2, :bar do counts[:bar] += 1; raise 'ErrorBar' end

        Timecop.travel(1) { scheduler.tick }
        Timecop.travel(1.5) { scheduler.tick }
        Timecop.travel(2) { scheduler.tick }
        Timecop.travel(2.5) { scheduler.tick }
        Timecop.travel(3) { scheduler.tick }
        Timecop.travel(3.5) { scheduler.tick }

        expect(counts).to eq foo: 3, ['ErrorFoo', :foo] => 3, bar: 1, ['ErrorBar', :bar] => 1
      end
    end

    context 'before hook' do
      it 'calls before hook before a job' do
        scheduler.before do |job_id|
          expect(job_id).to eq :foo
          counts[:before] += 1
        end

        scheduler.every(0, :foo) { counts[:foo] += 1 }
        scheduler.tick

        expect(counts).to eq foo: 1, before: 1
      end

      context 'without error handler' do
        it 'suppresses errors in the hook' do
          scheduler.before do
            counts[:before] += 1
            raise 'Error'
          end

          scheduler.every(0, :foo) { counts[:foo] += 1 }
          scheduler.tick

          expect(counts).to eq foo: 1, before: 1
        end
      end

      context 'with error handler' do
        it 'reports errors in the hook' do
          scheduler.error_handler do |e, job_id|
            counts[[e.message, job_id]] += 1
          end

          scheduler.before do
            counts[:before] += 1
            raise 'Error'
          end

          scheduler.every(0, :foo) { counts[:foo] += 1 }
          scheduler.tick

          expect(counts).to eq foo: 1, before: 1, ['Error', :foo] => 1
        end
      end

    end

    context 'after hook' do
      it 'calls after hook after a job' do
        scheduler.after do |job_id|
          expect(job_id).to eq :foo
          counts[:after] += 1
        end

        scheduler.every(0, :foo) { counts[:foo] += 1 }
        scheduler.tick

        expect(counts).to eq foo: 1, after: 1
      end

      context 'without error handler' do
        it 'suppresses errors in the hook' do
          scheduler.after do
            counts[:after] += 1
            raise 'Error'
          end

          scheduler.every(0, :foo) { counts[:foo] += 1 }
          scheduler.tick

          expect(counts).to eq foo: 1, after: 1
        end
      end

      context 'with error handler' do
        it 'reports errors in the hook' do
          scheduler.error_handler do |e, job_id|
            counts[[e.message, job_id]] += 1
          end

          scheduler.after do
            counts[:after] += 1
            raise 'Error'
          end

          scheduler.every(0, :foo) { counts[:foo] += 1 }
          scheduler.tick

          expect(counts).to eq foo: 1, after: 1, ['Error', :foo] => 1
        end
      end

    end
  end

end