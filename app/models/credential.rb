# frozen_string_literal: true

class Credential < ApplicationRecord
  # Which password manager or security key made a passkey, by the AAGUID it reports
  PROVIDERS = YAML.load_file(Rails.root.join("config/passkey_providers.yml")).freeze

  # Associations
  belongs_to :user

  # A passkey only works on the domain it was made on
  attribute :rp_id, default: -> { WebAuthn.configuration.rp_id }

  # Validations
  validates :external_id, :public_key, :nickname, :sign_count, :rp_id, presence: true
  validates :external_id, uniqueness: true
  validates :sign_count,
    numericality: {only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: (2**32) - 1}

  # Scopes
  scope :on_this_domain, -> { where(rp_id: WebAuthn.configuration.rp_id) }

  # Named after the password manager when we know it, otherwise the browser it was made in
  def self.nickname_for(aaguid, user_agent)
    PROVIDERS[aaguid] || WebPushNotification.describe_device(user_agent) || "Passkey"
  end
end
