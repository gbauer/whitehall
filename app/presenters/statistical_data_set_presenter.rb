class StatisticalDataSetPresenter < Draper::Base
  include EditionPresenterHelper

  decorates :statistical_data_set

  def display_date_attribute_name
    :published_at
  end
end