# frozen_string_literal: true

# Since this app has no models, I've coded the actions directly in the
# application controller.
class ApplicationController < ActionController::Base
  require 'json'
  require 'open-uri'

  def display
    mapbox_url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/'
    # If path is 'museums', category will be 'museum'
    category = params[:category].singularize
    proximity = "proximity=#{params[:lng]},#{params[:lat]}"
    access_token = "access_token=#{ENV['MAPBOX_TOKEN']}"
    # Get six results
    query_string = "type=poi&limit=6&#{proximity}&#{access_token}"
    uri = URI.parse("#{mapbox_url}#{category}.json?#{query_string}").open
    parsed_response = JSON.parse(uri.read)
    result = group_by_place_type(parsed_response['features'], 'postcode')
    render json: result
  end

  private

  # Given an array of feature objects and a place type, creates a hash which
  # groups the features by the place type (e.g., by postcode, or by region, or
  # by neighborhood, etc.).
  def group_by_place_type(features, place_type)
    result = Hash.new { |hash, key| hash[key] = [] }
    features.each_with_object(result) do |feature, result|
      postcode = find_place(place_type, feature['context'])
      result[postcode] << feature['text']
    end
  end

  # Given a context and a place type, finds the context's value for that
  # particular place type. For example, if `place_type` is "postcode", it will
  # find the context's postcode.
  def find_place(place_type, context)
    context.find do |place|
      extract_place_type(place['id']) == place_type
    end['text']
  end

  def extract_place_type(place_id)
    place_id.split('.').first
  end
end
