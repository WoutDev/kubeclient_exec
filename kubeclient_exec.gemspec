Gem::Specification.new do |s|
  s.name          = 'kubeclient_exec'
  s.version       = '0.1.1'
  s.licenses      = ['MIT']
  s.summary       = 'An extension to the kubeclient gem that adds exec_pod and cp_pod functionality.'
  s.authors       = ['Wout Ceulemans']
  s.email         = 'me@wout.dev'
  s.files         = Dir['lib/**/*.rb']
  s.require_paths = 'lib'
  s.homepage      = 'https://github.com/WoutDev/kubeclient_exec'
  s.add_runtime_dependency 'kubeclient', '~> 4.11.0'
  s.add_runtime_dependency 'faye-websocket', '~> 0.11.3'
end