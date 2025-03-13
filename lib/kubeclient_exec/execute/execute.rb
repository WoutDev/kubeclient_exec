# frozen_string_literal: true

require_relative 'executor'

module KubeclientExec
  module Execute
    DEFAULT_EXEC_OPTIONS = {
      container: nil,
      stdin: true,
      stdout: true,
      stderror: true,
      tty: true,
      suppress_errors: false,
      tls: {
        cert_chain_file: nil,
        cert: nil,
        private_key_file: nil,
        private_key: nil,
        verify_peer: true
      }
    }

    def exec_pod(command, name, namespace, options: {}, &block)
      ns_prefix = build_namespace_prefix(namespace)
      client = rest_client["#{ns_prefix}pods/#{name}/exec"]
      url = URI.parse(client.url)

      # Reverse merge with the default options
      options.merge!(Execute::DEFAULT_EXEC_OPTIONS) { |_, option, _| option }

      kubeclient_options = { headers: @headers, tls: options[:tls] }

      url.query = (options.filter { |k| ![:suppress_errors, :tls].include?(k) }.compact.map { |k, v| "#{k}=#{v}"} << command.split(' ').map { |c| "command=#{c}"}).join('&')

      if url.to_s.start_with?('https')
        url = "wss" + url.to_s[5..-1]
      end

      last_output = { last_stdout: nil, last_stderr: nil }

      EM.run do
        executor = if block_given?
            Executor.new(command, url, kubeclient_options, options) do |executor|
              block.call(executor)
            end
        else
            Executor.new(command, url, kubeclient_options, options.merge!(mode: :adhoc))
        end

        EM.add_shutdown_hook do
          last_output[:last_stdout] = executor.last_stdout
          last_output[:last_stderr] = executor.last_stderr
        end
      end

      last_output
    end
  end
end