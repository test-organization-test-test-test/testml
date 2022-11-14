view: lsc_metadata_suggestions {
  derived_table: {
    # persist_for: "24 hours"
    sql: SELECT DISTINCT label_group,
                         label,
                         chapter,
                         season,
                         media_group
         FROM `rbmh-mit-pemobi-prod.99_metadata_v1.general_metadata_v1` ;;
  }

  dimension: label_group {type: string}
  dimension: label {type: string}
  dimension: chapter {type: string}
  dimension: season {type: string}
  dimension: media_group {type: string}
}
