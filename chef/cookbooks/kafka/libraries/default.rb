module Kafka
  def is_kafka
    node.role?("kakfa_node")
  end

  def kafka_nodes_ip
    servers = all_providers_fqdn_for_role("kafka_node")
    Chef::Log.info("Apache Kafka nodes in cluster #{node[:cluster_name]} are: #{servers.inspect}")
    servers
  end
end

class Chef::Recipe; include Kafka; end
