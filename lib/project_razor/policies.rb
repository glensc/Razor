module ProjectRazor
  # Used for binding of policy+models to a node
  # this is permanent unless a user removed the binding or deletes a node
  class Policies < ProjectRazor::Object
    include(ProjectRazor::Logging)
    include(Singleton)

    POLICY_PREFIX = "ProjectRazor::PolicyTemplate::"
    MODEL_PREFIX = "ProjectRazor::ModelTemplate::"


    # table
    # ensure unique
    # store as single object


    class PolicyTable < ProjectRazor::Object
      attr_accessor :p_table
      def initialize(hash)
        super()
        @uuid = "policy_table"
        @_collection = :policy_table
        @p_table = []
        from_hash(hash)
      end

      def get_line_number(policy_uuid)
        @p_table.each_with_index { |p_item_uuid, index| return index if p_item_uuid == policy_uuid }
      end

      def add_p_item(policy_uuid)
        @p_table.push policy_uuid unless exists_in_array?(policy_uuid)
        update_table
      end


      def resolve_duplicates
        @p_table.inject(Hash.new(0)) {|h,v| h[v] += 1; h}.reject{|k,v| v==1}.keys
      end

      def remove_missing
        policy_uuid_array = get_data.fetch_all_objects(:policy).map {|p| p.uuid}
        @p_table.map! do
          |p_item_uuid|
          p_item_uuid if policy_uuid_array.select {|uuid| uuid == p_item_uuid}.count > 0
        end
        @p_table.compact!
      end

      def exists_in_array?(policy_uuid)
        @p_table.each { |p_item_uuid|
          return true if p_item_uuid == policy_uuid }
        false
      end

      def update_table
        resolve_duplicates
        remove_missing
        self.update_self
      end

      def move_higher(policy_uuid)
        policy_index = find_policy_index(policy_uuid)
        unless policy_index == 0
          @p_table[policy_index], @p_table[policy_index - 1] = @p_table[policy_index - 1], @p_table[policy_index]
          update_table
          true
        end
        false
      end

      def move_lower(policy_uuid)
        policy_index = find_policy_index(policy_uuid)
        puts "#{policy_index} == #{(@p_table.count - 1)}"
        unless policy_index == (@p_table.count - 1)
          @p_table[policy_index], @p_table[policy_index + 1] = @p_table[policy_index + 1], @p_table[policy_index]
          update_table
          true
        end
        false
      end

      def find_policy_index(policy_uuid)
        @p_table.index(policy_uuid)
      end

    end

    def policy_table
      pt = get_data.fetch_object_by_uuid(:policy_table, "policy_table")
      return pt if pt
      pt = ProjectRazor::Policies::PolicyTable.new({})
      pt = get_data.persist_object(pt)
      raise ProjectRazor::Error::CannotCreatePolicyTable, "Cannot create policy table" unless pt
      pt
    end


    # Get Array of Models that are compatible with a Policy Template
    def get_models(model_template)
      models = []
      get_data.fetch_all_objects(:model).each do
      |mc|
        models << mc if mc.template == model_template
      end
      models
    end

    # Get Array of Policy Templates available
    def get_templates
      temp_hash = {}
      ObjectSpace.each_object do
      |object_class|
        if object_class.to_s.start_with?(POLICY_PREFIX) &&
            object_class.to_s != POLICY_PREFIX &&
            (/#/ =~ object_class.to_s) == nil
          temp_hash[object_class.to_s] = object_class.to_s.sub(POLICY_PREFIX,"").strip
        end
      end
      policy_template_array = {}
      temp_hash.each_value {|x| policy_template_array[x] = x}
      policy_template_array.each_value.collect {|x| x}
      valid_templates = []
      policy_template_array.each do
      |policy_template|
        policy_template_obj = Object.full_const_get(POLICY_PREFIX + policy_template[0]).new({})
        valid_templates << policy_template_obj if !policy_template_obj.hidden
      end
      valid_templates
    end

    def get_model_templates
      temp_hash = {}
      ObjectSpace.each_object do
      |object_class|
        if object_class.to_s.start_with?(MODEL_PREFIX) && object_class.to_s != MODEL_PREFIX
          temp_hash[object_class.to_s] = object_class.to_s.sub(MODEL_PREFIX,"").strip
        end
      end
      model_template_array = {}
      temp_hash.each_value {|x| model_template_array[x] = x}
      model_template_array.each_value.collect {|x| x}
      valid_templates = []
      model_template_array.each do
      |model_template|
        model_template_obj = Object.full_const_get(MODEL_PREFIX + model_template[0]).new({})
        valid_templates << model_template_obj if !model_template_obj.hidden
      end
      valid_templates
    end

    def new_policy_from_template_name(policy_template_name)
      get_templates.each do
      |template|
        return template if template.template.to_s == policy_template_name
      end
      template
    end

    def is_policy_template?(policy_template_name)
      get_templates.each do
      |template|
        return true if template.template.to_s == policy_template_name
      end
      false
    end

    def is_model_template?(model_name)
      get_model_templates.each do
      |template|
        return template if template.name == model_name
      end
      false
    end


    def get
      # Get all the policy templates
      policies_array = get_data.fetch_all_objects(:policy)
      logger.debug "Total policies #{policies_array.count}"
      # Sort the policies based on line_number
      policies_array.sort! do
      |a,b|
        a.line_number <=> b.line_number
      end
      policies_array
    end

    # When adding a policy
    # Line number is preserved for updates, line_number is last for new

    def add(new_policy)
      get_data.persist_object(new_policy)
      pt = policy_table
      pt.add_p_item(new_policy.uuid)
    end

    alias :update :add

    def get_line_number(policy_uuid)
      pt = policy_table
      pt.add_p_item(policy_uuid)
      pt.get_line_number(policy_uuid)
    end

    # Down is up in numbers (++)
    def move_policy_up(policy_uuid)
      pt = policy_table
      pt.add_p_item(policy_uuid)
      pt.move_higher(policy_uuid)
    end

    def move_policy_down(policy_uuid)
      pt = policy_table
      pt.add_p_item(policy_uuid)
      pt.move_lower(policy_uuid)
    end

    def policy_exists?(new_policy)
      get_data.fetch_object_by_uuid(:policy, new_policy)
    end

  end
end