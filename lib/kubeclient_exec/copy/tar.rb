# frozen_string_literal: true

require 'rubygems'
require 'rubygems/package'

# Greatly inspired by Github.com/sinisterchipmunk
# Source: https://gist.github.com/sinisterchipmunk/1335041/5be4e6039d899c9b8cca41869dc6861c8eb71f13
#
# Copyright (C) 2011 by Colin MacKenzie IV
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
module KubeclientExec
  module Copy
    module Tar
      def tar(src, dst, copy_file)
        tar_file = StringIO.new

        Gem::Package::TarWriter.new(tar_file) do |tar|
          if copy_file
            relative_file = dst.split('/').last

            tar.add_file relative_file, File.stat(src).mode do |tf|
              File.open(src, "rb") { |f| tf.write f.read }
            end
          else
            Dir[File.join(src, "**/*")].each do |file|
              mode = File.stat(file).mode
              relative_file = file.sub /^#{Regexp::escape src}\/?/, ''

              if File.directory?(file)
                tar.mkdir relative_file, mode
              else
                tar.add_file relative_file, mode do |tf|
                  File.open(file, "rb") { |f| tf.write f.read }
                end
              end
            end
          end
        end

        tar_file.rewind
        tar_file
      end

      def untar(io, destination)
        Gem::Package::TarReader.new(io) do |tar|
          tar.each do |tarfile|
            destination_file = File.join(destination, tarfile.full_name)

            if tarfile.directory?
              FileUtils.mkdir_p(destination_file)
            else
              destination_directory = File.dirname(destination_file)

              FileUtils.mkdir_p destination_directory unless File.directory?(destination_directory)

              File.open(destination_file, "wb") do |f|
                f.write(tarfile.read)
              end
            end
          end
        end
      end

      def single_untar(io)
        Gem::Package::TarReader.new(io) do |tar|
          tar.each do |tarfile|
            return tarfile.read
          end
        end
      end
    end
  end
end