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

require 'config_o_mat/configurator/op/refresh_all_profiles'

require 'config_o_mat/configurator/memory'
require 'config_o_mat/shared/types'

require 'aws-sdk-appconfig'
require 'logsformyfamily'

require 'securerandom'

RSpec.describe ConfigOMat::Op::RefreshAllProfiles do
  def perform
    described_class.call(state)
  end

  before { @result = perform }

  subject(:result) { @result }

  let(:state) do
    ConfigOMat::Configurator::Memory.new(
      profile_defs: profile_defs,
      applied_profiles: applied_profiles,
      client_id: client_id,
      appconfig_client: client_stub,
      logger: logger
    )
  end

  let(:profile_defs) do
    {
      source0: ConfigOMat::Profile.new(application: 'test', environment: 'test', profile: 'test'),
      source1: ConfigOMat::Profile.new(application: 'foo', environment: 'bar', profile: 'boo'),
      source2: ConfigOMat::Profile.new(application: 'other', environment: 'test', profile: 'test')
    }
  end

  let(:applied_profiles) do
    {
      source0: ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
      source1: ConfigOMat::LoadedAppconfigProfile.new(:source1, '1', { answer: 255 }.to_json, 'application/json')
    }
  end

  let(:stub_responses) do
    {
      'test' => { content: StringIO.new({ answer: 42 }.to_json), configuration_version: '1', content_type: 'application/json' },
      'foo' => { content: StringIO.new({ answer: 181 }.to_json), configuration_version: '2', content_type: 'application/json' },
      'other' => { content: StringIO.new({ answer: 255 }.to_json), configuration_version: '1', content_type: 'application/json' }
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

  let(:client_id) { SecureRandom.uuid }
  let(:logger) { nil }

  context 'when all profiles refresh' do
    it 'includes versions for applied profiles' do
      expect(client_stub.api_requests).to contain_exactly(
        a_hash_including(
          params: { application: 'test', environment: 'test', configuration: 'test', client_configuration_version: '1',
                    client_id: client_id }
        ),
        a_hash_including(
          params: { application: 'foo', environment: 'bar', configuration: 'boo', client_configuration_version: '1',
                    client_id: client_id }
        ),
        a_hash_including(
          params: { application: 'other', environment: 'test', configuration: 'test', client_id: client_id }
        )
      )
    end

    it 'sets the profiles to apply' do
      expect(state.profiles_to_apply).to contain_exactly(
        ConfigOMat::LoadedAppconfigProfile.new(:source1, '2', { answer: 181 }.to_json, 'application/json'),
        ConfigOMat::LoadedAppconfigProfile.new(:source2, '1', { answer: 255 }.to_json, 'application/json')
      )
    end

    it 'sets last refresh time' do
      expect(state.last_refresh_time).to be_within(1).of(Time.now.to_i)
    end

    context 'with a logger' do
      let(:logger) do
        @messages = []
        l = LogsForMyFamily::Logger.new
        l.backends = [proc { |level_name, event_type, merged_data| @messages << [level_name, event_type, merged_data] }]
        l
      end

      RSpec::Matchers.define_negated_matcher :an_array_excluding, :include

      it 'logs updated profiles' do
        expect(@messages).to include(
          contain_exactly(
            :notice, :updated_profile, a_hash_including(name: :source1, previous_version: '1', new_version: '2')
          ),
          contain_exactly(
            :notice, :updated_profile, a_hash_including(name: :source2, previous_version: nil, new_version: '1')
          )
        ).and(an_array_excluding(include(a_hash_including(name: :source0))))
      end
    end
  end

  context 'with no applied profiles' do
    let(:applied_profiles) { nil }

    it 'sets the profiles to apply' do
      expect(state.profiles_to_apply).to contain_exactly(
        ConfigOMat::LoadedAppconfigProfile.new(:source0, '1', { answer: 42 }.to_json, 'application/json'),
        ConfigOMat::LoadedAppconfigProfile.new(:source1, '2', { answer: 181 }.to_json, 'application/json'),
        ConfigOMat::LoadedAppconfigProfile.new(:source2, '1', { answer: 255 }.to_json, 'application/json')
      )
    end

    it 'sets last refresh time' do
      expect(state.last_refresh_time).to be_within(1).of(Time.now.to_i)
    end
  end

  context 'when a profile update errors' do
    let(:stub_responses) do
      {
        'test' => { content: StringIO.new, configuration_version: '1', content_type: 'application/json' },
        'foo' => { content: StringIO.new({ answer: 181 }.to_json), configuration_version: '2', content_type: 'application/json' },
        'other' => 'BadRequestException'
      }
    end

    it 'errors' do
      expect(result.errors).to match(
        source2: [an_instance_of(Aws::AppConfig::Errors::BadRequestException)]
      )
    end
  end
end
