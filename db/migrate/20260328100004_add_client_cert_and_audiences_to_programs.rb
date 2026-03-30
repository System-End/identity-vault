# frozen_string_literal: true

class AddClientCertAndAudiencesToPrograms < ActiveRecord::Migration[8.0]
  def change
    add_column :oauth_applications, :client_cert_fingerprint, :string
    add_column :oauth_applications, :allowed_audiences, :jsonb, default: []

    add_index :oauth_applications, :client_cert_fingerprint, unique: true,
              where: "client_cert_fingerprint IS NOT NULL"
  end
end
