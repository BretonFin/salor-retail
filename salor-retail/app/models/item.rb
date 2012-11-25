# coding: UTF-8

# Salor -- The innovative Point Of Sales Software for your Retail Store
# Copyright (C) 2012-2013  Red (E) Tools LTD
# 
# See license.txt for the license applying to all files within this software.

# {VOCABULARY} item_price item_category item_location_id tax_profile_info info foreign_key_constraint logging_time coupon_amount_paid paying_agent reimburseable unknown_item
# {VOCABULARY} location_reversed info_on_category real_category_name part_ident part_qty2 quantity_of_sale gift_card_remainder coupon_b1g1 gift_card_owner
class Item < ActiveRecord::Base
  # {START}
	include SalorScope
  include SalorError
  include SalorBase
  include SalorModel
	belongs_to :category
	belongs_to :vendor
	belongs_to :location
  belongs_to :tax_profile
  belongs_to :item_type
  belongs_to :item
  belongs_to :shipper
  has_many :actions, :as => :owner, :order => "weight asc"
  has_many :parts, :class_name => 'Item', :foreign_key => :part_id
  has_one :parent, :class_name => 'Item', :foreign_key => :child_id
  belongs_to :child, :class_name => 'Item'
  has_many :order_items



  validates_presence_of :sku
  validate :validify


  #scope :by_vendor, lambda {|vid| where(:vendor_id => vid)}
  #scope :visible, lambda { where("hidden = 0") }
  #scope :by_keywords, lambda {|keywords| where("name LIKE '%#{keywords}%' OR sku LIKE '#{keywords}%'")}

  after_create :set_amount_remaining
  
  before_save :run_actions
  COUPON_TYPES = [
      {:text => I18n.t('views.forms.percent_off'), :value => 1},
      {:text => I18n.t('views.forms.fixed_amount_off'), :value => 2},
      {:text => I18n.t('views.forms.buy_one_get_one'), :value => 3}
  ]
  REORDER_TYPES = ['default_export','tobacco_land']
  
  def self.csv_headers
    return [:name,:sku,:base_price,:quantity,:quantity_sold,:tax_profile_name,:tax_profile_amount,:category_name,:location_name]
  end
  def to_csv(headers=nil)
    headers = Item.csv_headers if headers.nil?
    values = []
    headers.each do |h|
      values << self.send(h)
    end
    return values.join("\t")
  end
  def tax_profile_name
    n = 'NoTaxProfile'
    return self.tax_profile.name if self.tax_profile
    return n
  end
  def get_translated_name(locale)
    locale = locale.to_s
    trans = read_attribute(:name_translations)
    if trans.empty? or trans.nil?
      return read_attribute(:name)
    else
      hash = ActiveSupport::JSON.decode(trans)
      if hash[locale] then
        return hash[locale]
      else
        return read_attribute :name
      end
    end
  end
  def name_translations=(hash)
    write_attribute(:name_translations,hash.to_json)
  end
  def name_translations
    text = read_attribute(:name_translations)
    if text.empty? or text.nil? then
      return {}
    else
      return ActiveSupport::JSON.decode(text)
    end
  end
  def item_type_name=(name)
    it = ItemType.find_by_behavior(name)
    if it then
      self.item_type_id = it.id
    end
  end
  def category_name
    return self.category.name if self.category
  end
  def category_name=(str)
    c = Category.scopied.find_by_name(str)
    if c then
      self.category = c
    end
  end
  def location_name
    return self.location.name if self.location
    return "NoLocation"
  end
  def self.repair_items
    Item.where('child_id IS NOT NULL and child_id != 0').each do |item|
      if item.parent or item.child then
        if item.child then
          if item.parent and item.child.id == item.parent.id then
            puts "#{item.sku} parent.id == child.id"
            item.parent.update_attribute :child_id, 0
          end
          if item.child_sku == item.sku then
            puts "#{item.sku} == child_sku"
            item.update_attribute :child_id, 0
          end
        end
        if item.parent_sku == item.sku then
          puts "#{item.sku} == parent_sku"
          item.parent.update_attribute :child_id,0
        end
      end # end if item.parent or item.child
    end
  end
  #
  def run_actions
    if self.actions.any? then
      Action.run(self, :on_save)
    end
  end
  def parent_sku
    if self.parent then
      return self.parent.sku
    end
    ""
  end
  def child_sku
    if self.child then
      return self.child.sku
    end
    ""
  end
  def parent
    Item.find_by_child_id(self.id) unless self.new_record?
  end
  def child
    Item.find_by_id(self.child_id)
  end
  def parent_sku=(string)
    if string.empty? then
      self.parent = nil
      return
    end
    if string == self.sku then
      errors.add(:child_sku,I18n.t("system.errors.parent_sku"))
      GlobalErrors.append_fatal("system.errors.parent_sku")
      return
    end
    p = Item.find_by_sku(string)
    if p then
      if self.child.id == p.id then
        errors.add(:parent_sku, I18n.t("system.errors.parent_sku"))
        GlobalErrors.append_fatal("system.errors.parent_sku")
      end
      # puts "Updating child_id of parent" + p.sku;
      p.update_attribute(:child_id,self.id)
    else
      errors.add(:parent_sku, I18n.t('system.errors.parent_sku_must_exist'))
      GlobalErrors.append_fatal("system.errors.parent_sku_must_exist")
    end
  end
  def child_sku=(string)
    if string.empty? then
      self.child = nil
      return 
    end
    if self.sku == string then
      errors.add(:child_sku,I18n.t("system.errors.child_sku"))
        GlobalErrors.append_fatal("system.errors.child_sku")
      return
    end
    c = Item.find_by_sku(string)
    if c then
      if self.parent and self.parent.id == c.id then
        errors.add(:child_sku, I18n.t("system.errors.child_sku"))
        GlobalErrors.append_fatal("system.errors.child_sku")
      end
      self.update_attribute(:child_id,c.id)
    else
      errors.add(:child_sku, I18n.t('system.errors.child_sku_must_exist'))
      GlobalErrors.append_fatal("system.errors.child_sku_must_exist")
    end
  end
  def self.search(keywords)
    if keywords =~ /([\w]+) (\d{1,2}[\.\,]\d{1,2})/ then
      parts = keywords.match(/([\w]+) (\d{1,2}[\.\,]\d{1,2})/)
      price = SalorBase.string_to_float(parts[2])
      return Item.scopied.where("name LIKE '%#{parts[1]}%' and base_price > #{(price - 5).to_i} and base_price < #{(price + 5).to_i}")
    else
      return Item.scopied.where("name LIKE '%#{parts[1]}%'")
    end
  end
  def self.get_by_code(code,emp)
    # Let's see if they entered a price
    pm = code.match(/(\d{1,9}[\.\,]\d{1,2})/)
    if pm and pm[1] then
      i = Item.scopied(emp).where("sku LIKE 'DMY%' and base_price = #{SalorBase.string_to_float(code)}") 
      if i.empty? then
        i = Item.scopied.find_or_create_by_sku("DMY" + GlobalData.salor_user.id.to_s + Time.now.strftime("%y%m%d") + rand(999).to_s)
        i.base_price = code
        i.make_valid
        i.save
        return i
      end 
      if i.respond_to? :first and i.first
        i = i.first
      end
      return i
    end # end if pm

    item = Item.scopied(emp).find_by_sku(code)
    return item if item
    #We didn't find it, so let's see if we can parse the code.
    m = code.match(/\d{2}(\d{5})(\d{5})/)
    item = Item.scopied(emp).find_by_sku(m[1]) if m
    if item then
      if not item.is_gs1 == true then
        item.update_attribute(:is_gs1, true)
      end
      return item
    end
    lcard = LoyaltyCard.scopied(emp).find_by_sku(code)
    return lcard if lcard
    #oops, still haven't found it, let's creat a dummy item
    i = Item.scopied(emp).find_or_create_by_sku(code)
    i.vendor_id = emp.get_meta.vendor_id
    i.make_valid
    return i
  end

  def price
    conds = "(item_sku = '#{self.sku}' and applies_to = 'Item') OR (location_id = '#{self.location_id}' and applies_to = 'Location') OR (category_id = '#{self.category_id}' and applies_to = 'Category') OR (applies_to = 'Vendor' and amount_type = 'percent')"
    price = self.base_price
    discounted = false
    damount = 0
    Discount.scopied.where(conds).each do |discount|
      if discount.amount_type == 'percent' then
        d = discount.amount / 100
        damount = (self.base_price * d)
        price -= damount
      elsif discount.amount_type == 'fixed' then
        damount = discount.amount
        price -= damount
      end
      discounted = true
    end
    return [price,discounted,damount]
  end

  def base_price=(p)
    p = self.string_to_float(p)
    write_attribute(:base_price,p.to_f)
  end
  def purchase_price=(p)
    p = self.string_to_float(p)
    write_attribute(:purchase_price,p)
  end
  def amount_remaining=(p)
    write_attribute(:amount_remaining,self.string_to_float(p))
  end
  def tax_profile_id=(id)
    tp = TaxProfile.find_by_id(id)
    if tp then
      write_attribute(:tax_profile_amount,tp.value)
      write_attribute(:tax_profile_id,id)
    end
  end
  def item_type_id=(id)
    write_attribute(:behavior,ItemType.find(id).behavior)
    write_attribute(:item_type_id,id)
  end
  def height=(p)
    p = self.string_to_float(p)
    write_attribute(:height,p)
  end
  def width=(p)
    p = self.string_to_float(p)
    write_attribute(:width,p)
  end
  def weight=(p)
    p = self.string_to_float(p)
    write_attribute(:weight,p)
  end
  def length=(p)
    p = self.string_to_float(p)
    write_attribute(:length,p)
  end
  def min_quantity=(p)
    p = self.string_to_float(p)
    write_attribute(:min_quantity,p)
  end
  def packaging_unit=(p)
    p = self.string_to_float(p)
    write_attribute(:packaging_unit,p)
  end
  def part_skus=(items)
    ids = []
    vid = GlobalData.salor_user.meta.vendor_id
    items.each do |item|
      i = Item.find_by_sku(item[:sku])
      i.vendor_id = vid
      i.is_part = 1
      i.part_quantity = self.string_to_float(item[:part_quantity])
      i.save
      if i then
        ids << i.id
      end
    end
    begin
      self.part_ids = ids if ids.any?
    rescue
      GlobalErrors.append_fatal(I18n.t("system.errors.failed_to_save_parts"),self)
      GlobalErrors.append_fatal($!.message,self)
    end
  end
  def batches
    []
  end
  def batch_skus=(batches)
    ids = []
    batches.each do |batch|
      batch[:expires_on] = Date.parse(batch[:expires_on])
      b = Batch.find_or_create_by_sku(batch[:sku])
      b.set_model_owner
      b.add_item(self)
      b.update_attributes(batch)
      b.save
    end
  end

  def gift_card?
    self.item_type.behavior == 'gift_card'
  end
  def coupon?
    self.item_type.behavior == 'coupon'
  end
  def make_valid
    self.sku = self.sku.upcase
    invld = false
    if self.vendor_id.nil? then
      self.vendor_id = $User.vendor.id
      invld = true
    end
    if self.name.blank? then
      self.name = I18n.t("views.dummy_item")
      invld = true
    end
    if self.quantity.nil? then
      self.quantity = 0
      invld = true
    end
    if self.quantity_sold.nil? then
      self.quantity_sold = 0
      invld = true
    end
    if self.base_price.nil? then
      self.base_price = 0
      invld = true
    end
    if not self.item_type_id then
      # puts "Setting Default ItemType"
      self.item_type_id = ItemType.find_by_behavior('normal').id
      invld = true
    end
    if not self.tax_profile then
      # puts "Setting Default TaxProfile"
      if TaxProfile.first
        tp = TaxProfile.scopied($User).find {|t| t if t.default == 1}
        if tp then
          self.tax_profile_id = tp.id
        else
          self.tax_profile_id = GlobalData.tax_profiles.first.id
        end
      end
      invld = true
    end
  end
  def validify
    @item = Item.by_vendor(self.vendor).find_by_sku(self.sku)
    if not @item.nil? and not self.id == @item.id then
      errors.add(:sku, I18n.t('system.errors.sku_must_be_unique',:sku => self.sku))
      GlobalErrors.append_fatal('system.errors.sku_must_be_unique',self,{:sku => self.sku});
      return
    end
    make_valid
    if self.item_type.behavior == 'coupon' then
      unless Item.find_by_sku(self.coupon_applies) then
        errors.add(:coupon_applies,I18n.t('views.item_must_exist'))
        GlobalErrors.append_fatal('views.item_must_exist');
      end
    end
    if self.parent_sku == self.sku then
        errors.add(:coupon_applies,I18n.t('system.errors.parent_sku'))
    end
    if self.child_sku == self.sku then
        errors.add(:coupon_applies,I18n.t('system.errors.child_sku'))
    end 
  end
  def set_amount_remaining
    self.update_attribute(:amount_remaining,self.base_price)
  end
  
  def from_shipment_item(si)
    i = Item.find_by_sku(si.sku)
    if i then
      if i.vendor == si.shipment.shipper then
        i.quantity -= si.quantity
      else
        i.quantity += si.quantity
      end
      if si.purchase_price then
        i.purchase_price = si.purchase_price
      end
      return i
    else
      # puts "No item found..."
      GlobalErrors.append_fatal("system.errors.item_not_found")
    end
    return nil
  end
  
  
  # Reorder recommendation csvs
  
  def self.recommend_reorder(type)
    shippers = Shipper.scopied.find_all_by_reorder_type(type)
    shippers << nil if type == 'default_export'
    items = Item.scopied.visible.where("quantity < min_quantity AND ignore_qty = 0").where(:shipper_id => shippers)
    if not items.any? then
      return nil 
    end
    unless type == 'default_export'
      # Now we need to create a shipment
      shipment = Shipment.new({
          :name => I18n.t("activerecord.models.shipment.default_name") + " - " + I18n.l(Time.now,:format => :salor),
          :price => items.sum(:purchase_price),
          :receiver_id => $Vendor.id,
          :receiver_type => 'Vendor',
          :shipper_id => shippers.first.id,
          :shipment_type => ShipmentType.scopied.first,
          :shipper_type => 'Shipper'
      })
      shipment.save
      items.each do |item|
        si = ShipmentItem.new({
            :name => item.name,
            :base_price => item.base_price,
            :category_id => item.category_id,
            :location_id => item.location_id,
            :item_type_id => item.item_type_id,
            :shipment_id => shipment.id,
            :sku => item.sku,
            :quantity => item.min_quantity - item.quantity,
            :vendor_id => $Vendor.id
        })
        si.save
      end
    end
    return Item.send(type.to_sym,items)
  end
  def self.tobacco_land(items)
    lines = []
    items.each do |item|
      sku = item.shipper_sku.blank? ? item.sku[0..3] : item.shipper_sku[0..3]
      lines << "%s %04d" % [sku,(item.min_quantity - item.quantity).to_i] 
    end
    return lines.join("\x0D\x0A")
  end
  def self.default_export(items)
    lines = []
    items.each do |item|
      lines << "%s\t%s\t%d\t%f" % [item.name,item.sku,(item.min_quantity - item.quantity).to_i,item.purchase_price.to_f]
    end
    return lines.join("\n")
  end

  def quantity=(q)
    q = 0 if q.nil? or q.blank?
    q = q.to_s.gsub(',','.')
    q = q.to_f.round(3)
    difference = q - self.quantity
    write_attribute(:quantity, q) and return unless difference < 0 and q == q.round and self.quantity == self.quantity.round
    # continue only for integer quantities and decrementation
    difference.to_i.abs.times do
      i = self.quantity - 1
      if i == -1
        if self.parent.class == Item
          #puts "Updating parent #{self.parent.name} qty";
          before = self.parent.quantity
          #puts "Before #{before}"
          self.parent.update_attribute :quantity, before - 1 # recursion
          after = self.parent.quantity
          #puts "After #{after}"
          parent_reducable = before != after
          write_attribute(:quantity, self.parent.packaging_unit - 1) if parent_reducable
        else
          b = write_attribute :quantity, 0
        end
      else
        c = write_attribute :quantity, i
      end
    end
  end
  def to_record
    attrs = self.attributes.clone
    attrs[:category] = self.category.name if self.category
    attrs[:location] = self.location.name if self.location
    attrs[:tax_profile] = self.tax_profile.name if self.tax_profile
    attrs[:parent_sku] = self.parent_sku if self.parent
    attrs[:child_sku] = self.child_sku if self.child
    attrs[:class] = self.class.to_s
    [ 
      :quantity, :quantity_sold,:created_at,
      :updated_at, :real_quantity,:quantity_buyback 
    ].each do |k|
      attrs.delete k
    end
    attrs
  end
  # {END}
end
