require 'spec_helper'

describe Spree::Calculator::TaxjarCalculator do

  let!(:taxjar_exempt_tax_code) { "99999" }
  let!(:country) { create(:country) }
  let!(:state) { create(:state, country: country, abbr: "TX") }
  let!(:state_ca) { create(:state, country: country, abbr: "CA") }
  let!(:zone) { create(:zone, name: "Country Zone", default_tax: true, zone_members: []) }
  let!(:ship_address) { create(:ship_address, city: "Adrian", zipcode: "79001", state: state) }
  let!(:ship_address_ca) { create(:ship_address, city: "Los Angeles", zipcode: "90002", state: state_ca) }
  let!(:tax_category) { create(:tax_category, tax_rates: []) }
  let!(:tax_category_exempt) { create(:tax_category, tax_rates: []) }
  let!(:rate) { create(:tax_rate, tax_category: tax_category, amount: 0.05, included_in_price: included_in_price) }
  let(:included_in_price) { false }
  let!(:calculator) { Spree::Calculator::TaxjarCalculator.new(calculable: rate, preferred_api_key: '04d828b7374896d7867b03289ea20957') }
  let!(:order) { create(:order,ship_address_id: ship_address.id) }
  let!(:line_item) { create(:line_item, price: 10, quantity: 3, order_id: order.id) }
  let!(:line_item_exempt) { create(:line_item, price: 10, quantity: 3, order_id: order.id) }
  let!(:shipment) { create(:shipment, cost: 10, order: order) }
  let!(:order_ca) { create(:order,ship_address_id: ship_address_ca.id) }
  let!(:line_item_ca) { create(:line_item, price: 10, quantity: 3, order_id: order_ca.id) }
  let!(:shipment_ca) { create(:shipment, cost: 10, order: order_ca) }
  let!(:taxjar) { double(Taxjar::Client) }
  let(:taxjar_response) { double(Taxjar::Tax) }

  before do
    ## Forcing tests with shipping_address as tax_address
    Spree::Config[:tax_using_ship_address] = true
  end

  describe ".description" do
    it 'returns the description for the calculator' do
      expect(calculator.description).to eq(Spree.t(:taxjar_calculator_description))
    end
  end

  describe "#compute_order" do
    it 'returns tax for the order upto two decimal places' do
      expect{ calculator.compute_order(order)}.to raise_error(RuntimeError, 'Calculate tax for line_item and shipment and not order')
    end
  end

  describe '#compute_line_item' do
    before :each do
      tax_category_exempt.update_column(:tax_code, taxjar_exempt_tax_code)
      line_item_exempt.update_column(:tax_category_id, tax_category_exempt.id)
    end

    context 'when rate not included in price' do
      it 'returns tax for the line_item upto two decimal places' do
        VCR.use_cassette "fully_taxable_line_item" do
          expect(calculator.compute_line_item(line_item)).to eq(2.33)
        end
      end

      it 'should return ZERO tax for line_item having tax exempt code' do
        VCR.use_cassette "fully_exempt_line_item" do
          expect(calculator.compute_line_item(line_item_exempt)).to eq(0.0)
        end
      end
    end

    context 'when rate included in price' do
      before do
        rate.included_in_price = true
        rate.save!
      end
      it 'returns tax for the line_item upto two decimal places' do
        expect(calculator.compute_line_item(line_item)).to eq(0)
      end
    end

    context 'when a line item changes but has the exact same attribtues as a previous one' do
      it 'returns tax for the line_item upto two decimal places' do
        VCR.use_cassette "fully_taxable_line_item" do
          # Cache the Taxjar response
          expect(calculator.compute_line_item(line_item)).to eq(2.33)
        end

        order.line_items.first.destroy
        new_line_item = create(:line_item, price: 10, quantity: 3, order_id: order.id)

        VCR.use_cassette "fully_taxable_new_line_item" do
          expect(calculator.compute_line_item(new_line_item)).to eq(2.33)
        end
      end
    end
  end

  describe '#compute_shipment' do
    context 'Nexus charges tax on shipping' do
      it 'should return tax on shipping' do
        VCR.use_cassette "compute_shipment_with_texas_address" do
          expect(calculator.compute_shipment(shipment)).to eq(0.78)
        end
      end
    end

    context 'Nexus charges NO tax on shipping' do
      it 'should return tax on shipping as ZERO' do
        VCR.use_cassette "compute_shipment_with_california_address" do
          expect(calculator.compute_shipment(shipment_ca)).to eq(0)
        end
      end
    end
  end

  describe '#rate' do
    it 'returns calculable' do
      expect(calculator.send(:rate)).to eq(rate)
    end
  end

  describe '#compute_shipping_rate' do
    context 'when rate included in price' do
      before do
        rate.included_in_price = true
        rate.save!
      end
      it 'will raise RuntimeError' do
        expect{ calculator.compute_shipping_rate(line_item)}.to raise_error(RuntimeError)
      end
    end
    context 'when rate not included in price' do
      it 'will return tax for shipping' do
        expect(calculator.compute_shipping_rate(line_item)).to eq(0.0)
      end
    end
  end
end
