require 'active_record'
require 'edge'

module LT
  module ActiveRecordUtil
    # Purpose: Include in AR models to connect them to Gifts
    #          via a join table.
    module ActsAsMethods
      def acts_as_tagged
        include LT::ActiveRecordUtil::Tags
      end

      def acts_as_paginatable
        include LT::ActiveRecordUtil::Pagination
      end

      def acts_as_draft
        include LT::ActiveRecordUtil::Draft
      end
    end
    ActiveRecord::Base.extend(ActsAsMethods)

    module Tags
      # this loads our class methods when called by 'include'
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:class_init)
      end

      module ClassMethods
        # creates an tag entity, and creates its parent by name if necessary
        # {name: "name", parent: {name: "parent"}}
        def find_or_create_with_parent(obj)
          parent = obj.delete(:parent) || {:name => ''}
          parent = self.find_or_create_by(parent)
          obj[:parent_id] = parent.id
          self.find_or_create_by(obj)
        end

        private
        def class_init
          acts_as_forest :order => "name" # adds "with_descendants" recursive capability (edge gem)
          belongs_to :parent, class_name: self.to_s, foreign_key: "parent_id"
          has_many :children, class_name: self.to_s, foreign_key: "parent_id"
          scope :members, -> (ids) {where(id: ids).with_descendants}
          # select the upper most tree member (assumes there is only one root)
          def top
            self.root.first
          end
        end
      end # ClassMethods

      # Instance methods go here...
      def top
        self.root
      end
    end # Tags

    module Pagination
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def page(page, per_page=10)
          self.offset(per_page*(page-1)).limit(per_page)
        end

        def total_pages(per_page=10)
          total = (self.count + per_page - 1)/per_page 
          total > 0 ? total : 1
        end
      end # ClassMethods

    end # Pagination

    module Draft
      def self.included(base)
        base.class_eval do
          scope :published, ->{ where(draft: false) }
          scope :drafts, ->{ where(draft: true) }
          belongs_to :draft_user, class_name: 'User'
        end
      end

      def draft?
        draft
      end

      def published?
        !draft
      end
    end # Proposal

    module Raw
      # returns an array of all the tables in schema public for current connection
      def all_tables
        all_tables_sql = "SELECT * FROM information_schema.tables where "+
          "table_schema = 'public' and table_name <> 'schema_migrations'"
        retval = []
        results = ActiveRecord::Base.connection.execute(all_tables_sql)
        results.each_with_index do |row, i|
          retval << results[i]["table_name"]
        end
        retval
      end

      def truncate_all
        raise(LT::Critical, "Truncate all is prohibited in production - do it manually.") if LT.env.production?
        all_tables.each do |table_name|
          ActiveRecord::Base.connection.execute("TRUNCATE #{table_name}")
        end
      end
    end
  end
end
