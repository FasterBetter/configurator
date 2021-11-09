# frozen_string_literal: true

require 'configurator_types'

RSpec.describe LoadedProfile do
  subject(:profile) do
    described_class.new(name, version, contents, content_type)
  end

  let(:name) { :source0 }
  let(:version) { '1' }
  let(:contents) { { answer: 42 }.to_json }
  let(:content_type) { 'application/json' }

  context 'with json' do
    it 'parses the json' do
      expect(profile).to have_attributes(
        name: name, version: version,
        contents: { answer: 42 },
        errors?: false
      )
    end
  end

  context 'with invalid json' do
    let(:contents) { '{ "answer": 42 ' }

    it 'reports errors' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: nil,
        errors?: true, errors: { contents: [an_instance_of(JSON::ParserError)] }
      )
    end
  end

  context 'with yaml' do
    let(:contents) { "answer: 42\n" }
    let(:content_type) { 'application/x-yaml' }

    it 'parses the yaml' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: { answer: 42 },
        errors?: false
      )
    end
  end

  context 'with invalid yaml' do
    let(:contents) { "foo:\n  - bar\n  -jkfd\n  - baz\n" }
    let(:content_type) { 'application/x-yaml' }

    it 'reports errors' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: nil,
        errors?: true, errors: { contents: [an_instance_of(Psych::SyntaxError)] }
      )
    end
  end

  context 'with plain text' do
    let(:contents) { 'foobarbaz' }
    let(:content_type) { 'text/plain' }

    it 'uses the text as content' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: contents, errors?: false
      )
    end
  end

  context 'with an invalid content_type' do
    let(:content_type) { 'application/x-dne' }

    it 'errors' do
      expect(profile).to have_attributes(
        name: name, version: version, contents: nil,
        errors?: true, errors: { content_type: [include('must be one of')] }
      )
    end
  end

  describe '#validate' do
    before { profile.validate }

    context 'with an empty name' do
      let(:name) { :"" }

      it 'is invalid' do
        expect(profile).to have_attributes(
          errors: { name: ['must be present'] }
        )
      end
    end

    context 'with an invalid name type' do
      let(:name) { 'foo' }

      it 'is invalid' do
        expect(profile).to have_attributes(
          errors: { name: ['must be a Symbol'] }
        )
      end
    end

    context 'with an empty version' do
      let(:version) { nil }

      it 'is invalid' do
        expect(profile).to have_attributes(
          errors: { version: ['must be present'] }
        )
      end
    end

    context 'with empty contents' do
      let(:content_type) { 'text/plain' }
      let(:contents) { '' }

      it 'is invalid' do
        expect(profile).to have_attributes(
          errors: { contents: ['must be present'] }
        )
      end
    end
  end
end
