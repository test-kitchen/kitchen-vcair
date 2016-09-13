# Encoding: UTF-8
#
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

require 'spec_helper'
require 'excon'
require 'kitchen/driver/vcair'
require 'kitchen/provisioner/dummy'
require 'kitchen/transport/dummy'
require 'kitchen/verifier/dummy'

describe Kitchen::Driver::Vcair do
  let(:logged_output) { StringIO.new }
  let(:logger)        { Logger.new(logged_output) }
  let(:platform)      { Kitchen::Platform.new(name: 'fake_platform') }
  let(:transport)     { Kitchen::Transport::Dummy.new }
  let(:driver)        { Kitchen::Driver::Vcair.new(config) }

  let(:config) do
    {
      vcair_username: 'myuser',
      vcair_password: 'mypassword',
      vcair_api_host: 'https://vcloud.air',
      vcair_api_path: '/api/compute/api',
      vcair_org:      'myorg',
      cpus:           2,
      memory:         2048,
      vdc_id:         1,
      catalog_id:     2,
      image_id:       3,
      network_id:     4
    }
  end

  let(:instance) do
    instance_double(Kitchen::Instance,
                    logger:    logger,
                    transport: transport,
                    platform:  platform,
                    to_str:    'instance_str'
    )
  end

  before do
    allow(driver).to receive(:instance).and_return(instance)
  end

  describe '#create' do
    context 'when the server is already created' do
      let(:state) { { vapp_id: 'vapp1' } }
      it 'does not call create_server' do
        expect(driver).not_to receive(:create_server)
      end
    end

    context 'when the server is not yet created' do
      let(:state) { {} }
      let(:vm)    { double('vm') }

      it 'calls the expected methods' do
        allow(driver).to receive(:vm).and_return(vm)
        allow(driver.vm).to receive(:ip_address).and_return('1.2.3.4')

        expect(driver).to receive(:validate!)
        expect(driver).to receive(:create_server).with(state)
        expect(driver.vm).to receive(:wait_for)
        expect(driver).to receive(:wait_for_server).with(state)

        driver.create(state)
      end
    end
  end

  describe '#destroy' do
    context 'when the server does not exist' do
      let(:state) { {} }
      it 'does not fetch the vapp' do
        expect(driver).not_to receive(:vapp)

        driver.destroy(state)
      end
    end

    context 'when the server exists' do
      let(:state) { { vapp_id: 'vapp1' } }
      let(:vapp)  { double('vapp') }
      before do
        allow(driver).to receive(:validate!)
        allow(driver).to receive(:vapp).and_return(vapp)
        allow(vapp).to receive(:power_off)
        allow(vapp).to receive(:undeploy)
        allow(vapp).to receive(:destroy)
      end

      it 'calls validate!' do
        expect(driver).to receive(:validate!)
        driver.destroy(state)
      end

      it 'sets the vapp_id' do
        expect(driver).to receive(:vapp_id=).with('vapp1')
        driver.destroy(state)
      end

      context 'when the vapp does not exist' do
        it 'does not call vapp again to power_off, etc.' do
          expect(driver).to receive(:vapp).once.and_raise(Fog::Compute::VcloudDirector::Forbidden)
          driver.destroy(state)
        end
      end

      it 'fetches the vapp' do
        expect(driver).to receive(:vapp)
        driver.destroy(state)
      end

      it 'gets rid of the vapp' do
        expect(driver.vapp).to receive(:power_off)
        expect(driver.vapp).to receive(:undeploy)
        expect(driver.vapp).to receive(:destroy)

        driver.destroy(state)
      end
    end
  end

  describe '#vcloud_client' do
    let(:fog_server_def) { double('fog_server_def') }
    let(:client)         { double('client') }

    before do
      allow(driver).to receive(:fog_server_def).and_return(fog_server_def)
    end

    it 'sets up a new Fog::Compute instance' do
      expect(Fog::Compute).to receive(:new).with(fog_server_def).and_return(client)
      expect(driver.vcloud_client).to eq(client)
    end

    it 'raises an error if unauthorized' do
      allow(Fog::Compute).to receive(:new).and_raise(Excon::Errors::Unauthorized, 'auth failed')
      expect { driver.vcloud_client }.to raise_error(
        RuntimeError,
        'Connection failure, please check your username and password. -- auth failed'
      )
    end
  end

  describe '#org' do
    let(:client)        { double('client') }
    let(:organizations) { double('organizations') }
    let(:org)           { double('org') }

    it 'fetches the organization by name' do
      allow(driver).to receive(:vcloud_client).and_return(client)
      allow(client).to receive(:organizations).and_return(organizations)
      expect(organizations).to receive(:get_by_name).with('myorg').and_return(org)
      expect(driver.org).to eq(org)
    end
  end

  describe '#create_server' do
    let(:state) { {} }

    it 'calls the expected methods' do
      expect(driver).to receive(:instantiate).and_return('vapp1')
      expect(driver).to receive(:vapp_id=).with('vapp1')
      expect(driver).to receive(:validate_vapp).and_return(true)
      expect(driver).to receive(:update_customization)
      expect(driver).to receive(:adjust_hardware)
      expect(driver).to receive(:attach_network)
      expect(driver).to receive(:tag_vm)
      expect(driver).to receive(:power_on)

      driver.create_server(state)
    end

    context 'when the vapp validation fails' do
      before do
        allow(driver).to receive(:instantiate)
        allow(driver).to receive(:validate_vapp).and_return(false)
      end

      it 'destroys the server' do
        expect(driver).to receive(:destroy).with(state)
        driver.create_server(state)
      end

      it 'does not power on the vapp' do
        expect(driver).not_to receive(:power_on)
        driver.create_server(state)
      end
    end
  end

  describe '#adjust_hardware' do
    let(:vm) { double('vm') }
    before do
      allow(driver).to receive(:vm).and_return(vm)
    end

    context 'when config parameters are supplied' do
      it 'sets the cpus and memory on the VM' do
        expect(vm).to receive(:cpu=).with(2)
        expect(vm).to receive(:memory=).with(2048)

        driver.adjust_hardware
      end
    end

    context 'when config parameters are not supplied' do
      before do
        config[:cpus] = nil
        config[:memory] = nil
      end

      it 'does not set the cpus and memory on the VM' do
        expect(vm).not_to receive(:cpu=)
        expect(vm).not_to receive(:memory=)

        driver.adjust_hardware
      end
    end
  end

  describe '#attach_network' do
    let(:client)  { double('client') }
    let(:payload) { {} }
    let(:task)    { double('task', body: 'body text') }
    let(:vm)      { double('vm', id: 'vm1') }

    it 'submits the request and processes it' do
      allow(driver).to receive(:vcloud_client).and_return(client)
      allow(driver).to receive(:attach_network_payload).and_return(payload)
      allow(driver).to receive(:vm).and_return(vm)

      expect(client).to receive(:put_network_connection_system_section_vapp)
        .with('vm1', payload).and_return(task)
      expect(client).to receive(:process_task).with('body text')

      driver.attach_network
    end
  end

  describe '#tag_vm' do
    let(:vm)   { double('vm') }
    let(:tags) { double('tags') }

    it 'tags the VM' do
      allow(driver).to receive(:vm).and_return(vm)
      allow(vm).to receive(:tags).and_return(tags)
      expect(tags).to receive(:create).with('created-by', 'test-kitchen')

      driver.tag_vm
    end
  end

  describe '#power_on' do
    let(:vapp) { double('vapp') }

    it 'powers on the vApp' do
      allow(driver).to receive(:vapp).and_return(vapp)
      expect(vapp).to receive(:power_on)

      driver.power_on
    end
  end

  describe '#wait_for_server' do
    let(:connection) { instance.transport.connection(state) }
    let(:state)      { {} }
    let(:vapp)       { double('vapp', id: 'vapp1') }
    let(:vm)         { double('vm', name: 'vm1') }

    before do
      allow(transport).to receive(:connection).and_return(connection)
      allow(driver).to receive(:vapp).and_return(vapp)
      allow(driver).to receive(:vm).and_return(vm)
    end

    it 'calls wait_until_ready on the transport connection' do
      expect(connection).to receive(:wait_until_ready)
      driver.wait_for_server(state)
    end

    it 'destroys the vApp if the server failed to become ready' do
      allow(connection).to receive(:wait_until_ready).and_raise(RuntimeError)
      expect(driver).to receive(:destroy).with(state)
      expect { driver.wait_for_server(state) }.to raise_error(RuntimeError)
    end
  end

  describe '#vcloud_username' do
    it 'returns a properly-formatted username' do
      expect(driver.vcloud_username).to eq('myuser@myorg')
    end
  end

  describe '#image' do
    let(:catalog)       { double('catalog') }
    let(:catalog_items) { double('catalog_items') }
    let(:image)         { double('image') }

    before do
      allow(driver).to receive(:catalog).and_return(catalog)
      allow(catalog).to receive(:catalog_items).and_return(catalog_items)
    end

    context 'when an ID is provided' do
      before do
        config[:image_id] = 1
        config[:image_name] = nil
      end

      it 'fetches the catalog item by ID' do
        expect(catalog_items).to receive(:get).with(1).and_return(image)
        expect(driver.image).to eq(image)
      end
    end

    context 'when a name is provided' do
      before do
        config[:image_id] = nil
        config[:image_name] = 'image name'
      end

      it 'fetches the catalog item by name' do
        expect(catalog_items).to receive(:get_by_name).with('image name').and_return(image)
        expect(driver.image).to eq(image)
      end
    end

    context 'when no image is returned' do
      before do
        config[:image_id] = 1
        config[:image_name] = nil
      end

      it 'raises an exception' do
        expect(catalog_items).to receive(:get).with(1).and_return(nil)
        expect { driver.image }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#catalog' do
    let(:org)      { double('org') }
    let(:catalogs) { double('catalogs') }
    let(:catalog)  { double('catalog') }

    before do
      allow(driver).to receive(:org).and_return(org)
      allow(org).to receive(:catalogs).and_return(catalogs)
    end

    context 'when an ID is provided' do
      before do
        config[:catalog_id] = 1
        config[:catalog_name] = nil
      end

      it 'fetches the catalog by ID' do
        expect(catalogs).to receive(:get).with(1).and_return(catalog)
        expect(driver.catalog).to eq(catalog)
      end
    end

    context 'when a name is provided' do
      before do
        config[:catalog_id] = nil
        config[:catalog_name] = 'catalog name'
      end

      it 'fetches the catalog by name' do
        expect(catalogs).to receive(:get_by_name).with('catalog name').and_return(catalog)
        expect(driver.catalog).to eq(catalog)
      end
    end

    context 'when no catalog is returned' do
      before do
        config[:catalog_id] = 1
        config[:catalog_name] = nil
      end

      it 'raises an exception' do
        expect(catalogs).to receive(:get).with(1).and_return(nil)
        expect { driver.catalog }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#vdc' do
    let(:org)  { double('org') }
    let(:vdcs) { double('vdcs') }
    let(:vdc)  { double('vdc') }

    before do
      allow(driver).to receive(:org).and_return(org)
      allow(org).to receive(:vdcs).and_return(vdcs)
    end

    context 'when an ID is provided' do
      before do
        config[:vdc_id] = 1
        config[:vdc_name] = nil
      end

      it 'fetches the vdc by ID' do
        expect(vdcs).to receive(:get).with(1).and_return(vdc)
        expect(driver.vdc).to eq(vdc)
      end
    end

    context 'when a name is provided' do
      before do
        config[:vdc_id] = nil
        config[:vdc_name] = 'vdc name'
      end

      it 'fetches the vdc by name' do
        expect(vdcs).to receive(:get_by_name).with('vdc name').and_return(vdc)
        expect(driver.vdc).to eq(vdc)
      end
    end

    context 'when no vdc is returned' do
      before do
        config[:vdc_id] = 1
        config[:vdc_name] = nil
      end

      it 'raises an exception' do
        expect(vdcs).to receive(:get).with(1).and_return(nil)
        expect { driver.vdc }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#network' do
    let(:org)      { double('org') }
    let(:networks) { double('networks') }
    let(:network)  { double('network') }

    before do
      allow(driver).to receive(:org).and_return(org)
      allow(org).to receive(:networks).and_return(networks)
    end

    context 'when an ID is provided' do
      before do
        config[:network_id] = 1
        config[:network_name] = nil
      end

      it 'fetches the network by ID' do
        expect(networks).to receive(:get).with(1).and_return(network)
        expect(driver.network).to eq(network)
      end
    end

    context 'when a name is provided' do
      before do
        config[:network_id] = nil
        config[:network_name] = 'network name'
      end

      it 'fetches the network by name' do
        expect(networks).to receive(:get_by_name).with('network name').and_return(network)
        expect(driver.network).to eq(network)
      end
    end

    context 'when no network is returned' do
      before do
        config[:network_id] = 1
        config[:network_name] = nil
      end

      it 'raises an exception' do
        expect(networks).to receive(:get).with(1).and_return(nil)
        expect { driver.network }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#node_description' do
    context 'when a node description is provided' do
      before do
        config[:node_description] = 'sample description'
      end

      it 'returns the configured description' do
        expect(driver.node_description).to eq('sample description')
      end
    end

    context 'when a node description is not provided' do
      it 'returns the default description' do
        allow(driver).to receive(:node_name).and_return('node')
        expect(driver.node_description).to eq('Test Kitchen: node')
      end
    end
  end

  describe '#node_name' do
    context 'when a node name is provided' do
      before do
        config[:node_name] = 'testnode'
      end

      it 'returns the configured node name' do
        expect(driver.node_name).to eq('testnode')
      end
    end

    context 'when a node name is not provided' do
      it 'returns a generated node name' do
        expect(driver).to receive(:generate_node_name).and_return('a12345')
        expect(driver.node_name).to eq('a12345')
      end
    end
  end

  describe '#generate_node_name' do
    it 'generates a node name using SecureRandom' do
      expect(SecureRandom).to receive(:hex).with(6).and_return('randomchars')
      expect(driver.generate_node_name).to eq('tk-randomchars')
    end
  end

  describe '#print_error_and_exit' do
    it 'prints an error message and raises an exception' do
      expect(driver).to receive(:error).with('error text')
      expect { driver.print_error_and_exit('error text') }.to raise_error(RuntimeError)
    end
  end

  describe '#validate!' do
    it 'calls all the expected validate methods' do
      expect(driver).to receive(:validate_parameter_pair!).with('vdc')
      expect(driver).to receive(:validate_parameter_pair!).with('catalog')
      expect(driver).to receive(:validate_parameter_pair!).with('image')
      expect(driver).to receive(:validate_parameter_pair!).with('network')

      expect(driver).to receive(:validate_method!).with(:org)
      expect(driver).to receive(:validate_method!).with(:vdc)
      expect(driver).to receive(:validate_method!).with(:catalog)
      expect(driver).to receive(:validate_method!).with(:image)
      expect(driver).to receive(:validate_method!).with(:network)

      expect(driver).to receive(:validate_customization_script!)
      expect(driver).to receive(:validate_computer_name!)

      driver.validate!
    end
  end

  describe '#validate_parameter_pair!' do
    context 'when an ID exists but not a name' do
      before do
        config[:test_id] = 1
        config[:test_name] = nil
      end

      it 'does not print an error' do
        expect(driver).not_to receive(:print_error_and_exit)
        driver.validate_parameter_pair!('test')
      end
    end

    context 'when a name exists but not an ID' do
      before do
        config[:test_id] = nil
        config[:test_name] = 'test'
      end

      it 'does not print an error' do
        expect(driver).not_to receive(:print_error_and_exit)
        driver.validate_parameter_pair!('test')
      end
    end

    context 'when neither a name nor an ID exists' do
      before do
        config[:test_id] = nil
        config[:test_name] = nil
      end

      it 'prints an error' do
        expect(driver).to receive(:print_error_and_exit)
        driver.validate_parameter_pair!('test')
      end
    end
  end

  describe '#validate_method!' do
    context 'when the method is successful' do
      it 'does not raise an exception' do
        allow(driver).to receive(:test_method)
        expect { driver.validate_method!(:test_method) }.not_to raise_error
      end
    end

    context 'when the method is not successful' do
      it 'raises an exception' do
        allow(driver).to receive(:test_method).and_raise(RuntimeError)
        expect { driver.validate_method!(:test_method) }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#validate_computer_name' do
    it 'allows an alphanumeric 15-char string' do
      allow(driver).to receive(:node_name).and_return('a12345678901234')
      expect(driver).not_to receive(:print_error_and_exit)

      driver.validate_computer_name!
    end

    it 'does not allow a computer name that only has numbers' do
      allow(driver).to receive(:node_name).and_return('12345')
      expect(driver).to receive(:print_error_and_exit)

      driver.validate_computer_name!
    end

    it 'does not allow a 16 character name' do
      allow(driver).to receive(:node_name).and_return('a123456789012345')
      expect(driver).to receive(:print_error_and_exit)

      driver.validate_computer_name!
    end

    it 'does not allow a hyphen at the end' do
      allow(driver).to receive(:node_name).and_return('a12345-')
      expect(driver).to receive(:print_error_and_exit)

      driver.validate_computer_name!
    end
  end

  describe '#validate_customization_script!' do
    context 'when no customization script has been configured' do
      before do
        config[:customization_script] = nil
      end

      it 'does not print an error' do
        expect(driver).not_to receive(:print_error_and_exit)

        driver.validate_customization_script!
      end
    end

    context 'when a script is configured and is readable' do
      before do
        config[:customization_script] = '/path/to/script'
      end

      it 'does not print an error' do
        expect(File).to receive(:readable?).with('/path/to/script').and_return(true)
        expect(driver).not_to receive(:print_error_and_exit)

        driver.validate_customization_script!
      end
    end

    context 'when a script is configured but is not readable' do
      before do
        config[:customization_script] = '/path/to/script'
      end

      it 'does not print an error' do
        expect(File).to receive(:readable?).with('/path/to/script').and_return(false)
        expect(driver).to receive(:print_error_and_exit)

        driver.validate_customization_script!
      end
    end
  end

  describe '#instantiate' do
    let(:image)              { double('image') }

    it 'calls instantiate on the image' do
      allow(driver).to receive(:image).and_return(image)
      allow(driver).to receive(:vmapp_name).and_return('node')
      allow(driver).to receive(:instantiate_config).and_return('config')
      expect(image).to receive(:instantiate).with('node', 'config')

      driver.instantiate
    end
  end

  describe '#vapp' do
    let(:vdc)   { double('vdc') }
    let(:vapps) { double('vapps') }
    let(:vapp)  { double('vapp') }

    it 'gets the vApp by ID' do
      allow(driver).to receive(:vapp_id).and_return('vapp1')
      allow(driver).to receive(:vdc).and_return(vdc)
      allow(vdc).to receive(:vapps).and_return(vapps)
      expect(vapps).to receive(:get).with('vapp1').and_return(vapp)
      expect(driver.vapp).to eq(vapp)
    end
  end

  describe '#vm' do
    let(:vapp) { double('vapp') }
    let(:vms)  { %w(vm1 vm2) }

    it 'returns the first VM from the array' do
      allow(driver).to receive(:vapp).and_return(vapp)
      allow(vapp).to receive(:vms).and_return(vms)

      expect(driver.vm).to eq('vm1')
    end
  end

  describe '#validate_vapp' do
    let(:vapp) { double('vapp') }
    before do
      allow(driver).to receive(:vapp).and_return(vapp)
    end

    it 'returns true when only 1 VM is present' do
      allow(vapp).to receive(:vms).and_return([1])
      expect(driver.validate_vapp).to eq(true)
    end

    it 'returns false when 0 VMs are present' do
      allow(vapp).to receive(:vms).and_return([])
      expect(driver.validate_vapp).to eq(false)
    end

    it 'returns false when >1 VMs are present' do
      allow(vapp).to receive(:vms).and_return([1, 2])
      expect(driver.validate_vapp).to eq(false)
    end
  end

  describe '#customization' do
    let(:vm)            { double('vm') }
    let(:customization) { double('customization') }
    it 'fetches the customization from the VM' do
      allow(driver).to receive(:vm).and_return(vm)
      expect(vm).to receive(:customization).and_return(customization)
      expect(driver.customization).to eq(customization)
    end
  end

  describe '#update_customization' do
    before do
      allow(driver).to receive(:set_customization_script)
      allow(driver).to receive(:set_customization_password)
      allow(driver).to receive(:set_customization_computer_name)
      allow(driver).to receive(:save_customization)
    end

    context 'when a customization script is provided' do
      before do
        config[:customization_script] = '/path/to/script'
      end

      it 'calls set_customization_script' do
        expect(driver).to receive(:set_customization_script)
        driver.update_customization
      end
    end

    context 'when a customization script is not provided' do
      before do
        config[:customization_script] = nil
      end

      it 'does not call set_customization_script' do
        expect(driver).not_to receive(:set_customization_script)
        driver.update_customization
      end
    end

    it 'calls the expected methods' do
      expect(driver).to receive(:set_customization_password)
      expect(driver).to receive(:set_customization_computer_name)
      expect(driver).to receive(:save_customization)
      driver.update_customization
    end
  end

  describe '#set_customization_script' do
    let(:customization) { double('customization') }

    before do
      config[:customization_script] = '/path/to/script'
      allow(driver).to receive(:customization).and_return(customization)
      allow(File).to receive(:read).with('/path/to/script').and_return('script body')
    end

    it 'sets the customization script to the file contents' do
      expect(customization).to receive(:script=).with('script body')
      driver.set_customization_script
    end
  end

  describe '#set_customization_password' do
    let(:customization) { double('customization') }
    before do
      allow(driver).to receive(:customization).and_return(customization)
    end

    context 'when a VM password is provided' do
      before do
        config[:vm_password] = 'password123'
      end

      it 'sets the password and disables auto-generation and reset' do
        expect(customization).to receive(:admin_password=).with('password123')
        expect(customization).to receive(:admin_password_auto=).with(false)
        expect(customization).to receive(:reset_password_required=).with(false)

        driver.set_customization_password
      end
    end

    context 'when a VM password is not provided' do
      before do
        config[:vm_password] = nil
      end

      it 'sets nulls-out the password, enables auto-generation, disables reset reset' do
        expect(customization).to receive(:admin_password=).with(nil)
        expect(customization).to receive(:admin_password_auto=).with(true)
        expect(customization).to receive(:reset_password_required=).with(false)

        driver.set_customization_password
      end
    end
  end

  describe '#set_customization_computer_name' do
    let(:customization) { double('customization') }
    it 'sets the computer name' do
      allow(driver).to receive(:customization).and_return(customization)
      allow(driver).to receive(:node_name).and_return('test node')
      expect(customization).to receive(:computer_name=).with('test node')

      driver.set_customization_computer_name
    end
  end

  describe '#save_customization' do
    let(:customization) { double('customization') }
    it 'enables and saves the customization' do
      allow(driver).to receive(:customization).and_return(customization)
      expect(customization).to receive(:enabled=).with(true)
      expect(customization).to receive(:save)

      driver.save_customization
    end
  end
end
