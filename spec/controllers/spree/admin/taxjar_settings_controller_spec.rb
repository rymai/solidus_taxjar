require 'spec_helper'

describe Spree::Admin::TaxjarSettingsController, type: :controller do
  render_views

  let(:user) { mock_model(Spree.user_class).as_null_object }

  before(:each) do
    allow(controller).to receive(:spree_current_user).and_return(user)
    allow(controller).to receive(:authorize!).and_return(true)
    allow(controller).to receive(:authorize_admin).and_return(true)
    allow(user).to receive(:spree_roles).and_return []
  end

  describe "GET 'edit'" do

    def send_request
      get :edit
    end

    before do
      send_request
    end

    it "assigns @preferences_api" do
      expect( response.body ).to match 'Taxjar api key'
      expect( response.body ).to match 'Taxjar enabled'
      expect( response.body ).to match 'Taxjar debug enabled'
    end

    it "renders edit template" do
      expect( response.body ).to match Spree.t(:taxjar_settings)
    end

  end

  describe "PUT 'update'" do

    def send_request
      put :update, taxjar_api_key: 'SAMPLE_API_KEY', taxjar_enabled: '1', taxjar_debug_enabled: '1'
    end

    before do
      send_request
    end

    it "saves taxjar_api_key with passed parameter" do
      expect(Spree::Config[:taxjar_api_key]).to eq 'SAMPLE_API_KEY'
    end

    it "saves taxjar_enabled with passed parameter" do
      expect(Spree::Config[:taxjar_enabled]).to be(true)
    end

    it "saves taxjar_debug_enabled with passed parameter" do
      expect(Spree::Config[:taxjar_debug_enabled]).to be(true)
    end

    it "sets flash message to success" do
      expect(flash[:success]).to eq Spree.t(:taxjar_settings_updated)
    end

    it "renders edit template" do
      expect(response).to redirect_to(edit_admin_taxjar_settings_path)
    end

  end

end
