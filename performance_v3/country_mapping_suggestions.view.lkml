view: country_mapping_suggestions {
  derived_table: {
    # persist_for: "24 hours"
    sql: SELECT DISTINCT TRIM(country_iso2) as country_iso2,
                         performance_country,
                         hc_region,
                         hc_region_text,
                         mpct,
                         rb_country
         FROM `rbmh-mit-pemobi-prod.99_mapping_v1.country_mapping_main_v1` ;;
  }

  dimension: country_iso2 {type: string}
  dimension: performance_country {type: string}
  dimension: hc_region {type: string}
  dimension: hc_region_text {type: string}
  dimension: mpct {type: string}
  dimension: rb_country {type: string}

}
