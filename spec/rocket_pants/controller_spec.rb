require 'spec_helper'
require 'logger'
require 'stringio'
require 'will_paginate/collection'

describe RocketPants::Base do
  include ControllerHelpers

  describe 'integration' do

    it 'should have the authorization helper methods' do
      instance = controller_class.new
      instance.should respond_to :authenticate_or_request_with_http_basic
      instance.should respond_to :authenticate_or_request_with_http_digest
      instance.should respond_to :authenticate_or_request_with_http_token
    end

    context 'with a valid model' do

      let(:table_manager) { ReversibleData.manager_for(:users) }

      before(:each) { table_manager.up! }
      after(:each)  { table_manager.down! }

      it 'should let you expose a single item' do
        user = User.create :age => 21
        allow(TestController).to receive(:test_data) { user }
        get :test_data
        content[:response].should == user.serializable_hash
      end

      it 'should let you expose a collection' do
        1.upto(5) do |offset|
          User.create :age => (18 + offset)
        end
        allow(TestController).to receive(:test_data) { User.all }
        get :test_data
        content[:response].should == User.all.map(&:serializable_hash)
        content[:count].should == 5
      end

      it 'should let you expose a scope' do
        1.upto(5) do |offset|
          User.create :age => (18 + offset)
        end
        allow(TestController).to receive(:test_data) { User.where('1 = 1') }
        get :test_data
        content[:response].should == User.all.map(&:serializable_hash)
        content[:count].should == 5
      end

    end
  end

  describe 'versioning' do

    it 'should be ok with an optional prefix with the specified prefix' do
      get :echo, {}, :version => 'v1', :rp_prefix => {:text => "v", :required => false}
      content[:error].should be_nil
    end

    it 'should be ok with an optional prefix without the specified prefix' do
      get :echo, {}, :version => '1', :rp_prefix => {:text => "v", :required => false}
      content[:error].should be_nil
    end

    it 'should be ok with a required prefix and one given' do
      get :echo, {}, :version => 'v1', :rp_prefix => {:text => "v", :required => true}
      content[:error].should be_nil
    end

    it 'should return an error when a prefix is required and not given' do
      get :echo, {}, :version => '1', :rp_prefix => {:text => "v", :required => true}
      content[:error].should == 'invalid_version'
    end

    it 'should return an error when a prefix is required and a different one is given' do
      get :echo, {}, :version => 'x1', :rp_prefix => {:text => "v", :required => true}
      content[:error].should == 'invalid_version'
    end

    it 'should return an error when an optional prefix is allowed and a different one is given' do
      get :echo, {}, :version => 'x1', :rp_prefix => {:text => "v", :required => false}
      content[:error].should == 'invalid_version'
    end

    it 'should return an error when a prefix is now allowed and is given' do
      get :echo, {}, :version => 'v1'
      content[:error].should == 'invalid_version'
    end

    it 'should be ok with a valid version' do
      %w(1 2).each do |version|
        get :echo, {}, :version => version.to_s
        content[:error].should be_nil
      end
    end

    it 'should return an error for an invalid version number' do
      [0, 3, 10, 2.5, 2.2, '1.1'].each do |version|
        get :echo, {}, :version => version.to_s
        content[:error].should == 'invalid_version'
      end
    end

    it 'should return an error for no version number' do
      get :echo, {}, :version => nil
      content[:error].should == 'invalid_version'
    end

  end

  describe 'respondable' do
    it 'should include url_options in default_serializer_options' do
      my_respondable = Object.new
      my_respondable.instance_eval {
        class << self
          include RocketPants::Respondable
        end
        def url_options
          "My Options"
        end
      }

      expect(my_respondable.respond_to?(:default_serializer_options)).to be_truthy
      expect(my_respondable.default_serializer_options).to include(url_options: my_respondable.url_options, root: false)
    end

    it 'should correctly convert a normal collection' do
      allow(TestController).to receive(:test_data) { %w(a b c d) }
      get :test_data
      content[:response].should == %w(a b c d)
      content[:pagination].should be_nil
      content[:count].should == 4
    end

    it 'should correctly convert a normal object' do
      object = {:a => 1, :b => 2}
      allow(TestController).to receive(:test_data) { object }
      get :test_data
      content[:count].should be_nil
      content[:pagination].should be_nil
      content[:response].should == {'a' => 1, 'b' => 2}
    end

    it 'should correctly convert an object with a serializable hash method' do
      object = {:a => 1, :b => 2}
      def object.serializable_hash(*); {:serialised => true}; end
      allow(TestController).to receive(:test_data) { object }
      get :test_data
      content[:response].should == {'serialised' => true}
    end

    it 'should correct convert an object with as_json' do
      object = {:a => 1, :b => 2}
      allow(object).to receive(:as_json) { {:serialised => true } }
      allow(TestController).to receive(:test_data) { object }
      get :test_data
      content[:response].should == {'serialised' => true}
    end


    it 'should correctly hook into paginated responses' do
      pager = WillPaginate::Collection.create(2, 10) { |p| p.replace %w(a b c d e f g h i j); p.total_entries = 200 }
      allow(TestController).to receive(:test_data) { pager }
      hooks = []
      allow_any_instance_of(TestController).to receive(:pre_process_exposed_object).with(pager, :paginated, false) { hooks << :pre }
      allow_any_instance_of(TestController).to receive(:post_process_exposed_object).with(pager, :paginated, false) { hooks << :post }
      get :test_data
      hooks.should == [:pre, :post]
    end

    it 'should correctly hook into collection responses' do
      object = %w(a b c d)
      allow(TestController).to receive(:test_data) { object }
      hooks = []
      allow_any_instance_of(TestController).to receive(:pre_process_exposed_object).with(object, :collection, false) { hooks << :pre }
      allow_any_instance_of(TestController).to receive(:post_process_exposed_object).with(object, :collection, false) { hooks << :post }
      get :test_data
      hooks.should == [:pre, :post]
    end

    it 'should correctly hook into singular responses' do
      object = {:a => 1, :b => 2}
      allow(TestController).to receive(:test_data) { object }
      hooks = []
      allow_any_instance_of(TestController).to receive(:pre_process_exposed_object).with(object, :resource, true) { hooks << :pre }
      allow_any_instance_of(TestController).to receive(:post_process_exposed_object).with(object, :resource, true) { hooks << :post }
      get :test_data
      hooks.should == [:pre, :post]
    end

    it 'should accept status options when rendering json' do
      allow(TestController).to receive(:test_data) { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_render_json
      response.status.should == 201
    end

    it 'should accept status options when responding with data' do
      allow(TestController).to receive(:test_data) { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_responds
      response.status.should == 201
    end

    it 'should accept status options when responding with a single object' do
      allow(TestController).to receive(:test_data) { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_data
      response.status.should == 201
    end

    it 'should accept status options when responding with a paginated collection' do
      allow(TestController).to receive(:test_data) do
        WillPaginate::Collection.create(1, 1) {|c| c.replace([{:hello => "World"}]); c.total_entries = 1 }
      end
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_data
      response.status.should == 201
    end

    it 'should accept status options when responding with collection' do
      allow(TestController).to receive(:test_data) { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:status => :created} }
      get :test_data
      response.status.should == 201
    end

    it 'should let you override the content type' do
      allow(TestController).to receive(:test_data) { {:hello => "World"} }
      allow(TestController).to receive(:test_options) { {:content_type => Mime[:html]} }
      get :test_data
      response.headers['Content-Type'].should =~ /text\/html/
    end

  end

  describe 'caching' do

    let!(:controller_class)    { Class.new TestController }

    it 'should use a set for storing the cached actions' do
      controller_class.cached_actions.should be_a Set
      controller_class.cached_actions.should == Set.new
    end

    it 'should default the caching timeout' do
    end

    it 'should let you set the caching timeout' do
      expect do
        controller_class.caches :test_data, :cache_for => 10.minutes
        controller_class.caching_timeout.should == 10.minutes
      end.to change(controller_class, :caching_timeout)
    end

    it 'should let you set which actions should be cached' do
      controller_class.cached_actions.should be_empty
      controller_class.caches :test_data
      controller_class.cached_actions.should == ["test_data"].to_set
    end

    describe 'when dealing with the controller' do

      it 'should invoke the caching callback with caching enabled' do
        set_caching_to true do
          allow_any_instance_of(controller_class).to receive(:cache_response)
          get :test_data
        end
      end

      it 'should not invoke the caching callback with caching disabled' do
        set_caching_to false do
          expect_any_instance_of(controller_class).to_not receive(:cache_response)
          get :test_data
        end
      end

      before :each do
        controller_class.caches :test_data
      end

      around :each do |t|
        set_caching_to true, &t
      end

      context 'with a singular response' do

        let(:cached_object) { Object.new }

        before :each do
          allow(RocketPants::Caching).to receive(:cache_key_for).with(cached_object) { "my-object" }
          allow(RocketPants::Caching).to receive(:etag_for).with(cached_object) { "my-object:stored-etag" }
          allow(controller_class).to receive(:test_data) { cached_object }
        end

        it 'should invoke the caching callback correctly' do
          allow_any_instance_of(controller_class).to receive(:cache_response).with(cached_object, true)
          get :test_data
        end

        it 'should not set the expires in time' do
          get :test_data
          response['Cache-Control'].to_s.should_not =~ /max-age=(\d+)/
        end

        it 'should set the response etag' do
          get :test_data
          response['ETag'].should == '"my-object:stored-etag"'
        end

      end

      context 'with a collection response' do

        let(:cached_objects) { [Object.new] }

        before :each do
          expect(RocketPants::Caching).to_not receive(:cache_key_for)
          expect(RocketPants::Caching).to_not receive(:etag_for)
          allow(controller_class).to receive(:test_data) { cached_objects }
        end

        it 'should invoke the caching callback correctly' do
          allow_any_instance_of(controller_class).to receive(:cache_response).with(cached_objects, false)
          get :test_data
        end

        it 'should set the expires in time' do
          get :test_data
          response['Cache-Control'].to_s.should =~ /max-age=(\d+)/
        end

        it 'should not set the response etag' do
          get :test_data
          response["ETag"].should be_nil
        end

      end

    end

  end

  describe 'jsonp support' do

    let!(:first_controller) { Class.new(TestController)   }
    let!(:controller_class) { Class.new(first_controller) }

    it 'should let you specify requests as having jsonp' do
      controller_class.jsonp
      get :echo, :echo => "Hello World"
      response.content_type.should include 'application/json'
      response.body.should == %({"response":{"echo":"Hello World"}})
      get :echo, :echo => "Hello World", :callback => "test"
      response.content_type.should include 'application/javascript'
      response.body.should == %|test({"response":{"echo":"Hello World"}});|
    end

    it 'should automatically inherit it' do
      first_controller.jsonp :enable => true
      get :echo, :echo => "Hello World", :callback => "test"
      response.content_type.should include 'application/javascript'
      response.body.should == %|test({"response":{"echo":"Hello World"}});|
      get :echo, :echo => "Hello World", :other_callback => "test"
      response.content_type.should include 'application/json'
      response.body.should == %({"response":{"echo":"Hello World"}})
    end

    it 'should allow you to disable at a lower level' do
      first_controller.jsonp :enable => true
      controller_class.jsonp :enable => false
      get :echo, :echo => "Hello World", :callback => "test"
      response.content_type.should include 'application/json'
      response.body.should == %({"response":{"echo":"Hello World"}})
    end

    it 'should let you specify options to it' do
      controller_class.jsonp :parameter => 'cb'
      get :echo, :echo => "Hello World", :cb => "test"
      response.content_type.should include 'application/javascript'
      response.body.should == %|test({"response":{"echo":"Hello World"}});|
      get :echo, :echo => "Hello World", :callback => "test"
      response.content_type.should include 'application/json'
      response.body.should == %({"response":{"echo":"Hello World"}})
    end

    it 'should let you specify it on a per action level' do
      controller_class.jsonp :only => [:test_data]
      get :echo, :echo => "Hello World", :callback => "test"
      response.content_type.should include 'application/json'
      response.body.should == %({"response":{"echo":"Hello World"}})
      allow(controller_class).to receive(:test_data) { {"other" => true} }
      get :test_data, :callback => "test"
      response.content_type.should include 'application/javascript'
      response.body.should == %|test({"response":{"other":true}});|
    end

    it 'should not wrap non-get actions' do
      controller_class.jsonp
      post :echo, :echo => "Hello World", :callback => "test"
      response.content_type.should include 'application/json'
      response.body.should == %({"response":{"echo":"Hello World"}})
    end

    it 'should have the correct content length' do
      controller_class.jsonp
      get :echo, :echo => "Hello World", :callback => "test"
      response.content_type.should include 'application/javascript'
      response.body.should == %|test({"response":{"echo":"Hello World"}});|
      response.headers['Content-Length'].to_i.should == response.body.bytesize
    end

  end

  describe 'custom metadata' do

    it 'should allow custom metadata' do
      get :test_metadata, :metadata => {:awesome => "1"}
      decoded = ActiveSupport::JSON.decode(response.body)
      decoded["awesome"].should == "1"
    end
  end

  context 'empty responses' do

    it 'correctly returns a blank body' do
      get :test_head
      response.status.should == 201
      response.body.should be_blank
      response.content_type.should include 'application/json'
    end
  end
end