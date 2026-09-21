module Sign
  class BaseController < ApplicationController
    before_action :set_workspace

    private

    def set_workspace
      Current.identity = SignConfig::IDENTITY
      Current.workspace_id = SignConfig::WORKSPACE_ID
      @workspace_id = params[:workspace_id]
    end
  end
end
