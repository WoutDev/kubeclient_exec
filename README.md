# kubeclient_exec
A simple gem adding `exec_pod` and `cp_pod` functionality to [Kubeclient](https://github.com/ManageIQ/kubeclient). 

# Installation
Add this line to your Gemfile:
```ruby
gem 'kubeclient_exec'
```

And then install the gem:
```
bundle
```

When you require the gem, the methods `exec_pod` and `cp_pod` are automatically included in `Kubeclient::Client`.

# Usage

## exec_pod
Execute a command in a Kubernetes Pod container.

**Example: simple touch-and-go**
```ruby
client.exec_pod("touch hello-world", "my-pod", "my-namespace", options: { container: 'my-container' })
```

**Example: more advanced**
```ruby
client.exec_pod("/bin/sh", "my-pod", "my-namespace", options: { container: 'my-container' }) do |executor|
  executor.on_stdout do |message|
    puts "STDOUT >> #{message}"
  end

  executor.on_stderr do |message|
    puts "STDERR >> #{message}"
  end
  
  executor.execute('date')
  executor.execute('echo "hello, world!" > test')
  
  EM.add_periodic_timer(0.1) do
    if executor.done?
      executor.stop
    end
  end
end
```
All code in the block is executed in an [EventMachine](https://github.com/eventmachine/eventmachine) run block.

## cp_pod
Copy a file or directory to/from a Kubernetes Pod container.

**Example: copy single file *to* a container**
```ruby
client.cp_pod("local-file.txt", "/home/local-file-renamed.txt", "my-pod", "my-namespace", options: { container: 'my-container' })
```

**Example: copy directory *to* a container**
```ruby
client.cp_pod("./my-local-secrets", "/home", "my-pod", "my-namespace", options: { container: 'my-container' })
```

**Example: copy single file *from* a container**
```ruby
client.cp_pod(".", "/home/local-file-renamed.txt", "my-pod", "my-namespace", options: { container: 'my-container', reverse_direction: true })
```
Note: copying a single file from a container into a (renamed) single file on your local machine is not yet implemented.

**Example: copy single file *from* a container into variable**
```ruby
result = client.cp_pod(:single_result, "/home/local-file-renamed.txt", "my-pod", "my-namespace", options: { container: 'my-container', reverse_direction: true })
```

**Example: copy directory *from* a container**
```ruby
client.cp_pod('.', "/home/interesting-results", "my-pod", "my-namespace", options: { container: 'my-container', reverse_direction: true })
```

## Authentication
Both bearer tokens and user certificates should be supported. However, in case user certificates are used, you should pass the certificate and key *file locations* into `options[:tls][:cert_chain_file]` and `options[:tls][:private_key_file]` respectively. This is a limitation of EventMachine.

**Note:** Since ```v0.2.0``` you can pass certificate and key information directly **if** you are explicitly using at the ```e7320417cf291cc6a69471a64ecae5ddb5367715``` (or later) commit of the ```eventmachine``` GitHub repository. This is a feature that has been added to ```eventmachine```, but not yet released to Rubygems. You pass the PEM-encoded format certificate and key directly to `options[:tls][:cert]` and `options[:tls][:private_key]`.

# Troubleshooting
**Problem:** Can I suppress errors?

You can enable the `suppress_errors` option in the `options` hash.

**Problem:** I want to disable TLS peer verification.

You can using `options[:tls][:verify_peer] = false`

# Contributions
Contributions are very much welcome.