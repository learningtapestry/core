module LT
  module Seeds
    SEED_FILES = '.seeds.rb'
    class << self
      def seed!
        # this loads all the seeds in the root (common seeds)
        retval = LT::Seeds::load_seeds
        # This runs all seeds for environment, eg "test"
        env_seeds = File::join('./',LT.env.run_env)
        retval += LT::Seeds::load_seeds(env_seeds)
        retval
      end
      # This looks in the path provided for files globbing SEED_FILES, 
      # "requiring" each one.
      # The assumption is that each file will know how to load itself
      def load_seeds(path = './')
        fullpath = File::expand_path(File::join(LT.env.seed_path,path))
        seedfiles = Dir::glob(File::join(fullpath,'*'+SEED_FILES))
        seedfiles.each do |seedfile|
          load_seed(seedfile)           
        end
      end # load_seeds
      def load_seed(seedfile)
        load File::expand_path(seedfile)
      end
    end #class << self
  end # Seeds
end
