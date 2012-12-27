class Speech < Announcement
  include Edition::Appointment

  after_save :populate_organisations_based_on_role_appointment

  validates :speech_type_id, :delivered_on, presence: true

  validate :role_appointment_has_associated_organisation

  delegate :genus, :explanation, to: :speech_type

  tire.index_name 'whitehall_announcements'

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

  def to_indexed_json
    {
      state: state,
      timestamp_for_sorting: timestamp_for_sorting,
      delivered_on: delivered_on,
      first_published_at: first_published_at,
      organisations: organisations.map(&:id),
      people: [person.id],
      speech_type: speech_type.id,
      topics: topics.map(&:id),
      title: title,
      description: summary,
      content: indexable_content,
    }.to_json
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
