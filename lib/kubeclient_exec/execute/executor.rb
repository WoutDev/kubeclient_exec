# frozen_string_literal: true

require 'eventmachine'

module KubeclientExec
  module Execute
    class Executor
      EXEC_STDIN = 0
      EXEC_STDOUT = 1
      EXEC_STDERR = 2
      EXEC_DCKERR = 3 # Seems like this is used for docker errors

      attr_reader :last_stdout, :last_stderr, :last_command

      def initialize(command, url, kubeclient_options, options, &block)
        @last_command = command
        @url = url
        @kubeclient_options = kubeclient_options
        @options = options
        @on_open = block
        @suppress_errors = options[:suppress_errors]

        if options[:mode] == :adhoc
          @on_stdout = ->(_) { stop }
          @on_stderr = ->(_) { stop }
        end

        setup
      end

      def execute(command)
        raise 'ws not initialized' unless @ws

        @last_command = command

        @ws.send((command + "\n").unpack("C*").unshift(EXEC_STDIN))
      end

      def write(content)
        raise 'ws not initialized' unless @ws

        @ws.send(content.unpack("C*").unshift(EXEC_STDIN))
      end

      def on_stdout(&block)
        @on_stdout = block
      end

      def on_stderr(&block)
        @on_stderr = block
      end

      def on_close(&block)
        @on_close = block
      end

      def stop
        @ws.instance_variable_get(:@stream).close_connection_after_writing
        @on_close.call if @on_close
      end

      def stop!
        stop
        EM.stop_event_loop
      end

      def done?
        @ws.instance_variable_get(:@driver).instance_variable_get(:@queue).empty?
      end

      def ready_state
        @ws.ready_state
      end

      private
      def setup
        @ws = Faye::WebSocket::Client.new(@url, nil, {
          ping: 10, # TODO: this is arbitrary
          headers: @kubeclient_options[:headers],
          tls: {
            cert_chain_file: @kubeclient_options[:tls][:cert_chain_file],
            cert: @kubeclient_options[:tls][:cert],
            private_key_file: @kubeclient_options[:tls][:private_key_file],
            private_key: @kubeclient_options[:tls][:private_key],
            verify_peer: @kubeclient_options[:tls][:verify_peer],
          },
          max_length: 2**32,
        })

        @ws.on(:message) do |msg|
          if msg.type == :close
            stop!
            return
          end

          next if msg.data.empty?

          type = msg.data.shift
          content = msg.data.pack("C*").force_encoding('utf-8')

          if content.empty?
            if @options[:mode] == :adhoc
              @last_stdout = 1 if type == EXEC_STDOUT
              @last_stderr = 1 if type == EXEC_STDERR || EXEC_DCKERR
              stop!
            end
          end

          case type
          when EXEC_STDOUT
            @last_stdout = content
            @on_stdout.call(content) if @on_stdout
          when EXEC_STDERR, EXEC_DCKERR
            @last_stderr = content
            @on_stderr.call(content) if @on_stderr
          else
            raise "Unsupported or Unknown channel"
          end
        end

        @ws.on(:error) do |event|
          raise "Error: #{event.inspect}" unless @suppress_errors
        end

        @ws.on(:close) do
          stop!
        end

        @ws.on(:open) do
          @on_open.call(self) if @on_open
        end
      end
    end
  end
end