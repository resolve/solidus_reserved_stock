require "spec_helper"

# Specs ReservedStockItem subclass to StockItem
describe Spree::Stock::Reserver, type: :model do
  let(:user) { create(:user) }
  let(:original_stock_location) { create(:stock_location) }
  let(:variant) { create(:variant) }
  let(:reserved_stock_location) { Spree::StockLocation.reserved_items_location }
  let(:reserved_stock_item) do
    create(
      :reserved_stock_item,
      variant: variant,
      stock_location: reserved_stock_location,
      original_stock_location: original_stock_location,
      user: user,
      expires_at: 1.day.from_now,
      backorderable: false
    )
  end
  let(:expired_reserved_stock_item) do
    create(
      :reserved_stock_item,
      variant: variant,
      stock_location: reserved_stock_location,
      original_stock_location: original_stock_location,
      user: user,
      expires_at: 1.day.ago,
      backorderable: false
    )
  end

  subject { Spree::Stock::Reserver.new }

  context "#reserve" do
    before do
      stock_item = original_stock_location.stock_item_or_create(variant)
      stock_item.adjust_count_on_hand(10)
    end
    it "moves stock items to the reserved stock location" do
      subject.reserve(variant, original_stock_location, user, 4)
      expect(user.reserved_count_on_hand(variant)).to eq 4
      expect(original_stock_location.count_on_hand(variant)).to eq 6
    end
    it "remembers original stock location" do
      subject.reserve(variant, original_stock_location, user, 4)
      reserved_stock_item = user.reserved_stock_item(variant)
      expect(
        reserved_stock_item.original_stock_location
      ).to eq original_stock_location
    end
    it "won't reserve more stock than exists" do
      expect do
        subject.reserve(variant, original_stock_location, user, 1000)
      end.to raise_error Spree::Stock::Reserver::InvalidQuantityError
    end
    it "won't reserve zero stock" do
      expect do
        subject.reserve(variant, original_stock_location, user, 0)
      end.to raise_error Spree::Stock::Reserver::InvalidQuantityError
    end
  end

  context "#restock" do
    before(:each) do
      reserved_stock_item
    end
    it "can restore all stock to the original stock location" do
      subject.restock(variant, user)
      expect(original_stock_location.count_on_hand(variant)).to eq 10
      expect(user.reserved_count_on_hand(variant)).to eq 0
    end
    it "can restore a quantity of stock to the original stock location" do
      subject.restock(variant, user, 4)
      expect(original_stock_location.count_on_hand(variant)).to eq 4
      expect(user.reserved_count_on_hand(variant)).to eq 6
    end
    it "won't restock more stock than exists"do
      expect do
        subject.restock(variant, user, 1000)
      end.to raise_error Spree::Stock::Reserver::InvalidQuantityError
    end
    it "won't restock zero stock" do
      expect do
        subject.restock(variant, user, 0)
      end.to raise_error Spree::Stock::Reserver::InvalidQuantityError
    end
  end

  context "#restock_expired" do
    it "restores expired ReservedStockItems" do
      expired_reserved_stock_item
      subject.restock_expired
      expect(original_stock_location.count_on_hand(variant)).to eq 10
      expect(user.reserved_count_on_hand(variant)).to eq 0
    end
    it "doesn't restore unexpired ReservedStockItems" do
      reserved_stock_item
      subject.restock_expired
      expect(original_stock_location.count_on_hand(variant)).to eq 0
      expect(user.reserved_count_on_hand(variant)).to eq 10
    end
  end
end