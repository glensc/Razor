# EMC Confidential Information, protected under EMC Bilateral Non-Disclosure Agreement.
# Copyright © 2012 EMC Corporation, All Rights Reserved

require "json"

# Root ProjectRazor namespace
# @author Nicholas Weaver
module ProjectRazor
  module Slice

    # ProjectRazor Slice Node (NEW)
    # Used for policy management
    # @author Nicholas Weaver
    class Boot < ProjectRazor::Slice::Base
      # @param [Array] args
      def initialize(args)
        super(args)
        @hidden = true
        @new_slice_style = true
        @slice_commands = {:boot => "boot_call",
                           :default => :boot,
                           :else => :boot}
        @slice_name = "Boot"
        @engine = ProjectRazor::Engine.instance
      end

      def boot_call
        @command = :boot_call
        if @web_command
          # Grab next arg as json string var
          json_string = @command_array.first
          # Validate JSON
          if is_valid_json?(json_string)
            # Grab vars as hash using sanitize to strip the @ prefix if used
            @vars_hash = sanitize_hash(JSON.parse(json_string))

            if @vars_hash['mac']
              @vars_hash['hw_id'] = @vars_hash['mac']
            end
            @hw_id = @vars_hash['hw_id']
          else
            # Invalid call, somehow API has an issue - tell node to reboot
            error_reboot_node "Bad JSON"
            return
          end
        else
          slice_error("Not implemented for CLI")
          return
        end

        return slice_error("Must Provide Hardware IDs[hw_id]") unless validate_arg(@hw_id)
        @hw_id = @hw_id.split("_") unless @hw_id.respond_to?(:each)
        unless @hw_id.count > 0
          error_reboot_node "Must Provide At Least One Hardware ID [hw_id]"
          return
        end

        @hw_id.map! {|hw| hw.gsub(":","").upcase}
        logger.info "Boot called by Node (HW_ID: #{@hw_id})"
        logger.info "Calling Engine for boot script"
        puts @engine.boot_checkin(@hw_id)
      end

      def error_reboot_node(msg)
        puts "#{msg}\necho API Error, will reboot in 30 seconds\nsleep 30\nreboot\n"
      end
    end
  end
end

