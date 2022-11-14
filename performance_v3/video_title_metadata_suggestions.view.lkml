view: video_title_metadata_suggestions {
  derived_table: {
    # persist_for: "24 hours"
    sql: SELECT DISTINCT video_title,
                         video_full_title,
                         managed_post_title
         FROM `rbmh-mit-pemobi-prod.99_metadata_v1.general_metadata_v1` ;;
  }

  dimension: video_title {type: string}
  dimension: video_full_title {type: string}
  dimension: managed_post_title {type: string}

}
