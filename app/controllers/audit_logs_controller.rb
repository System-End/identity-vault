# frozen_string_literal: true

class AuditLogsController < ApplicationController
  def index
    id = current_identity.id

    verification_ids = Array(current_identity.verifications.pluck(:id)) rescue []
    document_ids = Array(current_identity.documents.pluck(:id)) rescue []
    breakglass_ids = if document_ids.any?
      Array(BreakGlassRecord.where(break_glassable_type: "Identity::Document", break_glassable_id: document_ids).pluck(:id))
    else
      []
    end

    verification_ids = [ -1 ] if verification_ids.empty?
    breakglass_ids = [ -1 ] if breakglass_ids.empty?

    sql_condition = <<~SQL.squish
      (
        (recipient_id = :id AND recipient_type = :itype) OR
        (owner_id = :id AND owner_type = :itype) OR
        (trackable_type = 'Identity' AND trackable_id = :id) OR
        (trackable_type = 'Verification' AND trackable_id IN (:verification_ids)) OR
        (trackable_type = 'BreakGlassRecord' AND trackable_id IN (:breakglass_ids))
      )
    SQL

    @activities = PublicActivity::Activity
      .where(sql_condition, id: id, itype: "Identity", verification_ids: verification_ids, breakglass_ids: breakglass_ids)
      .where.not(trackable_type: "Program")
      .where.not("key LIKE ?", "program.%")
      .includes(:owner, :trackable)
      .order(created_at: :desc)
      .page(params[:page])
      .per(50)

    render layout: (request.headers["HX-Request"] ? "htmx" : "application")
  end
end
