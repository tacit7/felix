defmodule RouteWiseApi.ErrorCodes do
  @moduledoc """
  Centralized error codes for consistent API error responses.
  """

  # Explore Results Controller Errors
  @place_not_found "PLACE_NOT_FOUND"
  @explore_results_error "EXPLORE_RESULTS_ERROR"
  @missing_parameter "MISSING_PARAMETER"
  @no_suggestions "NO_SUGGESTIONS"
  @disambiguation_error "DISAMBIGUATION_ERROR"

  # General API Errors
  @validation_error "VALIDATION_ERROR"
  @internal_server_error "INTERNAL_SERVER_ERROR"
  @authentication_error "AUTHENTICATION_ERROR"
  @authorization_error "AUTHORIZATION_ERROR"
  @not_found_error "NOT_FOUND"
  @bad_request_error "BAD_REQUEST"

  # Service Errors
  @cache_error "CACHE_ERROR"
  @database_error "DATABASE_ERROR"
  @external_api_error "EXTERNAL_API_ERROR"
  @rate_limit_error "RATE_LIMIT_ERROR"

  def place_not_found, do: @place_not_found
  def explore_results_error, do: @explore_results_error
  def missing_parameter, do: @missing_parameter
  def no_suggestions, do: @no_suggestions
  def disambiguation_error, do: @disambiguation_error

  def validation_error, do: @validation_error
  def internal_server_error, do: @internal_server_error
  def authentication_error, do: @authentication_error
  def authorization_error, do: @authorization_error
  def not_found_error, do: @not_found_error
  def bad_request_error, do: @bad_request_error

  def cache_error, do: @cache_error
  def database_error, do: @database_error
  def external_api_error, do: @external_api_error
  def rate_limit_error, do: @rate_limit_error
end