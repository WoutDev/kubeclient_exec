# frozen_string_literal: true

require 'eventmachine'

module KubeclientExec
  module Execute
    class Executor
      EXEC_STDIN = 0
      EXEC_STDOUT = 1
      EXEC_STDERR = 2
      EXEC_DCKERR = 3 # Not sure about this one
      NOOP_PROC = -> {}

      attr_reader :last_stdout, :last_stderr, :last_command, :suppress_errors

      def initialize(command, url, ssl_options, options, &block)
        @last_command = command
        @url = url
        @ssl_options = ssl_options
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
        @ws.close if @ws
        @on_close.call if @on_close
        EM.stop_event_loop
      end

      def done?
        @ws.instance_variable_get(:@driver).instance_variable_get(:@queue).empty?
      end

      private
      def setup
        @ws = Faye::WebSocket::Client.new(@url, nil, {
          ping: 10,
          tls: {
            cert: @ssl_options[:client_cert].to_pem,
            cert_chain_file: "/home/wout/.kube/docker-desktop.crt",
            private_key: @ssl_options[:client_key].private_to_pem,
            private_key_file: "/home/wout/.kube/docker-desktop.key",
            verify_peer: false,
          }
        })

        @ws.on(:message) do |msg|
          if msg.type == :close
            stop
            return
          end

          next if msg.data.empty?

          type = msg.data.shift
          content = msg.data.pack("C*").force_encoding('utf-8')

          if content.empty?
            if @options[:mode] == :adhoc
              @last_stdout = 1 if type == EXEC_STDOUT
              @last_stderr = 1 if type == EXEC_STDERR || EXEC_DCKERR
              stop
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
          stop
        end

        @ws.on(:open) do
          @on_open.call(self) if @on_open
        end
      end
    end
  end
end