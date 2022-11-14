view: metadata_suggestions {
  derived_table: {
    # persist_for: "24 hours"
    sql: SELECT DISTINCT hostname_account,
                         hostname,
                         author_country,
                         source_content_type,
                         page_type,
                         platform_split,
                         sub_platform,
                         media_type,
                         message_type,
                         site_type,
                         website_categories,
                         event_initiative,
                         people_partners,
                         macro_categories
         FROM `rbmh-mit-pemobi-prod.99_metadata_v1.general_metadata_v1` ;;
  }

  dimension: hostname_account {type: string}
  dimension: hostname {type: string}
  dimension: author_country {type: string}
  dimension: source_content_type {type: string}
  dimension: page_type {type: string}
  # dimension: platform {type: string}
  # dimension: platform_overall {type: string}
  dimension: platform_split {type: string}
  dimension: sub_platform {type: string}
  dimension: media_type {type: string}
  dimension: message_type {type: string}
  dimension: site_type {type: string}
  dimension: website_categories {type: string}
  dimension: event_initiative {type: string}
  dimension: people_partners {type: string}
  dimension: macro_categories {type: string}

}
