#
# Cookbook Name:: kafka
# Recipe:: default
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include_recipe "java::sun"
include_recipe "hadoop_common::pre_run"
include_recipe "hadoop_common::mount_disks"
include_recipe "hadoop_cluster::update_attributes"

node.default[:kafka][:zookeeper_server_list] = zookeepers_ip

set_bootstrap_action(ACTION_INSTALL_PACKAGE, 'kafka', true)

remote_file "/tmp/kafka-0.8.2.0-src.tgz" do
  source "http://hadoop-mgmt.or1.omniture.com/yum/kafka/kafka-0.8.2.0-src.tgz"
  action :create
end

remote_file "/tmp/scala-2.11.5.rpm" do
  source "http://hadoop-mgmt.or1.omniture.com/yum/kafka/scala-2.11.5.rpm"
  action :create
end

remote_file "/etc/yum.repos.d/sbt.repo" do
  source "http://hadoop-mgmt.or1.omniture.com/yum/kafka/sbt.repo"
  action :create
end

package "scala" do
  source "/tmp/scala-2.11.5.rpm"
  action :install
  provider Chef::Provider::Package::Rpm
end

# Dependency packages
%w{gcc gcc-c++ libtool make unzip automake sbt}.each do |pkg|
  package pkg do
    action :install
  end
end

# Create User and Group
group "kafka"
user "kafka" do
  comment "Kafka User"
  gid "kafka"
  shell "/bin/bash"
  home "/home/kafka"
  supports :manage_home => true
end

# A package called Gradle is required for Kafka
remote_file "/tmp/gradle-2.3-all.zip" do
  source "https://services.gradle.org/distributions/gradle-2.3-all.zip"
  action :create
end

script "install_gradle" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
    unzip gradle-2.3-all.zip -d /opt/
    ln -s /opt/gradle-2.3 /opt/gradle
    printf "export GRADLE_HOME=/opt/gradle\nexport PATH=\$PATH:\$GRADLE_HOME/bin\nexport SCALA_VERSION=2.11.5\nexport SCALA_BINARY_VERSION=2.11\n" > /etc/profile.d/gradle.sh
    . /etc/profile.d/gradle.sh
  EOH
end

# Install the Kafka package from source
script "install_kafka" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
    tar zxf kafka-0.8.2.0-src.tgz
    mv /tmp/kafka-0.8.2.0-src /opt/kafka-0.8.2.0
    ln -s /opt/kafka-0.8.2.0 /opt/kafka
    cd /opt/kafka
    /opt/gradle/bin/gradle -PscalaVersion=2.11.5 -PscalaBinaryVersion=2.11
    ./gradlew -PscalaVersion=2.11.5 -PscalaBinaryVersion=2.11 jar
    chown -R kafka:kafka /opt/kafka-0.8.2.0
  EOH
end

# Setup the variables for the server.properties file
# Need a unique broker_id for each node
node.default[:kafka][:broker_id] = rand(1..65535)

template '/opt/kafka/config/server.properties' do
  source 'server.properties.erb'
  variables(
    zookeeper_server_list: node.default[:kafka][:zookeeper_server_list],
    broker: node.default[:kafka][:broker_id]
  )
  action :create
end

# Create init.d script for kafka
template "/etc/init.d/kafka" do
  source "kafka.initd.erb"
  owner "root"
  group "root"
  mode  00755
end

execute "Starting Kafka Service" do
  command "service kafka start"
end

clear_bootstrap_action
