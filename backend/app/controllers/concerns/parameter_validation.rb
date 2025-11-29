module ParameterValidation
  extend ActiveSupport::Concern

  included do
    before_action :validate_content_type
  end

  private

  def validate_content_type
    return unless request.post? || request.put? || request.patch?
    return if request.content_type&.include?('application/json')
    return if request.content_type&.include?('multipart/form-data')

    render json: { error: 'Invalid content type' }, status: :unsupported_media_type
  end

  def validate_required_params(*keys)
    missing = keys.select { |k| params[k].blank? }
    return if missing.empty?

    render json: { error: "Missing required parameters: #{missing.join(', ')}" }, status: :bad_request
  end

  def sanitize_params(param_key, schema)
    return {} unless params[param_key]

    schema.each_with_object({}) do |(key, type), result|
      value = params[param_key][key]
      next if value.nil?

      result[key] = case type
      when :string then InputSanitizer.sanitize_string(value)
      when :integer then InputSanitizer.sanitize_integer(value)
      when :email then InputSanitizer.sanitize_email(value)
      when :html then InputSanitizer.sanitize_html(value)
      when Array then InputSanitizer.sanitize_array(value, allowed_values: type)
      else value
      end
    end
  end
end


