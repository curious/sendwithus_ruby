require_relative '../../test_helper'

describe SendWithUs::Api do
  let(:subject) { SendWithUs::Api.new }
  let(:any_request) { SendWithUs::ApiRequest.any_instance }

  describe '.configuration with initializer' do
    before do
      @initializer_api_key = 'CONFIG_TEST'
      SendWithUs::Api.configure { |config| config.api_key = @initializer_api_key }
    end

    it('configs') { SendWithUs::Api.new.configuration.api_key.must_equal @initializer_api_key }
  end

  describe '.configuration with custom' do
    before do
      @initializer_api_key = 'CONFIG_TEST'
      @custom_api_key = 'STUFF_AND_THINGS'
      SendWithUs::Api.configure { |config| config.api_key = @initializer_api_key }
    end

    it('configs') { SendWithUs::Api.new( api_key: @custom_api_key ).configuration.api_key.must_equal @custom_api_key }
  end

  # FIXME: There should be tests for send_email

  describe '#send_emails' do
    let(:email_param_sets) do
      [
        ['id_1', { name: 'name_1', address: 'address_1' }],
        ['id_2', { name: 'name_2', address: 'address_2' }, { data: { foo: 'bar' }, version_name: 'version' }],
      ]
    end
    let(:send_emails) { subject.send_emails(email_param_sets) }
    it 'posts with the batch endpoint' do
      any_request.expects(:post).with(:batch, any_parameters)
      send_emails
    end
    it 'posts with a json string' do
      any_request.expects(:post).with(anything, instance_of(String))
      send_emails
    end
    it 'posts with requests of the send path' do
      any_request.expects(:post).with do |_endpoint, json|
        requests = JSON.parse(json)
        requests.all? do |request|
          request['path'] == '/api/v1/send'
        end
      end
      send_emails
    end
    it 'posts with requests of method POST' do
      any_request.expects(:post).with do |_endpoint, json|
        requests = JSON.parse(json)
        requests.all? { |request| request['method'] == 'POST' }
      end
      send_emails
    end
    it 'posts with requests that have the correct email_payload as the body' do
      any_request.expects(:post).with do |_endpoint, json|
        requests = JSON.parse(json, symbolize_names: true)
        payloads = requests.map { |request| request[:body] }
        payloads[0].must_equal({ email_id: 'id_1',
                                 recipient: { name: 'name_1', address: 'address_1'} })
        payloads[1].must_equal({ email_id: 'id_2',
                                 recipient: { name: 'name_2', address: 'address_2'},
                                 email_data: { foo: 'bar' },
                                 version_name: 'version' })
      end
      send_emails
    end
  end

  describe '#logs' do
    describe 'without options' do
      let(:options) { nil }
      before { any_request.expects(:get).with('logs') }

      it { subject.logs }
    end
    describe 'with options' do
      let(:options) { { count: 2 } }
      before { any_request.expects(:get).with('logs?count=2') }

      it { subject.logs(options) }
    end
  end

  describe '#customer_email_log' do
    describe 'without options' do
      let(:options) { nil }
      let(:email) { 'some@email.stub' }
      before { any_request.expects(:get).with("customers/#{email}/logs") }

      it { subject.customer_email_log(email) }
    end
    describe 'with options' do
      let(:options) { { count: 2 } }
      let(:email) { 'some@email.stub' }
      before { any_request.expects(:get).with("customers/#{email}/logs?count=2") }

      it { subject.customer_email_log(email, options) }
    end
  end

  describe '#log' do
    describe 'with log_id' do
      let(:log_id) { 'log_TESTTEST123' }
      before { any_request.expects(:get).with("logs/#{log_id}") }

      it { subject.log(log_id) }
    end

    describe 'without log_id' do
      it { -> { subject.log }.must_raise ArgumentError }
    end
  end

  describe '#start_on_drip_campaign' do
    let(:email) { 'some@email.stub' }
    let(:drip_campaign_id) { 'dc_SoMeCampaIGnID' }
    let(:locale) { "en-US" }
    let(:tags) { ['tag1', 'tag2'] }
    let(:endpoint) { "drip_campaigns/#{drip_campaign_id}/activate" }

    before { any_request.expects(:post).with(endpoint, payload.to_json) }

    describe 'email_data' do
      let(:payload) { {recipient_address: email, email_data: {foo: 'bar'}} }

      it { subject.start_on_drip_campaign(email, drip_campaign_id, {foo: 'bar'}) }
    end

    describe 'email_data & tags' do
      let(:payload) { {recipient_address: email, email_data: {foo: 'bar'}, tags: tags, locale: locale} }

      it { subject.start_on_drip_campaign(email, drip_campaign_id, {foo: 'bar'}, locale, tags) }
    end

    describe 'tags' do
      let(:payload) { {recipient_address: email, tags: tags, locale: locale} }

      it { subject.start_on_drip_campaign(email, drip_campaign_id, {}, locale, tags) }
    end
  end

  describe '#customer_get' do
      let(:email) {'customer@example.com'}
      before { any_request.expects(:get).with("customers/#{email}") }

      it { subject.customer_get(email) }
  end
end
