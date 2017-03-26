require 'yaml'
require 'yaml/store'

class GetConf
attr_accessor :memory, :cpu, :disk_root, :disk_opt, :HASH_OF_HASHES, :nodes
def RemoveLocalFiles
  puts "Remove local files"
  %w(nodes.yml memory.rules cpu.rules disk_root.rules disk_opt.rules).each do |folders|
    if File.exist?(folders)
      system "DEL #{folders}"
      system "rm #{folders}"
    end
  end
end
def CreateConfigNodes
  p "Creating nodes.yml config from aws EC2 resources"
  @nodes = Array.new
  IO.popen("aws ec2 describe-instances --query \"Reservations[*].Instances[*].PrivateIpAddress\" --output=text").each do |line|
    @nodes << line.chomp
  end
  @nodes.map! {|item| "'" + item + ":9100" + "'"}
  @HASH_OF_HASHES = {
    '- targets' => "#{nodes}".gsub!('"', '')
  }
  File.open('./nodes.yml', 'w') {|f| f.write @HASH_OF_HASHES.to_yaml.gsub!('"', '') }
  if File.exist?('./nodes.yml')
    puts "Created"
  else
    raise "something went wrong"
  end
end
  def initialize
    @memory = 314572800
    @cpu = 90
    @disk_root = 90
    @disk_opt = 90
  end
def CreateRules()
  mem_limit = @memory
  @nodes.each do |node|
    open('memory.rules', 'a') { |f|
      f << "ALERT FreeMemory\n"
      f << "\tIF node_memory_MemFree{instance=#{node}} < #{mem_limit} \n"
      f << "\tFOR 1s\n"
      f << "\tANNOTATIONS {\n"
      f << "\t\tsummary = \"PROBLEM ON {{ $labels.instance }}\",\n"
      f << "\t\tdescription = \"{{ $labels.queue }} has a (current value:{{ $value }}) bytes memory\",\n"
      f << "}\n"
    }
  end
  cpu_limit = @cpu
  @nodes.each do |node|
    open('cpu.rules', 'a') { |c|
      c << "ALERT CPU_USAGE\n"
      c << "\tIF 100 - (avg by (instance) (irate(node_cpu{instance=#{node},mode=\"idle\"}[5m])) * 100) > #{cpu_limit} \n" 
      c << "\tFOR 10s\n"
      c << "\tANNOTATIONS {\n"
      c << "\t\tsummary = \"PROBLEM ON {{ $labels.instance }}\",\n"
      c << "\t\tdescription = \"{{ $labels.queue }} has a (current value:{{ $value }})% CPU usage\",\n"
      c << "}\n"
    }
  end
  disk_limit_root = @disk_root
  @nodes.each do |node|
    open('disk_root.rules', 'a') { |c|
      c << "ALERT disk_usage_on_root_mountpoint\n"
      c << "\tIF 100.0 - 100 * (node_filesystem_free{instance=~#{node},device !~\'tmpfs\',device!~\'by-uuid\',mountpoint=\"/\"} / node_filesystem_size{instance=~#{node},device !~\'tmpfs\',device!~\'by-uuid\',mountpoint=\"/\"}) > #{disk_limit_root} \n"
      c << "\tFOR 50s\n"
      c << "\tANNOTATIONS {\n"
      c << "\t\tsummary = \"PROBLEM ON {{ $labels.instance }}\",\n"
      c << "\t\tdescription = \"{{ $labels.queue }} has a (current value:{{ $value }})% disk usage\",\n"
      c << "}\n"
  }
  end
  disk_limit_opt = @disk_opt
  @nodes.each do |node|
    open('disk_opt.rules', 'a') { |c|
      c << "ALERT disk_usage_on_opt_mountpoint\n"
      c << "\tIF 100.0 - 100 * (node_filesystem_free{instance=~#{node},device !~\'tmpfs\',device!~\'by-uuid\',mountpoint=\"/opt\"} / node_filesystem_size{instance=~#{node},device !~\'tmpfs\',device!~\'by-uuid\',mountpoint=\"/opt\"}) > #{disk_limit_opt} \n"
      c << "\tFOR 50s\n"
      c << "\tANNOTATIONS {\n"
      c << "\t\tsummary = \"PROBLEM ON {{ $labels.instance }}\",\n"
      c << "\t\tdescription = \"{{ $labels.queue }} has a (current value:{{ $value }})% disk usage\",\n"
      c << "}\n"
  }
    end
  end
end
Conf = GetConf.new
Conf.RemoveLocalFiles
Conf.CreateConfigNodes
Conf.CreateRules