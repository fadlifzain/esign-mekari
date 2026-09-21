module Sign
  class BaseController < ApplicationController
    before_action :set_workspace

    private

    def set_workspace
      @workspace_id = params[:workspace_id]
    end
  end
end
