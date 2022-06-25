# frozen_string_literal: true

# Since this app has no models, I've coded the actions directly in the
# application controller.
class ApplicationController < ActionController::Base
  require 'json'
  require 'open-uri'
  LIMIT = 6
  PLACE_TYPE = 'postcode'

  def display
    mapbox_url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/'
    # If path is 'museums', category will be 'museum'
    category = params[:category].singularize
    proximity = "proximity=#{params[:lng]},#{params[:lat]}"
    access_token = "access_token=#{ENV['MAPBOX_TOKEN']}"
    # Get as many results as possible for now, will be filtered down to `LIMIT`
    # by `group_by_place_type`
    query_string = "type=poi&limit=10&#{proximity}&#{access_token}"
    uri = URI.parse("#{mapbox_url}#{category}.json?#{query_string}").open
    parsed_response = JSON.parse(uri.read)
    result = group_by_place_type(
      parsed_response['features'], PLACE_TYPE, category, LIMIT
    )
    render json: result
  end

  private

  # Given an array of POI feature objects and a place type, creates a hash which
  # groups the POIs by the place type (e.g., by postcode, or by region, or
  # by neighborhood, etc.).
  def group_by_place_type(poi, place_type, category, limit)
    empty_hash = Hash.new { |hash, key| hash[key] = [] }
    n = 0
    poi.each_with_object(empty_hash) do |poi, result|
      return result if n >= limit
      next unless in_category?(poi, category)

      postcode = find_place(place_type, poi['context'])
      result[postcode] << poi['text']
      n += 1
    end
  end

  # Ensures that the POI really belongs to the specified category. (For
  # instance, if we were searching for museums, we wouldn't want a restaurant
  # called "The Museum Café" to be included in the results.)
  def in_category?(poi, category)
    categories = poi['properties']['category'].split(', ')
    categories.include?(category)
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
