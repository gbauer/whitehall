class Speech < Announcement
  include Edition::Appointment

  tire.index_name 'whitehall_announcements'

  mapping do
    indexes :id,                    index: :not_analyzed
    indexes :title,                 analyzer: 'snowball', boost: 10
    indexes :summary,               analyzer: 'snowball', boost: 5
    indexes :indexable_content,     analyzer: 'snowball'
    indexes :state,                 analyzer: 'keyword'
    indexes :timestamp_for_sorting, type: 'date'
    indexes :first_published_at,    type: 'date'
    indexes :organisations,         type: 'string', 
                                    analyzer: 'keyword', 
                                    as: 'organisations.map(&:id)'
    indexes :topics,                type: 'string', 
                                    analyzer: 'keyword', 
                                    as: 'topics.map(&:id)'
    indexes :people,                type: 'string',
                                    analyzer: 'keyword',
                                    as: '[role_appointment.person_id]'
    indexes :delivered_on,          type: 'date'
    indexes :speech_type,           type: 'integer',
                                    as: 'speech_type.id'

  end

  after_save :populate_organisations_based_on_role_appointment

  validates :speech_type_id, :delivered_on, presence: true

  validate :role_appointment_has_associated_organisation

  delegate :genus, :explanation, to: :speech_type

  def speech_type
    SpeechType.find_by_id(speech_type_id)
  end

  def speech_type=(speech_type)
    self.speech_type_id = speech_type && speech_type.id
  end

  def display_type
    if [SpeechType::WrittenStatement, SpeechType::OralStatement].include?(speech_type)
      "Statement to parliament"
    else
      super
    end
  end

  def delivery_title
    role_appointment.role.ministerial? ? "Minister" : "Speaker"
  end

  private

  def skip_organisation_validation?
    true
  end

  def populate_organisations_based_on_role_appointment
    unless deleted?
      self.edition_organisations = []
      self.organisations = []
      organisations_via_role_appointment.each { |o| self.organisations << o }
    end
  end

  def organisations_via_role_appointment
    role_appointment && role_appointment.role && role_appointment.role.organisations || []
  end

  def set_timestamp_for_sorting
    self.timestamp_for_sorting = delivered_on
  end

  def role_appointment_has_associated_organisation
    unless organisations_via_role_appointment.any?
      errors.add(:role_appointment, "must have an associated organisation")
    end
  end
end
