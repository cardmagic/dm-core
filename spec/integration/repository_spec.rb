require 'pathname'
require Pathname(__FILE__).dirname.expand_path.parent + 'spec_helper'

require ROOT_DIR + 'lib/data_mapper'

begin
  require 'do_sqlite3'

  DataMapper.setup(:sqlite3, "sqlite3://#{INTEGRATION_DB_PATH}")

  describe DataMapper::Repository do
    describe "finders" do
      before do
        class SerialFinderSpec
          include DataMapper::Resource

          property :id, Fixnum, :serial => true
          property :sample, String
        end

        @adapter = repository(:sqlite3).adapter

        @adapter.execute(<<-EOS.compress_lines)
          CREATE TABLE "serial_finder_specs" (
            "id" INTEGER PRIMARY KEY,
            "sample" VARCHAR(50)
          )
        EOS

        # Why do we keep testing with Repository instead of the models directly?
        # Just because we're trying to target the code we're actualling testing
        # as much as possible.
        setup_repository = repository(:sqlite3)
        100.times do
          setup_repository.save(SerialFinderSpec.new(:sample => rand.to_s))
        end
      end

      it "should return all available rows" do
        repository(:sqlite3).all(SerialFinderSpec, {}).should have(100).entries
      end

      it "should allow limit and offset" do
        repository(:sqlite3).all(SerialFinderSpec, { :limit => 50 }).should have(50).entries

        repository(:sqlite3).all(SerialFinderSpec, { :limit => 20, :offset => 40 }).map(&:id).should ==
          repository(:sqlite3).all(SerialFinderSpec, {})[40...60].map(&:id)
      end

      it "should lazy-load missing attributes" do
        sfs = repository(:sqlite3).all(SerialFinderSpec, { :fields => [:id], :limit => 1 }).first
        sfs.should be_a_kind_of(SerialFinderSpec)
        sfs.should_not be_a_new_record

        sfs.instance_variables.should_not include('@sample')
        sfs.sample.should_not be_nil
      end

      it "should translate an Array to an IN clause" do
        ids = repository(:sqlite3).all(SerialFinderSpec, { :limit => 10 }).map(&:id)
        results = repository(:sqlite3).all(SerialFinderSpec, { :id => ids })

        results.size.should == 10
        results.map(&:id).should == ids
      end

      after do
        @adapter.execute('DROP TABLE "serial_finder_specs"')
      end

    end
  end
rescue LoadError
  warn "integration/repository_spec not run! Could not load do_sqlite3."
end
