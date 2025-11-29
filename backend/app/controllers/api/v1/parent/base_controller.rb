module Api
  module V1
    module Parent
      class BaseController < ApplicationController
        skip_before_action :authenticate_request
        before_action :authenticate_parent

        private

        def authenticate_parent
          token = extract_token
          payload = JwtService.decode(token)

          if payload && payload[:parent_id]
            @current_parent = ::Parent.find_by(id: payload[:parent_id])
          end

          render json: { error: 'Unauthorized' }, status: :unauthorized unless @current_parent
        end

        def current_parent
          @current_parent
        end

        def extract_token
          header = request.headers['Authorization']
          header&.split(' ')&.last
        end
      end
    end
  end
end


