module Api
  class BaseController < ApplicationController
    skip_before_action :ensure_browser_support, raise: false
    before_action :set_demo_identity

    private

    def set_demo_identity
      Current.identity = SignConfig::IDENTITY
      Current.workspace_id = SignConfig::WORKSPACE_ID
    end

    def render_result(result)
      if result.ok?
        render json: result.value, status: result.http_status
      else
        render json: { error: result.error }, status: result.http_status
      end
    end

    def parsed_json_body
      JSON.parse(request.raw_post.presence || "null")
    rescue JSON::ParserError
      :invalid
    end
  end
end
