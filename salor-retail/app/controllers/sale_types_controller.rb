class SaleTypesController < ApplicationController
  
  def index
    @sale_types = SaleType.scopied(@current_employee)
  end
  
  def new
    @sale_type = SaleType.new
  end
  
  def create
    @sale_type = SaleType.new(params[:sale_type])
    @sale_type.set_model_owner
    if @sale_type.save
      redirect_to sale_types_path
    else
      render :new
    end
  end
  
  def update
    @sale_type = SaleType.find_by_id(params[:id])
    if @sale_type.update_attributes(params[:sale_type])
      redirect_to sale_types_path
    else
      render :new
    end
  end
  
  def edit
    @sale_type = SaleType.find_by_id(params[:id])
    redirect_to sales_types_path and return unless @sale_type
    render :new
  end
  
  def destroy
    @sale_type = SaleType.find_by_id(params[:id])
    redirect_to roles_path and return unless @sale_type
    @sale_type.update_attribute :hidden, true
    redirect_to sales_types_path
  end
  before_filter :initialize_instance_variables,:authify,:crumble
  private
  def crumble
    @vendor = @current_employee.get_vendor(@current_employee.meta.vendor_id)
    add_breadcrumb @vendor.name,'vendor_path(@vendor)'
    add_breadcrumb I18n.t("activerecord.models.invoice_note.other"),'invoice_notes_path(:vendor_id => params[:vendor_id])'
  end
end
