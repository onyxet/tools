require 'yaml'
require 'yaml/store'
# require 'fileutils'
def RemoveLocalFile
  if File.exist?('./nodes.yml')
    puts "Remove nodes.yml"
    system "DEL nodes.yml"
    system "rm nodes.yml"
  end
  if File.exist?('./memory.rules')
    puts "Remove memory.rules"
    system "DEL memory.rules"
    system "rm memory.rules"
  end
  if File.exist?('./cpu.rules')
    puts "Remove cpu.rules"
    system "DEL cpu.rules"
    system "rm cpu.rules"
  end
if File.exist?('./disk_root.rules')
    puts "Remove disk_root.rules"
    system "DEL disk_root.rules"
    system "rm disk_root.rules"
  end
if File.exist?('./disk_opt.rules')
    puts "Remove disk_opt.rules"
    system "DEL disk_opt.rules"
    system "rm disk_opt.rules"
  end
end
RemoveLocalFile()
def_memory = 314572800
def_cpu = 90
def_disk_root = 90
def_disk_opt = 90
p "Creating nodes.yml config"
nodes = Array.new
IO.popen("aws ec2 describe-instances --query \"Reservations[*].Instances[*].PrivateIpAddress\" --output=text").each do |line|
  nodes << line.chomp
end
nodes.map! {|item| "'" + item + ":9100" + "'"}
HASH_OF_HASHES = {
  '- targets' => "#{nodes}".gsub!('"', '')
}
File.open('./nodes.yml', 'w') {|f| f.write HASH_OF_HASHES.to_yaml.gsub!('"', '') }
if File.exist?('./nodes.yml')
  puts "Created"
else
  puts "something went wrong"
end
# puts nodes
puts "Enter memory limit in bytes\n Example is 314572800 (300MB)"
mem_limit = gets.chomp
nodes.each do |node|
  open('memory.rules', 'a') { |f|
  f << "ALERT FreeMemory\n"
  f << "\tIF node_memory_MemFree{instance=#{node},job=\"prometheus\"} < #{mem_limit} \n"
  f << "\tFOR 1s\n"
  f << "\tANNOTATIONS {\n"
  f << "\t\tsummary = \"PROBLEM ON {{ $labels.instance }}\",\n"
  f << "\t\tdescription = \"{{ $labels.queue }} has a (current value:{{ $value }}) bytes memory\",\n"
  f << "}\n"
}
end
puts "OK\n Enter CPU usage limit in percents\n Example is 90"
cpu_limit = gets.chomp
nodes.each do |node|
  open('cpu.rules', 'a') { |c|
  c << "ALERT CPU_USAGE\n"
  c << "\tIF sum by (instance) (irate(node_cpu{instance=#{node},job=\"instances\"}[1m])) > #{cpu_limit} \n"
  c << "\tFOR 10s\n"
  c << "\tANNOTATIONS {\n"
  c << "\t\tsummary = \"PROBLEM ON {{ $labels.instance }}\",\n"
  c << "\t\tdescription = \"{{ $labels.queue }} has a (current value:{{ $value }})% CPU usage\",\n"
  c << "}\n"
}
end
puts "OK\n Enter disk usage limit in percents on root fs\n Example is 90"
disk_limit_root = gets.chomp
nodes.each do |node|
  open('disk_root.rules', 'a') { |c|
  c << "ALERT disk_usage_on_/_mountpoint\n"
  c << "\tIF 100.0 - 100 * (node_filesystem_free{instance=~#{node},device !~\'tmpfs\',device!~\'by-uuid\',mountpoint=\"/\"} / node_filesystem_size{instance=~#{node},device !~\'tmpfs\',device!~\'by-uuid\',mountpoint=\"/\"}) > #{disk_limit_root} \n"
  c << "\tFOR 50s\n"
  c << "\tANNOTATIONS {\n"
  c << "\t\tsummary = \"PROBLEM ON {{ $labels.instance }}\",\n"
  c << "\t\tdescription = \"{{ $labels.queue }} has a (current value:{{ $value }})% disk usage\",\n"
  c << "}\n"
}
end
puts "OK\n Enter disk usage limit in percents on /opt mountpoint\n Example is 90"
disk_limit_root = gets.chomp
nodes.each do |node|
  open('disk_opt.rules', 'a') { |c|
  c << "ALERT disk_usage_on_/opt_mountpoint\n"
  c << "\tIF 100.0 - 100 * (node_filesystem_free{instance=~#{node},device !~\'tmpfs\',device!~\'by-uuid\',mountpoint=\"/opt\"} / node_filesystem_size{instance=~#{node},device !~\'tmpfs\',device!~\'by-uuid\',mountpoint=\"/opt\"}) > #{disk_limit_root} \n"
  c << "\tFOR 50s\n"
  c << "\tANNOTATIONS {\n"
  c << "\t\tsummary = \"PROBLEM ON {{ $labels.instance }}\",\n"
  c << "\t\tdescription = \"{{ $labels.queue }} has a (current value:{{ $value }})% disk usage\",\n"
  c << "}\n"
}
end

