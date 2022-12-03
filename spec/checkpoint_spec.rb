# frozen_string_literal: true

RSpec.describe PeriodicJob::Checkpoint, type: :model do

  describe 'model' do
    it 'is a mongoid document ' do
      is_expected.to be_mongoid_document
    end

    it 'has timestamps' do
      is_expected.to have_timestamps.shortened
    end

    describe 'fields' do
      describe 'name' do
        it 'is of type StringifiedSymbol' do
          is_expected.to have_field(:name).of_type Mongoid::StringifiedSymbol
        end

        it 'is required' do
          is_expected.to validate_presence_of :name
        end
      end

      describe 'reached_at' do
        it 'is of type Time' do
          is_expected.to have_field(:reached_at).of_type Time
        end
      end
    end
  end

  describe 'creating checkpoints' do
    it 'implicitly creates a new checkpoint with the given name' do
      expect(PeriodicJob::Checkpoint[:foo]).to be_a_kind_of PeriodicJob::Checkpoint
      expect(PeriodicJob::Checkpoint.find_by(name: :foo).name).to eq :foo
      expect(PeriodicJob::Checkpoint[:foo].age).to be_nil
    end

    it 'rejects empty names' do
      expect(PeriodicJob::Checkpoint[nil]).to be_nil
    end

    context 'checkpoint already exists' do
      before { PeriodicJob::Checkpoint[:foo] }
      it 'returns same checkpoint' do
        id = PeriodicJob::Checkpoint.find_by(name: :foo).id
        expect(PeriodicJob::Checkpoint[:foo].id).to eq id
      end
    end
  end

  describe 'advancing checkpoints' do
    it 'advances if first time' do
      expect(PeriodicJob::Checkpoint[:foo].advance_if_older_than 0.second).to be_truthy
      expect(PeriodicJob::Checkpoint[:foo].age).to be_within(0.1.seconds).of 0.seconds
    end

    context 'after initial advancement' do
      before { PeriodicJob::Checkpoint[:foo].advance_if_older_than 0 }
      it 'if does not advance if time is not up' do
        expect(PeriodicJob::Checkpoint[:foo].advance_if_older_than 1.second).to be_falsey
      end
      it 'if advances if time is up' do
        Timecop.travel 1.second do
          expect(PeriodicJob::Checkpoint[:foo].age).to be_within(0.1.seconds).of 1.second
          expect(PeriodicJob::Checkpoint[:foo].advance_if_older_than 1.second).to be_truthy
          expect(PeriodicJob::Checkpoint[:foo].age).to be_within(0.1.seconds).of 0.seconds
        end
      end
    end

    context 'last checkpoint is more than 10 minutes into the future' do
      before do
        Timecop.travel 11.minutes.from_now do
          PeriodicJob::Checkpoint[:foo].advance_if_older_than 0
        end
      end

      it 'ignores that checkpoint and advances anyway' do
        expect(PeriodicJob::Checkpoint[:foo].age).to be_within(0.1.seconds).of -11.minutes
        expect(PeriodicJob::Checkpoint[:foo].advance_if_older_than 0.seconds).to be_truthy
        expect(PeriodicJob::Checkpoint[:foo].age).to be_within(0.1.seconds).of 0.seconds
      end
    end
  end

end