#
# Authors:: Chris McClimans (<c@vulk.co>)
# Authors:: Taylor Carpenter (<t@vulk.co>)
# Authors:: Chef Partner Engineering (<partnereng@chef.io>)
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'fog'
require 'kitchen'
require 'securerandom'

module Kitchen
  module Driver
    class Vcair < Kitchen::Driver::Base
      attr_accessor :vapp_id

      default_config :wait_for, 600
      default_config :vcair_api_path, '/api'
      default_config :catalog_id, nil
      default_config :catalog_name, nil
      default_config :image_id, nil
      default_config :image_name, nil
      default_config :vdc_id, nil
      default_config :vdc_name, nil
      default_config :network_id, nil
      default_config :network_name, nil
      default_config :cpus, 1
      default_config :memory, 1024
      default_config :vm_password

      required_config :vcair_username
      required_config :vcair_password
      required_config :vcair_api_host
      required_config :vcair_org

      def initialize(config)
        super
        Fog.timeout = config[:wait_for].to_i
      end

      def name
        'vCloudAir'
      end

      def create(state)
        return unless state[:vapp_id].nil?

        validate!

        create_server(state)
        vm.wait_for { ready? }
        state[:hostname] = vm.ip_address

        info("Server #{state[:hostname]} is powered on. Waiting for it to be ready...")
        wait_for_server(state)
      end

      def destroy(state)
        return if state[:vapp_id].nil?

        validate!

        self.vapp_id = state[:vapp_id]

        info("Destroying vApp #{vapp_id}...")
        begin
          vapp
        rescue Fog::Compute::VcloudDirector::Forbidden
          warn("Unable to locate vApp <#{state[:vapp_id]}> - assuming it is already destroyed.")
          return
        end

        info('Powering off the vApp...')
        vapp.power_off

        info('Undeploying the vApp...')
        vapp.undeploy

        info('Deleting the vApp...')
        vapp.destroy

        info("vApp <#{state[:vapp_id]}> destroyed.")
      end

      def vcloud_client
        @vcloud_client ||= Fog::Compute.new(fog_server_def)
      rescue Excon::Errors::Unauthorized => e
        raise "Connection failure, please check your username and password. -- #{e.message}"
      end

      def org
        @org ||= vcloud_client.organizations.get_by_name(config[:vcair_org])
      end

      def create_server(state)
        self.vapp_id = instantiate
        state[:vapp_id] = vapp_id

        info("vApp ID #{vapp_id} created.")

        info('Validating the vApp...')
        unless validate_vapp
          destroy(state)
          return
        end

        info('Updating the VM customization...')
        update_customization

        info('Adjusting VM hardware...')
        adjust_hardware

        info('Attaching it to the network...')
        attach_network

        info('Tagging the VM...')
        tag_vm

        info('Powering on the VM...')
        power_on
      end

      def adjust_hardware
        vm.cpu    = config[:cpus] if config[:cpus]
        vm.memory = config[:memory] if config[:memory]
      end

      def attach_network_payload
        {
          PrimaryNetworkConnectionIndex: 0,
          NetworkConnection: [
            {
              network: network.name,
              needsCustomization: true,
              NetworkConnectionIndex: 0,
              IsConnected: true,
              IpAddressAllocationMode: 'POOL'
            }
          ]
        }
      end

      def attach_network
        task = vcloud_client.put_network_connection_system_section_vapp(vm.id, attach_network_payload)
        vcloud_client.process_task(task.body)
      end

      def tag_vm
        vm.tags.create('created-by', 'test-kitchen')
      end

      def power_on
        vapp.power_on
      end

      def wait_for_server(state)
        instance.transport.connection(state).wait_until_ready
      rescue StandardError
        error("Server #{vapp.id} (#{vm.name}) not reachable. Destroying server...")
        destroy(state)
        raise
      end

      def vcloud_username
        [config[:vcair_username], config[:vcair_org]].join('@')
      end

      def fog_server_def
        {
          provider: 'vclouddirector',
          vcloud_director_username: vcloud_username,
          vcloud_director_password: config[:vcair_password],
          vcloud_director_host: config[:vcair_api_host],
          vcloud_director_api_version: config[:vcair_api_version],
          vcloud_director_show_progress: false,
          path: config[:vcair_api_path]
        }
      end

      def image
        image = if config[:image_id]
                  catalog.catalog_items.get(config[:image_id])
                else
                  catalog.catalog_items.get_by_name(config[:image_name])
                end

        raise 'Unable to find image - check your image_id or image_name' if image.nil?

        image
      end

      def catalog
        catalog = if config[:catalog_id]
                    org.catalogs.get(config[:catalog_id])
                  else
                    org.catalogs.get_by_name(config[:catalog_name])
                  end

        raise 'Unable to find catalog - check your catalog_id or catalog_name' if catalog.nil?

        catalog
      end

      def vdc
        vdc = if config[:vdc_id]
                org.vdcs.get(config[:vdc_id])
              else
                org.vdcs.get_by_name(config[:vdc_name])
              end

        raise 'Unable to find VDC - check your vdc_id or vdc_name' if vdc.nil?

        vdc
      end

      def network
        network = if config[:network_id]
                    org.networks.get(config[:network_id])
                  else
                    org.networks.get_by_name(config[:network_name])
                  end

        raise 'Unable to find network - check your network_id or network_name' if network.nil?

        network
      end

      def node_description
        config[:node_description] || "Test Kitchen: #{node_name}"
      end

      def node_name
        config[:node_name] || generate_node_name
      end

      def generate_node_name
        # SecureRandom.hex generates a string 2x the argument.
        # We need the name to be 15 chars or less to play nicely
        # with windows, so we're generating a 12-char random
        # string prefixed with "tk-"
        'tk-' + SecureRandom.hex(6)
      end

      def instantiate_config
        {
          vdc_id: vdc.id,
          network_id: network.id,
          description: node_description
        }
      end

      def print_error_and_exit(message)
        error(message)
        fail message
      end

      def validate!
        %w[vdc catalog image network].each do |param|
          validate_parameter_pair!(param)
        end

        %i[org vdc catalog image network].each do |method|
          validate_method!(method)
        end

        validate_customization_script!
        validate_computer_name!
      end

      def validate_parameter_pair!(param)
        id_key   = param + '_id'
        name_key = param + '_name'

        print_error_and_exit("No #{param} found. You must specify #{id_key} or #{name_key}.") if
          config[id_key.to_sym].nil? && config[name_key.to_sym].nil?
      end

      def validate_method!(method)
        send(method)
      rescue StandardError => e
        raise "Unable to validate #{method} - check your configuration and try again. #{e.class} -- #{e.message}"
      end

      def validate_computer_name!
        # regex proudly modified after stealing from:
        # http://stackoverflow.com/questions/2063213/regular-expression-for-validating-dns-label-host-name
        print_error_and_exit('Node name is not valid - must be 15 characters or less, and be a valid Windows node name') unless
          node_name =~ /^(?![0-9]+$)(?!-)[a-zA-Z0-9-]{,15}(?<!-)$/
      end

      def validate_customization_script!
        return unless config[:customization_script]

        print_error_and_exit("Customization script #{config[:customization_script]} is not found or not readable.") unless
          ::File.readable?(config[:customization_script])
      end

      def instantiate
        image.instantiate(node_name, instantiate_config)
      end

      def vapp
        @vapp ||= vdc.vapps.get(vapp_id)
      end

      def vm
        @vm ||= vapp.vms.first
      end

      def validate_vapp
        vms = vapp.vms
        if vms.empty?
          error('vApp created, but did not contain any VMs')
          return false
        end

        if vms.size > 1
          error('vApp created, but contained more than one VM')
          return false
        end

        true
      end

      def customization
        @customization ||= vm.customization
      end

      def update_customization
        set_customization_script if config[:customization_script]
        set_customization_password
        set_customization_computer_name
        save_customization
      end

      def set_customization_script
        customization.script = ::File.read(config[:customization_script])
      end

      def set_customization_password
        customization.reset_password_required = false

        if config[:vm_password]
          customization.admin_password          = config[:vm_password]
          customization.admin_password_auto     = false
        else
          customization.admin_password          = nil
          customization.admin_password_auto     = true
        end
      end

      def set_customization_computer_name
        customization.computer_name = node_name
      end

      def save_customization
        customization.enabled = true
        customization.save
      end
    end
  end
end
