module LT
  module Seeds
    class << self
      def load_seed
        LT.env.load_all_models

        # This loads all the seeds in the root (common seeds)
        retval = load_seeds

        # This runs all seeds for environment, eg "test"
        env_seeds = File::join('./',LT.env.run_env)
        retval += LT::Seeds::load_seeds(env_seeds)
        retval
      end

      # This looks in the path provided for files globbing '*.seeds.rb' files,
      # "requiring" each one.
      # The assumption is that each file will know how to load itself
      def load_seeds(path = './')
        fullpath = File::expand_path(File::join(LT.env.seed_path,path))
        seedfiles = Dir::glob(File::join(fullpath, '*.seeds.rb'))
        seedfiles.each do |seedfile|
          load File::expand_path(seedfile)
        end
      end
    end #class << self
  end # Seeds
end
