view: iml_mapping_suggestions {
  derived_table: {
    # persist_for: "24 hours"
    sql: SELECT DISTINCT project_group_id,
                         project_season_id,
                         project_single_stop_id,
                         project_group_title,
                         project_season_title,
                         project_single_stop_title,
                         project_status
         FROM `rbmh-mit-pemobi-prod.99_mapping_v1.iml_mapping_v1` ;;
  }

  dimension: project_group_id {type: string}
  dimension: project_season_id {type: string}
  dimension: project_single_stop_id {type: string}
  dimension: project_group_title {type: string}
  dimension: project_season_title {type: string}
  dimension: project_single_stop_title {type: string}
  dimension: project_status {type: string}

}
