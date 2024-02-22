# frozen_string_literal: true

require_relative 'tar'

module KubeclientExec
  module Copy
    include Tar

    DEFAULT_CP_OPTIONS = {
      container: nil,
      reverse_direction: false,
      suppress_errors: false,
      tls: {
        cert_chain_file: nil,
        private_key_file: nil,
        verify_peer: true
      }
    }

    def cp_pod(local_path, remote_path, name, namespace, options: {})
      # Reverse merge with the default options
      options.merge!(Copy::DEFAULT_CP_OPTIONS) { |_, option, _| option }

      if options[:reverse_direction]
        cp_from_pod(local_path, remote_path, name, namespace, options)
      else
        cp_to_pod(local_path, remote_path, name, namespace, options)
      end
    end

    private
    def cp_to_pod(local_path, remote_path, name, namespace, options)
      copy_file = false

      if File.file?(local_path)
        copy_file = true
      elsif !File.directory?(local_path)
        raise 'Did not find local path!'
      end

      tar_file = tar(local_path, remote_path, copy_file)

      if copy_file
        exec_pod("tar xf - -C #{remote_path.split('/')[0...-1].join('/')}", name, namespace, options: { tty: false }.merge!(options)) do |executor|
          executor.write(tar_file.string)

          # Feels like there should be a better way for this
          EM.add_periodic_timer(0.1) do
            if executor.done?
              executor.stop
            end
          end
        end
      else
        exec_pod("tar xf - -C #{remote_path}", name, namespace, options: { tty: false }.merge!(options)) do |executor|
          executor.write(tar_file.string)

          # Feels like there should be a better way for this
          EM.add_periodic_timer(0.1) do
            if executor.done?
              executor.stop
            end
          end
        end
      end
    end

    def cp_from_pod(local_path, remote_path, name, namespace, options)
      result = nil

      exec_pod("tar cf - #{remote_path}", name, namespace, options: { tty: false }.merge!(options)) do |executor|
        count = 0

        executor.on_stdout do |data|
          if count == 1
            if local_path.is_a? String
              untar(StringIO.new(data), local_path)
            elsif local_path == :single_result
              result = single_untar(StringIO.new(data))
            end
            executor.stop
          end

          count += 1
        end
      end

      result
    end
  end
end