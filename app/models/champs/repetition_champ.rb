class Champs::RepetitionChamp < Champ
  accepts_nested_attributes_for :champs, allow_destroy: true

  def rows
    champs.group_by(&:row).values
  end

  def add_row(row = 0)
    type_de_champ.types_de_champ.each do |type_de_champ|
      self.champs << type_de_champ.champ.build(row: row)
    end
  end

  def mandatory_and_blank?
    mandatory? && champs.empty?
  end

  def search_terms
    # The user cannot enter any information here so it doesn’t make much sense to search
  end

  def for_tag
    ([libelle] + rows.map do |champs|
      champs.map do |champ|
        "#{champ.libelle} : #{champ}"
      end.join("\n")
    end).join("\n\n")
  end

  def rows_for_export
    rows.each.with_index(1).map do |champs, index|
      Champs::RepetitionChamp::Row.new(index: index, dossier_id: dossier_id.to_s, champs: champs)
    end
  end

  class Row < Hashie::Dash
    property :index
    property :dossier_id
    property :champs

    def read_attribute_for_serialization(attribute)
      self[attribute]
    end

    def spreadsheet_columns
      [
        ['Dossier ID', :dossier_id],
        ['Ligne', :index]
      ] + exported_champs
    end

    private

    def exported_champs
      champs.reject(&:exclude_from_export?).map do |champ|
        [champ.libelle, champ.for_export]
      end
    end
  end
end
