view: device_mapping_suggestions {
  derived_table: {
    # persist_for: "24 hours"
    sql: SELECT DISTINCT device,
                         device_category,
                         platform_reporting_category
         FROM `rbmh-mit-pemobi-prod.99_mapping_v1.device_mapping_v1` ;;
  }

  dimension: device {type: string}
  dimension: device_category {type: string}
  dimension: platform_reporting_category {type: string}

}
