# frozen_string_literal: true

require 'kubeclient'
require 'faye/websocket'
require_relative 'kubeclient_exec/execute/execute'
require_relative 'kubeclient_exec/copy/copy'

module KubeclientExec
  include KubeclientExec::Execute
  include KubeclientExec::Copy
end

Kubeclient::Client.include(KubeclientExec)