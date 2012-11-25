class CountriesController < ApplicationController
  
  def testing
    puts "i am a test"
  end
  def index
    @countries = Country.scopied(@current_employee)
  end
  
  def new
    @country = Country.new
  end
  
  def create
    @country = Country.new(params[:country])
    @country.set_model_owner
    if @country.save
      redirect_to countries_path
    else
      render :new
    end
  end
  
  def update
    @country = Country.scopied(@current_employee).find_by_id(params[:id])
    if @country.update_attributes(params[:country])
      redirect_to countries_path
    else
      render :new
    end
  end
  
  def edit
    @country = Country.scopied(@current_employee).find_by_id(params[:id])
    redirect_to countries_path and return unless @country
    render :new
  end
  
  def destroy
    @country = Country.scopied(@current_employee).find_by_id(params[:id])
    redirect_to countries_path and return unless @country
    @country.update_attribute :hidden, true
    redirect_to countries_path
  end
  before_filter :initialize_instance_variables,:authify,:crumble
  private
  def crumble
    add_breadcrumb @current_vendor.name,'vendor_path(@current_vendor)'
    add_breadcrumb I18n.t("activerecord.models.country.other"),'countries_path(:vendor_id => params[:vendor_id])'
  end
end
