# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

module ProjectRazor
  module SliceUtil
    module Common

      # here, we define a Stack class that simply delegates the equivalent "push", "pop",
      # "to_s" and "clear" calls to the underlying Array object using the delegation
      # methods provided by Ruby through the Forwardable class.  We could do the same
      # thing using an Array, but that wouldn't let us restrict the methods that
      # were supported by our Stack to just those methods that a stack should have

      require "forwardable"

      class Stack
        extend Forwardable
        def_delegators :@array, :push, :pop, :to_s, :clear, :count

        # initializes the underlying array for the stack
        def initialize
          @array = []
        end

        # looks at the last element pushed onto the stack
        def look
          @array.last
        end

        # peeks down to the n-th element in the stack (zero is the top,
        # if the 'n' value that is passed is deeper than the stack, it's
        # an error (and will result in an IndexError being thrown)
        def peek(n = 0)
          stack_idx = -(n+1)
          @array[stack_idx]
        end

      end

      class ObjectTemplate < ProjectRazor::Object
        attr_accessor :template, :description

        def initialize(template, description)
          @template, @description = template, description
        end

        def print_header
          return "Template", "Description"
        end

        def print_items
          return @template, @description
        end

        def line_color
          :white_on_black
        end

        def header_color
          :red_on_black
        end
      end

      class ObjectPlugin < ObjectTemplate
        attr_accessor :plugin, :description

        def initialize(plugin, description)
          @plugin, @description = plugin, description
        end

        def print_header
          return "Plugin", "Description"
        end

        def print_items
          return @plugin, @description
        end
      end

      def get_noun(classname)
        noun = nil
        begin
          File.open(File.join(File.dirname(__FILE__), "api_mapping.yaml")) do
          |file|
            api_map = YAML.load(file)

            api_map.sort! {|a,b| a[:namespace].length <=> b[:namespace].length}.reverse!
            api_map.each do
            |api|
              noun = api[:noun] if classname.start_with?(api[:namespace])
            end
          end
        rescue => e
          logger.error e.message
          return nil
        end
        noun
      end

      # Returns all child templates from prefix
      def get_child_templates(namespace_prefix)
        temp_hash = {}
        ObjectSpace.each_object do
        |object_class|
          if object_class.to_s.start_with?(namespace_prefix) && object_class.to_s != namespace_prefix && !(object_class.to_s =~ /#/)
            temp_hash[object_class.to_s] = object_class.to_s.sub(namespace_prefix,"").strip
          end
        end
        object_array = {}
        temp_hash.each_value {|x| object_array[x] = x}

        object_array.each_value.collect { |x| x }.collect {|x| Object::full_const_get(namespace_prefix + x).new({})}
      end

      alias :get_child_types :get_child_templates

      # returns child templates as ObjectType (used for printing)
      def get_templates_as_object_templates(namespace_prefix)
        get_child_templates(namespace_prefix).map do
        |template|
          ObjectTemplate.new(template.template.to_s, template.description) unless template.hidden
        end.compact
      end

      def get_plugins_as_object_plugins(namespace_prefix)
        get_child_templates(namespace_prefix).map do
        |plugin|
          ObjectPlugin.new(plugin.plugin.to_s, plugin.description) unless plugin.hidden
        end.compact
      end

      # Checks to make sure an arg is a format that supports a noun (uuid, etc))
      def validate_arg(*arg)
        if arg.respond_to?(:each)
          arg.each do
          |a|
            unless a != nil && (a =~ /^\{.*\}$/) == nil && a != ''
              return false
            end
          end
        else
          arg != nil && (arg =~ /^\{.*\}$/) == nil && arg != ''
        end
      end



      # Gets a selection of objects for slice
      # @param noun [String] name of the object for logging
      # @param collection [Symbol] collection for object

      def get_object(noun, collection, uuid = nil)
        logger.debug "Query #{noun} called"

        # If uuid provided just grab and return
        if uuid
          return return_objects_using_uuid(collection, uuid)
        end

        # Check if REST-driven request
        if @web_command
          # Get request filter JSON string
          @filter_json_string = @command_array.shift
          # Check if we were passed a filter string
          if @filter_json_string != "{}" && @filter_json_string != nil
            @command = "query_with_filter"
            begin
              # Render our JSON to a Hash
              return return_objects_using_filter(JSON.parse(@filter_json_string), collection)
            rescue StandardError => e
              # We caught an error / likely JSON. We return the error text as a Slice error.
              slice_error(e.message, false)
            end
          else
            @command = "#{noun}_query_all"
            return return_objects(collection)
          end
          # Is CLI driven
        else
          return_objects(collection)
        end
      end

      # Return objects using a filter
      # @param filter [Hash] contains key/values used for filtering
      # @param collection [Symbol] collection symbol
      def return_objects_using_filter(collection, filter_hash)
        setup_data
        @data.fetch_objects_by_filter(filter_hash, collection)
      end

      # Return all objects (no filtering)
      def return_objects(collection)
        setup_data
        @data.fetch_all_objects(collection)
      end

      # Return objects using uuid
      # @param filter [Hash] contains key/values used for filtering
      # @param collection [Symbol] collection symbol
      def return_objects_using_uuid(collection, uuid)
        setup_data
        @data.fetch_object_by_uuid_pattern(collection, uuid)
      end


      def print_object_details_cli(obj)
        obj.instance_variables.each do
        |iv|
          unless iv.to_s.start_with?("@_")
            key = iv.to_s.sub("@", "")
            print "#{key}: "
            print "#{obj.instance_variable_get(iv)}  ".green
          end
        end
        print "\n"
      end

      def print_model_configs(model_array)
        unless @web_command
          puts "Model Configs:"
          unless @verbose
            model_array.each do |model|
              print "   Label: " + "#{model.label}".yellow
              print "  Type: " + "#{model.name}".yellow
              print "  Description: " + "#{model.description}".yellow
              print "\n  Model UUID: " + "#{model.uuid}".yellow
              print "  Image UUID: " + "#{model.image_uuid}".yellow if model.instance_variable_get(:@image_uuid) != nil
              print "\n\n"
            end
          else
            model_array.each { |model| print_object_details_cli(model) }
          end
        else
          model_array = model_array.collect { |model| model.to_hash }
          slice_success(model_array, false)
        end
      end

      def print_model_templates(templates_array)
        if @web_command
          templates_array = templates_array.collect { |template| template.to_hash }
          slice_success(templates_array, false)
        else
          puts "Valid Model Templates:"
          if @verbose
            templates_array.each { |template| print_object_details_cli(template) }
          else
            templates_array.each { |template| puts "\t#{template.name} ".yellow + " :  #{template.description}" }
          end
        end
      end

      # Handles printing of image details to CLI
      # @param [Array] images_array
      def print_images(images_array)
        unless @web_command
          puts "Images:"

          unless @verbose
            images_array.each do
            |image|
              image.print_image_info(@data.config.image_svc_path)
              print "\n"
            end
          else
            images_array.each do
            |image|
              image.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{image.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          images_array = images_array.collect { |image| image.to_hash }
          slice_success(images_array, false)
        end
      end

      # Handles printing of node details to CLI or REST
      # @param [Hash] node_array
      def print_node(node_array)
        unless @web_command
          puts "Nodes:"

          unless @verbose
            node_array.each do
            |node|
              print "\tuuid: "
              print "#{node.uuid}  ".green
              print "last state: "
              print "#{node.last_state}  ".green
              print "name: " unless node.name == nil
              print "#{node.name}  ".green unless node.name == nil
              print "\n"
            end
          else
            node_array.each do
            |node|
              node.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{node.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          node_array = node_array.collect { |node| node.to_hash }
          slice_success(node_array,false)
        end
      end

      #def print_policy_bound_log(bound_policy)
      #  unless @web_command
      #    puts "Bound policy log for Node(#{bound_policy.node_uuid}):"
      #
      #    unless @verbose
      #      print "\t" + "(Model call) (Action) | (Original state) => (New state) | (Time)\n".red_on_black
      #      bound_policy.model.log.each do
      #      |log_item|
      #        print "\t#{log_item["method"]}##{log_item["action"]} | ".white_on_black
      #        print "#{log_item["old_state"]} => #{log_item["state"]}".white_on_black
      #        print " | #{Time.at(log_item["timestamp"].to_i)}\n".white_on_black
      #      end
      #
      #    else
      #      bound_policy.model.log.each do
      #      |log_item|
      #        log_item.instance_variables.each do
      #        |iv|
      #          unless iv.to_s.start_with?("@_")
      #            key = iv.to_s.sub("@", "")
      #            print "#{key}: "
      #            print "#{log_item.instance_variable_get(iv)}  ".green
      #          end
      #        end
      #        print "\n"
      #      end
      #    end
      #  else
      #    slice_success(bound_policy.model.log, false)
      #  end
      #end

      def print_tag_rule_old(rule_array)
        if rule_array.respond_to?(:each)
          rule_array = rule_array.collect { |rule| rule.to_hash }
          slice_success(rule_array, false)
        else
          slice_success(rule_array.to_hash, false)
        end
      end

      def print_tag_rule(object_array)
        unless @web_command
          puts "Tag Rules:"

          unless @verbose

            print_array = []
            header = []
            line_color = :green
            header_color = :white

            object_array.each do
            |rule|
              print_array << rule.print_items
              header = rule.print_header
              line_color = rule.line_color
              header_color = rule.header_color
            end

            print_array.unshift header if header != []
            print_table(print_array, line_color, header_color)
          else
            object_array.each do
            |rule|
              rule.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{rule.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          object_array = object_array.collect { |rule| rule.to_hash }
          slice_success(object_array, false)
        end
      end

      def print_tag_matcher(object_array)
        unless @web_command
          puts "\t\tTag Matchers:"

          unless @verbose
            object_array.each do
            |matcher|
              print "   Key: " + "#{matcher.key}".yellow
              print "  Compare: " + "#{matcher.compare}".yellow
              print "  Value: " + "#{matcher.value}".yellow
              print "  Inverse: " + "#{matcher.inverse}".yellow
              print "\n"
            end
          else
            object_array.each do
            |matcher|
              matcher.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{matcher.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          object_array = object_array.collect { |matcher| matcher.to_hash }
          slice_success(object_array, false)
        end
      end

      def print_object_array(object_array, title = nil, options = {})
        # This is for backwards compatibility
        title = options[:title] unless title
        unless @web_command
          puts title if title
          unless object_array.count > 0
            puts "< none >".red
          end
          unless @verbose
            print_array = []
            header = []
            line_colors = []
            header_color = :white

            if object_array.count == 1 && options[:style] != :table
              puts print_single_item(object_array.first)
            else
              object_array.each do
              |obj|
                print_array << obj.print_items
                header = obj.print_header
                line_colors << obj.line_color
                header_color = obj.header_color
              end
              # If we have more than one item we use table view, otherwise use item view
              print_array.unshift header if header != []
              puts print_table(print_array, line_colors, header_color)
            end
          else
            object_array.each do
            |obj|
              obj.instance_variables.each do
              |iv|
                unless iv.to_s.start_with?("@_")
                  key = iv.to_s.sub("@", "")
                  print "#{key}: "
                  print "#{obj.instance_variable_get(iv)}  ".green
                end
              end
              print "\n"
            end
          end
        else
          if @uri_root
            object_array = object_array.collect do |object|
              if object.class == ProjectRazor::SliceUtil::Common::ObjectTemplate ||
                  object.class == ProjectRazor::SliceUtil::Common::ObjectPlugin
                object.to_hash
              else
                obj_web = object.to_hash
                obj_web.select! { |k, v| ["@uuid", "@classname"].include?(k) } unless object_array.count == 1
                noun = get_noun(obj_web["@classname"])
                obj_web["@uri"] = "#{@uri_root}#{noun}/#{obj_web["@uuid"]}" if noun
                obj_web
              end
            end
          else
            object_array = object_array.collect { |object| object.to_hash }
          end

          slice_success(object_array)
        end
      end

      def print_single_item(obj)
        print_array = []
        header = []
        line_color = []
        print_output = ""
        header_color = :white

        if obj.respond_to?(:print_item) && obj.respond_to?(:print_item_header)
          print_array = obj.print_item
          header = obj.print_item_header
        else
          print_array = obj.print_items
          header = obj.print_header
        end
        line_color = obj.line_color
        header_color = obj.header_color
        print_array.each_with_index do
        |val, index|
          print_output << " " + "#{header[index]}".send(header_color)
          print_output << " => "
          print_output << " " + "#{val}".send(line_color) + "\n"
        end
        print_output
      end

      def print_table(print_array, line_colors, header_color)
        table = ""
        print_array.each_with_index do
        |line, li|
          line_string = ""
          line.each_with_index do
          |col, ci|
            max_col = print_array.collect {|x| x[ci].length}.max
            if li == 0
              if header_color
                line_string << "#{col.center(max_col)}  ".send(header_color)
              else
                line_string << "#{col.center(max_col)}  "
              end
            else
              if line_colors[li-1]
                line_string << "#{col.ljust(max_col)}  ".send(line_colors[li-1])
              else
                line_string << "#{col.ljust(max_col)}  "
              end
            end
          end
          table << line_string + "\n"
        end
        table
      end
    end
  end
end
