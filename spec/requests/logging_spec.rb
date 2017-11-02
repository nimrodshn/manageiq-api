#
# REST API Logging Tests
#
describe "Logging" do
  before do
    @log = StringIO.new
    @logger = Logger.new(@log)
    $api_log.loggers << @logger
  end

  after { $api_log.loggers.delete(@logger) }

  describe "Successful Requests logging" do
    it "logs hashed details about the request" do
      api_basic_authorize collection_action_identifier(:users, :read, :get)

      get api_users_url

      @log.rewind
      request_log_line = @log.readlines.detect { |l| l =~ /MIQ\(.*\) Request:/ }
      expect(request_log_line).to include(':path=>"/api/users"', ':collection=>"users"', ":collection_id=>nil",
                                          ":subcollection=>nil", ":subcollection_id=>nil")
    end

    it "logs all hash entries about the request" do
      api_basic_authorize

      get api_entrypoint_url

      @log.rewind
      request_log_line = @log.readlines.detect { |l| l =~ /MIQ\(.*\) Request:/ }
      expect(request_log_line).to include(":method", ":action", ":fullpath", ":url", ":base", ":path", ":prefix",
                                          ":version", ":api_prefix", ":collection", ":c_suffix", ":collection_id",
                                          ":subcollection", ":subcollection_id")
    end

    it "filters password attributes in nested parameters" do
      api_basic_authorize collection_action_identifier(:services, :create)

      post(api_services_url, :params => gen_request(:create, "name" => "new_service_1", "options" => { "password" => "SECRET" }))

      expect(@log.string).to include(
        'Parameters:     {"action"=>"create", "controller"=>"api/services", "format"=>"json", ' \
        '"body"=>{"action"=>"create", "resource"=>{"name"=>"new_service_1", ' \
        '"options"=>{"password"=>"[FILTERED]"}}}}'
      )
    end

    it "logs additional system authentication with miq_token" do
      Timecop.freeze("2017-01-01 00:00:00 UTC") do
        server_guid = MiqServer.first.guid
        userid = @user.userid
        timestamp = Time.now.utc

        miq_token = MiqPassword.encrypt({:server_guid => server_guid, :userid => userid, :timestamp => timestamp}.to_yaml)

        get api_entrypoint_url, :headers => {Api::HttpHeaders::MIQ_TOKEN => miq_token}

        expect(@log.string).to include(
          "System Auth:    {:x_miq_token=>\"#{miq_token}\", :server_guid=>\"#{server_guid}\", " \
          ":userid=>\"api_user_id\", :timestamp=>2017-01-01 00:00:00 UTC}",
          'Authentication: {:type=>"system", :token=>nil, :x_miq_group=>nil, :user=>"api_user_id"}'
        )
      end
    end
  end
end
