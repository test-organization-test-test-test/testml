view: playground_mapping_suggestions {
  derived_table: {
    # persist_for: "24 hours"
    sql: SELECT DISTINCT sap_playground_key,
                         option_value_path,
                         sap_playground_key_path,
                         playground_category,
                         playground,
                         playground_type,
                         playground_discipline
         FROM `rbmh-mit-pemobi-prod.99_mapping_v1.playground_mapping_v2` ;;
  }

  dimension: sap_playground_key {type: string}
  dimension: option_value_path {type: string}
  dimension: sap_playground_key_path {type: string}
  dimension: playground_category {type: string}
  dimension: playground {type: string}
  dimension: playground_type {type: string}
  dimension: playground_discipline {type: string}

}
