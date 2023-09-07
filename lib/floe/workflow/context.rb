# frozen_string_literal: true

module Floe
  class Workflow
    class Context
      def initialize(context = nil, input: {})
        context = JSON.parse(context) if context.kind_of?(String)

        @context = context || {
          "Execution"    => {
            "Input" => input
          },
          "State"        => {},
          "StateHistory" => [],
          "StateMachine" => {},
          "Task"         => {}
        }
      end

      def execution
        @context["Execution"]
      end

      def started?
        execution.key?("StartTime")
      end

      def running?
        started? && !ended?
      end

      def ended?
        execution.key?("EndTime")
      end

      def state
        @context["State"]
      end

      def output
        state["Output"]
      end

      def status
        if !started?
          "pending"
        elsif running?
          "running"
        elsif state["Error"]
          "failure"
        else
          "success"
        end
      end

      def state=(val)
        @context["State"] = val
      end

      def state_history
        @context["StateHistory"]
      end

      def state_machine
        @context["StateMachine"]
      end

      def task
        @context["Task"]
      end

      def [](key)
        @context[key]
      end

      def []=(key, val)
        @context[key] = val
      end

      def dig(*args)
        @context.dig(*args)
      end

      def to_h
        @context
      end
    end
  end
end
