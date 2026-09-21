module Api
  class EnvelopesController < BaseController
    def create
      result = ::Envelopes::Create.new(file: params[:file], extra_keys: multipart_keys).call
      session[:envelope_id] = result.value[:envelope_id] if result.ok?
      render_result(result)
    end

    def charge_preview
      payload = parsed_json_body
      if payload == :invalid
        return render_result(::ServiceResult.error(code: "PAYLOAD_INVALID", message: "JSON body must be an object"))
      end

      render_result(
        ::Envelopes::ChargePreview.new(
          envelope_id: params[:id],
          payload: payload,
          workspace_id: Current.workspace_id
        ).call
      )
    end

    private

    def multipart_keys
      params.to_unsafe_h.keys.map(&:to_s) - %w[controller action]
    end
  end
end
