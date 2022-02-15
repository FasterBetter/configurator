# frozen_string_literal: true

# Copyright 2021 Teak.io, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'config_o_mat/configurator/op/refresh_profile'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

require 'aws-sdk-appconfig'
require 'logsformyfamily'

RSpec.describe ConfigOMat::Op::RefreshProfile do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      profile_defs: profile_defs,
      client_id: client_id,
      applying_profile: applying_profile,
      appconfig_client: client_stub,
      logger: logger
    )
  end

  let(:profile_defs) do
    {
      source0: ConfigOMat::Profile.new(application: 'test', environment: 'test', profile: 'test')
    }
  end

  let(:applying_profile) do
    ConfigOMat::LoadedProfile.new(:source0, '1', '{"answer": 42', 'application/json')
  end

  let(:client_id) { SecureRandom.uuid }

  let(:stub_responses) do
    {
      'test' => { content: StringIO.new({ answer: 42 }.to_json), configuration_version: '2', content_type: 'application/json' },
    }
  end

  let(:client_stub) do
    Aws::AppConfig::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(:get_configuration, proc do |request|
        stub_responses[request.params[:application]]
      end
      )
    end
  end

  let(:logger) { nil }

  context 'when the profile is updated' do
    it 'updates applying_profile' do
      expect(state.applying_profile).to eq(
        ConfigOMat::LoadedProfile.new(:source0, '2', { answer: 42 }.to_json, 'application/json')
      )
    end

    context 'with a logger' do
      let(:logger) do
        @messages = []
        l = LogsForMyFamily::Logger.new
        l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
        l
      end

      it 'logs the update' do
        expect(@messages).to include(
          contain_exactly(
            :notice, :updated_profile, a_hash_including(name: :source0, previous_version: '1', new_version: '2')
          )
        )
      end
    end
  end

  context 'when the profile is not updated' do
    let(:stub_responses) do
      {
        'test' => { content: StringIO.new, configuration_version: '1', content_type: 'application/json' },
      }
    end

    it 'does not update applying_profile' do
      expect(state.applying_profile).to eq applying_profile
    end

    it 'does not error' do
      expect(result.errors?).to be false
    end

    context 'with a logger' do
      let(:logger) do
        @messages = []
        l = LogsForMyFamily::Logger.new
        l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
        l
      end

      it 'logs a warning' do
        expect(@messages).to include(
          contain_exactly(
            :warning, :no_update, a_hash_including(name: :source0, version: '1')
          )
        )
      end
    end
  end

  context 'when the update fails' do
    let(:stub_responses) do
      {
        'test' => 'BadRequestException',
      }
    end

    it 'errors' do
      expect(result.errors).to  match(
        source0: [an_instance_of(Aws::AppConfig::Errors::BadRequestException)]
      )
    end
  end
end