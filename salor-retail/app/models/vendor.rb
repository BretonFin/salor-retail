# coding: UTF-8

# Salor -- The innovative Point Of Sales Software for your Retail Store
# Copyright (C) 2012-2013  Red (E) Tools LTD
# 
# See license.txt for the license applying to all files within this software.

class Vendor < ActiveRecord::Base
 # {START}
	include SalorScope
  include SalorModel
	belongs_to :user
	has_one :salor_configuration
	has_many :orders
	has_many :categories
	has_many :items
	has_many :locations
	has_many :employees
	has_many :cash_registers
	has_many :customers
	has_many :broken_items
	has_many :paylife_structs
	has_many :nodes
	has_many :shipments_received, :as => :receiver
	has_many :returns_sent, :as => :shipper
	has_many :shipments
	has_many :vendor_printers
  has_many :shippers, :through => :user
	has_many :discounts
	has_many :stock_locations
	has_many :shipment_items, :through => :shipments
  has_many :tax_profiles
  has_many :shipment_types
	
  
	def salor_configuration_attributes=(hash)
	  if self.salor_configuration.nil? then
	    self.salor_configuration = SalorConfiguration.new hash
	    self.salor_configuration.save
	    return
	  end
	  self.salor_configuration.update_attributes(hash)
	end
  def set_vendor_printers=(printers)
    self.connection.execute("delete from vendor_printers where vendor_id = '#{self.id}'")
    ps = []
    printers.each do |printer|
      p = VendorPrinter.new(printer)
      p.vendor_id = self.id
      p.save
      ps << p.id
    end
    self.vendor_printer_ids = ps
  end
  def open_cash_drawer
    cash_register_id = $User.meta.cash_register_id
    vendor_id = self.id
    if cash_register_id and vendor_id
      text = Printr.new.sane_template("drawer_transaction",binding)
      Printr.new.direct_write($Register.thermal_printer,text)
    end
  end

  def receipt_logo_header=(data)
    write_attribute :receipt_logo_header, Escper::Image.new(data.read, :blob).to_s 
  end

  def receipt_logo_footer=(data)
    write_attribute :receipt_logo_footer, Escper::Image.new(data.read, :blob).to_s 
  end

  def logo=(data)
    write_attribute :logo_image_content_type, data.content_type.chomp
    write_attribute :logo_image, data.read
  end

  def logo_invoice=(data)
    write_attribute :logo_invoice_image_content_type, data.content_type.chomp
    write_attribute :logo_invoice_image, data.read
  end
  def get_stats
    # this method shows what features are being used, and how often.
    features = Hash.new
    features[:actions] = true if Action.scopied.count > 0
    features[:coupons] = true if OrderItem.scopied.where('coupon_amount > 0').count > 0
    features[:discounts] = true if Discount.by_vendor.all_seeing.count > 0
    features[:item_level_rebates] = true if OrderItem.scopied.where('rebate > 0').count > 0
      if features[:item_level_rebates] == true then
        features[:item_level_rebates_count] = OrderItem.scopied.where('rebate IS NOT NULL AND rebate != 0.0').count
      end
    features[:order_level_rebates] = true if Order.scopied.where('rebate > 0').count > 0
    if features[:order_level_rebates] == true then
      features[:order_level_rebates_count] = Order.scopied.where('rebate IS NOT NULL AND rebate != 0.0').count
    end
    @features = features
  end
  # {END}
end