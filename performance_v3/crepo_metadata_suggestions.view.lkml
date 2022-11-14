view: crepo_metadata_suggestions {
  derived_table: {
    # persist_for: "24 hours"
    sql: SELECT DISTINCT content_language_locale,
                         language,
                         content_type,
                         creator_locale
         FROM `rbmh-mit-pemobi-prod.99_metadata_v1.crepo_editorial_metadata_v1` ;;
  }

  dimension: content_language_locale {type: string}
  dimension: language {type: string}
  dimension: content_type {type: string}
  dimension: creator_locale {type: string}

}
