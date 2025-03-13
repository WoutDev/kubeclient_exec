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
        cert: nil,
        private_key_file: nil,
        private_key: nil,
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
          chunks = split_string_into_chunks(tar_file.string, 1024 * 1024) # 1MB
          chunks.each do |chunk|
            executor.write(chunk)
          end

          # Feels like there should be a better way for this
          stopping = false
          EM.add_periodic_timer(0.1) do
            if executor.done? && !stopping
              stopping = true
              executor.stop
            end

            if executor.ready_state == 3
              EM.stop_event_loop
            end
          end
        end
      else
        exec_pod("tar xf - -C #{remote_path}", name, namespace, options: { tty: false }.merge!(options)) do |executor|
          executor.write(tar_file.string)

          # Feels like there should be a better way for this
          stopping = false
          EM.add_periodic_timer(0.1) do
            if executor.done? && !stopping
              stopping = true
              executor.stop
            end

            if executor.ready_state == 3
              EM.stop_event_loop
            end
          end
        end
      end
    end

    def cp_from_pod(local_path, remote_path, name, namespace, options)
      result = nil

      exec_pod("tar cf - #{remote_path}", name, namespace, options: { tty: false }.merge!(options)) do |executor|
        count = 0
        content = ''

        executor.on_stdout do |data|
          if count >= 1
            content += data
          end

          count += 1
        end

        executor.on_close do
          if local_path.is_a? String
            untar(StringIO.new(content), local_path)
          elsif local_path == :single_result
            result = single_untar(StringIO.new(content))
          end
        end
      end

      result
    end

    private
    def split_string_into_chunks(string, chunk_size)
      chunks = []
      start_index = 0

      while start_index < string.length
        chunk = string[start_index, chunk_size]
        chunks << chunk
        start_index += chunk_size
      end

      chunks
    end
  end
end