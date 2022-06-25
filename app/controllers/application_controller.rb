# frozen_string_literal: true

# Since this app has no models, I've coded the `display` action directly in the
# application controller.
class ApplicationController < ActionController::Base
  require 'json'
  require 'open-uri'
  GEOCODING_URL = 'https://api.mapbox.com/geocoding/v5/mapbox.places/'
  LIMIT = 6
  PLACE_TYPE = 'postcode'

  # Generates a JSON object whose keys are instances of `PLACE_TYPE` (e.g.,
  # particular postcodes, or particular regions, etc.) and whose values are
  # an array of `CATEGORY` instances (e.g., particular museums, or particular
  # restaurants, etc.) that are located in the given place type. A maximum of
  # `LIMIT` category instances are included.
  def generate_json
    # If path is 'museums', category will be 'museum'
    category = params[:category].singularize
    parsed_response = JSON.parse(call_geocoding_api(category))
    result = group_by_place_type(
      parsed_response['features'], PLACE_TYPE, category, LIMIT
    )
    render json: result
  end

  private

  # Fetches and reads data pertaining to the requested category from the MapBox
  # Geocoding API.
  def call_geocoding_api(category)
    proximity = "proximity=#{params[:lng]},#{params[:lat]}"
    access_token = "access_token=#{ENV['MAPBOX_TOKEN']}"
    # Get as many results as possible for now, will be filtered down to `LIMIT`
    # by `group_by_place_type`
    query_string = "types=poi&limit=10&#{proximity}&#{access_token}"
    URI.parse("#{GEOCODING_URL}#{category}.json?#{query_string}").open.read
  end

  # Given an array of POI feature objects and a place type, creates a hash which
  # groups the POIs by the place type (e.g., by postcode, or by region, or
  # by neighborhood, etc.).
  def group_by_place_type(pois, place_type, category, limit)
    empty_hash = Hash.new { |hash, key| hash[key] = [] }
    n = 0
    pois.each_with_object(empty_hash) do |poi, result|
      return result if n >= limit
      next unless in_category?(poi, category)

      postcode = find_place(poi, place_type)
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

  # Given a POI and a place type, finds the POI's value for that particular
  # place type. For example, if `place_type` is "postcode", it will find the
  # POI's postcode.
  def find_place(poi, place_type)
    # TODO: This throws an error if the POI is located in an area that lacks a
    # value for `place_type`. For example, if the POI is in an area that doesn't
    # have a postcode, then this will throw if `place_type == "postcode"`.
    poi['context'].find do |place|
      extract_place_type(place['id']) == place_type
    end['text']
  end

  # In a response from MapBox's Geocoding API, a feature has an ID of the form
  # `<place_type>.<number>`. This method extracts the place type.
  def extract_place_type(place_id)
    place_id.split('.').first
  end
end
