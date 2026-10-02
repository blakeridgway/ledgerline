class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  PER_PAGE = 25

  private
    def current_user
      Current.user
    end

    # Minimal offset pagination: sets @page / @total_pages / @total_count.
    def paginate(scope)
      total = scope.count
      total_pages = [ (total.to_f / PER_PAGE).ceil, 1 ].max
      page = params[:page].to_i
      page = 1 if page < 1
      page = total_pages if page > total_pages

      @page = page
      @total_pages = total_pages
      @total_count = total

      scope.limit(PER_PAGE).offset((page - 1) * PER_PAGE)
    end

    def parse_date(value)
      Date.parse(value.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # Redirects to a same-origin path supplied by the form, else to the fallback.
    def redirect_after_write(fallback, notice)
      target = params[:return_to].to_s
      target = fallback unless target.start_with?("/") && !target.start_with?("//")
      redirect_to target, notice: notice
    end
end
