view: general_performance {
   derived_table: {
    sql:  SELECT
            *
          FROM `rbmh-mit-pemobi-prod.99_performance_v1.general_performance_v3` source_1
          WHERE view_date >= '2019-01-01'
          ;;
  }
  label: "RBMH Performance"


#---- Technical

 dimension: prim_key {    #  used for aggregate, if neede. currently disabled
    type: number
    primary_key: yes
    sql: ${TABLE}.bi_uuid ;;
    hidden: yes
 }

  parameter: force_exact_count {
    label: "Activate exact Count for all data"
    default_value: "no"
    type: string
    allowed_value: {
      label: "yes"
      value: "yes"
    }
    hidden: yes
  }


# -------------------- Date and Time Filter ----------------------------

  filter: date_filter {
    type:  date
    convert_tz: no
    #sql:  cast(${TABLE}.view_date as timestamp) >= {% date_start date_filter %} and cast(${TABLE}.view_date as timestamp) < coalesce({% date_end date_filter %}, current_timestamp())  ;;
    #sql:  cast(${TABLE}.view_date as timestamp)  ;;  was used for the dimension previously
    sql: {% condition date_filter %} cast(${TABLE}.view_date as timestamp) {% endcondition %} ;;
    hidden: no
  }

  dimension: start_date { # used for measures/dimensions filtered on calendar date
    type: date
    convert_tz: no
    sql: {% date_start date_filter %};;
    hidden: yes
  }

  dimension: end_date {
    type: date
    convert_tz: no
    sql: DATE_SUB ({% date_end date_filter %}, INTERVAL 1 DAY);;
    hidden: yes
  }

#------------ Period over Period ----------------
  filter: current_date_range {
    type: date
    view_label: "PoP"
    label: "Current Date Range"
    description: "Select the current date range you are interested in. Make sure any other filter on Event Date covers this period, or is removed."
    sql: ${period} IS NOT NULL ;;
    hidden: yes
  }

  parameter: pop {
    view_label: "PoP"
    label: "Period"
    description: "Select the templated previous period you would like to compare to. Must be used with Date Filter"
    type: unquoted
    allowed_value: {
      label: "Previous Period"
      value: "Period"
    }
    allowed_value: {
      label: "Previous Week"
      value: "Week"
    }
    allowed_value: {
      label: "Previous Month"
      value: "Month"
    }
    allowed_value: {
      label: "Previous Year"
      value: "Year"
    }
    default_value: "Period"
    hidden: yes
  }


  dimension: days_in_period {
    hidden:  yes
    view_label: "PoP"
    description: "Gives the number of days in the current period date range"
    type: number
    sql: DATE_DIFF(DATE({% date_end current_date_range %}), DATE({% date_start current_date_range %}), DAY) ;;
  }

  dimension: period_2_start {
    hidden:  yes
    view_label: "PoP"
    description: "Calculates the start of the previous period"
    type: date
    sql:
      {% if pop._parameter_value == "Period" %}
      DATE_SUB(DATE({% date_start current_date_range %}), INTERVAL ${days_in_period} DAY)
      {% else %}
      DATE_SUB(DATE({% date_start current_date_range %}), INTERVAL 1 {% parameter pop %})
      {% endif %};;
  }

  dimension: period_2_end {
    hidden:  yes
    view_label: "PoP"
    description: "Calculates the end of the previous period"
    type: date
    sql:
      {% if pop._parameter_value == "Period" %}
      DATE_SUB(DATE({% date_start current_date_range %}), INTERVAL 1 DAY)
      {% else %}
      DATE_SUB(DATE_SUB(DATE({% date_end current_date_range %}), INTERVAL 1 DAY), INTERVAL 1 {% parameter pop %})
      {% endif %};;
  }

  dimension: day_in_period {
    hidden: yes
    description: "Gives the number of days since the start of each period. Use this to align the event dates onto the same axis, the axes will read 1,2,3, etc."
    type: number
    sql:
      {% if current_date_range._is_filtered %}
          CASE
          WHEN {% condition current_date_range %} ${view_date_raw} {% endcondition %}
          THEN DATE_DIFF(${view_date_date}, DATE({% date_start current_date_range %}), DAY) + 1
          WHEN ${view_date_date} between ${period_2_start} and ${period_2_end}
          THEN DATE_DIFF(${view_date_date}, ${period_2_start}, DAY) + 1
          END
      {% else %} NULL
      {% endif %}
      ;;
  }

  dimension: order_for_period {
    hidden: yes
    type: number
    sql:
      {% if current_date_range._is_filtered %}
          CASE
          WHEN {% condition current_date_range %} ${view_date_raw} {% endcondition %}
          THEN 1
          WHEN ${view_date_date} between ${period_2_start} and ${period_2_end}
          THEN 2
          END
      {% else %}
          NULL
      {% endif %}
      ;;
  }

  dimension_group: date_in_period {
    description: "Use this as your grouping dimension when comparing periods. Aligns the previous periods onto the current period"
    label: "Current Period"
    type: time
    sql: CAST(DATE_ADD(DATE({% date_start current_date_range %}), INTERVAL (${day_in_period} - 1) DAY) as TIMESTAMP) ;;
    view_label: "PoP"
    timeframes: [
      raw,
      date,
      week,
      month,
      month_num,
      month_name,
      year]
    hidden: yes
  }


  dimension: period {
    view_label: "PoP"
    label: "Period"
    description: "Pivot me! Returns the period the metric covers, i.e. either the 'This Period' or 'Previous Period'"
    type: string
    order_by_field: order_for_period
    sql:
      {% if current_date_range._is_filtered %}
          CASE
          WHEN {% condition current_date_range %} ${view_date_raw} {% endcondition %}
          THEN 'This {% parameter pop %}'
          WHEN ${view_date_date} between ${period_2_start} and ${period_2_end}
          THEN 'Last {% parameter pop %}'
          END
      {% else %}
          NULL
      {% endif %}
      ;;
      hidden: yes
  }

  dimension: period_filtered_measures {
    hidden: yes
    description: "We just use this for the filtered measures"
    type: string
    sql:
      {% if current_date_range._is_filtered %}
          CASE
          WHEN {% condition current_date_range %} ${view_date_raw} {% endcondition %} THEN 'this'
          WHEN ${view_date_date} between ${period_2_start} and ${period_2_end} THEN 'last' END
      {% else %} NULL {% endif %} ;;
  }


#------------  JOINS  -------------

  dimension: accountmetadata_key {
    type: number
    sql: ${TABLE}.accountmetadata_key ;;
    value_format: "0"
    hidden: yes
    view_label: "Keys"
  }

  dimension: pageaccountmetadata_key {
    type: number
    hidden: yes
    sql: ${TABLE}.pageaccountmetadata_key ;;
    value_format: "0"
    view_label: "Keys"
  }

  dimension: metadata_key {
    type: number
    sql: ${TABLE}.metadata_key;;
    value_format: "0"
    hidden: yes
    view_label: "Keys"
  }

  dimension: device_id {
    type: string
    sql: ${TABLE}.device_id ;;
    hidden: yes
    view_label: "Keys"
  }

  dimension: performance_country_iso2 {
    type: string
    sql: TRIM(${TABLE}.performance_country_iso2) ;;
    hidden: yes
    view_label: "Keys"
    suggest_explore: country_mapping_suggestions
    suggest_dimension: country_mapping_suggestions.country_iso2
  }

  dimension: pagemetadata_key {
    type: string
    sql: ${TABLE}.pagemetadata_key ;;
    hidden: yes
    view_label: "Keys"
  }

  dimension: module_tracking_key {
    type: string
    sql: ${TABLE}.module_tracking_key ;;
    hidden: yes
    view_label: "Keys"
  }

  dimension: iml_id {
    type: string
    sql: ${TABLE}.iml_id;;
    hidden: yes
    view_label: "Keys"
  }

  dimension: asset_playground_id {
    type: string
    hidden: yes
    sql: ${TABLE}.asset_playground_id ;;
    view_label: "Keys"
  }

  dimension: crepo_videometadata_key {
    type: number
    hidden: yes
    sql: ${TABLE}.crepo_videometadata_key ;;
    view_label: "Keys"
  }

  dimension: videometadata_key {
    type: number
    hidden: yes
    sql: ${TABLE}.videometadata_key ;;
    value_format: "0"
    view_label: "Keys"
  }


  dimension: editorialmetadata_key {
    type: number
    hidden: yes
    sql: ${TABLE}.editorialmetadata_key ;;
    value_format: "0"
    view_label: "Keys"
  }


  dimension: project_playground_id {
    type: string
    hidden: yes
    sql: ${TABLE}.project_playground_id ;;
    view_label: "Keys"
  }

  dimension: lcmmetadata_key {
    type: string
    sql: ${TABLE}.lcmmetadata_key ;;
    hidden: yes
    value_format: "0"
    view_label: "Keys"
  }





#---------------   TIME ------------------

  dimension_group: view_date {
    type: time
    timeframes: [
      raw,
      date,
      week,
      month,
      month_num,
      quarter,
      year,
    ]
    sql: CAST(${TABLE}.view_date AS TIMESTAMP) ;;
    label: "Trend"
    group_label: "[Time Dimensions]"
    description: "Date of the performance CET. [ZPE000516]"
  }

  dimension_group: view_time {
    type: time
    timeframes: [
      raw,
      minute,
      second,
      hour
    ]
    sql: CAST(${TABLE}.view_time AS TIMESTAMP) ;;
    label: "Trend"
    group_label: "[Time Dimensions]"
    description: "Date and time of performance CET. [ZPE000430]"
  }

  dimension_group: view_date_name {
    label: ""  # empty to keep the label clean
    type: time
    timeframes: [
      day_of_week
    ]
    sql: CAST(${TABLE}.view_date AS TIMESTAMP) ;;
    group_label: "[Time Dimensions]"
    description: "Derived from View Date [ZPE000516]"
  }

  dimension_group: view_time_name {
    label: ""  # empty to keep the label clean
    type: time
    timeframes: [
    hour_of_day
    ]
    sql: CAST(${TABLE}.view_time AS TIMESTAMP) ;;
    group_label: "[Time Dimensions]"
    description: "Date and time of performance CET. [ZPE000430]"
  }

# --------------- Text Filter ------------------------

  filter: search_filter_videos {
    label: "Search Filter for Videos"
    type: string
    sql: {% condition %} ${general_performance.harmonized_video_id} {% endcondition %} OR
         {% condition %} ${general_performance.video_full_title} {% endcondition %} OR
         {% condition %} ${general_performance.platform_video_title} {% endcondition %} OR
         {% condition %} ${general_performance.project_group_title} {% endcondition %} OR
         {% condition %} ${general_performance.project_single_stop_title} {% endcondition %} OR
         {% condition %} ${general_performance.post_url} {% endcondition %} ;;
  #  group_label: "[Admin]"
    hidden: no
    case_sensitive: no
  }

  filter: search_filter_pages {
    label: "Search Filter for Pages"
    type: string
    sql: {% condition %} ${general_performance.page_url} {% endcondition %} OR
         {% condition %} ${general_performance.page_title} {% endcondition %} OR
         {% condition %} ${general_performance.page_name_url} {% endcondition %} OR
         {% condition %} ${general_performance.crepo_master_id_page} {% endcondition %} OR
         {% condition %} ${general_performance.author} {% endcondition %} ;;
   # group_label: "[Admin]"
    hidden: no
    case_sensitive: no
  }




# --------------- Borb -----------------------------

  parameter: disable_linear_parsing {         # parameter needed for linear parsing filter in genreal performance
    default_value: "no"
    type: string
    allowed_value: {
      label: "yes"
      value: "yes"
    }
    allowed_value: {
      label: "no"
      value: "no"
    }
  }

  dimension: borb_video_id {
    type: string
    sql: ${TABLE}.borb_video_id;;
    label: "Borb ID"
    group_label: "Admin"
    description: "ZPE000448"
    hidden: yes
    view_label: "General Metadata"
  }

  dimension: linear_stream_type {
    type: string
    sql:
          {% if disable_linear_parsing._parameter_value == "'yes'" %}
          ${TABLE}.linear_stream_type_unparsed
          {% else %}
          ${TABLE}.linear_stream_type
          {% endif %} ;;
    label: "Linear Stream Type"
    group_label: "[Video Dimensions]"
    description: "Traffic Split from the Linear-Borb stream [ZPE000062]"
    view_label: "General Metadata"
    suggest_persist_for: "12 hours"
  }

  #------------  VIDEO VIEWS--------------

  dimension: video_play_id_tec {             # dimension needed to switch between borb and not borb
    label: "Video Play ID"
    group_label: "Admin"
    type:  number
    sql:    {% if general_performance.disable_linear_parsing._parameter_value == "'yes'" %}
          ${TABLE}.video_play_id_excl_borb
          {% else %}
          ${TABLE}.video_play_id
          {% endif %} ;;
    hidden: yes
  }

  measure: views_owned_exact {
    type:  count_distinct
    allow_approximate_optimization: no
    sql: ${video_play_id_tec}  ;;
    hidden: yes
  }

  measure: views_owned_approximate {
    type:  count_distinct
    allow_approximate_optimization: yes
    sql: ${video_play_id_tec} ;;
    hidden: yes
  }

  measure: views_owned {    # correct video metric to switch borb on owned - needed for calculation
    label: "Video Views Owned"
    group_label: "[Framework Metrics]"
    type:  number
    sql: {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${views_owned_exact} {% else %} ${views_owned_approximate} {% endif %};;
    value_format: "#,##0"
    description: "Indication of a video start. [MHAI000005]"
    hidden: yes
  }

  dimension: managed_views_dimension {
    type: number
    sql: ${TABLE}.views ;;
    hidden: yes
  }

  measure: views_managed {               # needed for calculation
    label: "Views Managed"
    group_label: "[Managed Metrics]"
    type:  sum
    sql:${managed_views_dimension};;
    value_format: "#,##0"
    description: "Managed Views [MHAI000006]"
    hidden: yes
  }

  measure: video_views {
    label: "Views"
    group_label: "[Framework Metrics]"
    type: number
    sql: ${views_managed} +  ${views_owned} ;;
    value_format: "#,##0"
    description: "Indication of a video start. [MHAI000004]"
  }

  measure: total_calculated_video_views {               # used for avg time watched calculation
    label: "Total Calculated Views"
    group_label: "[Framework Metrics]"
    type:  number
    sql: ${views_owned} + ${calculated_views} ;;
    value_format: "#,##0"
    description: "The total views generated for platforms with a watchtime, including the video starts from Facebook under 3 seconds. Total time watched / avg time watched to retrieve overall video starts including the ones under 3 seconds (Facebook) [MHAI000227]"
  }

  dimension: video_views_facebook_dimension{
    label: "Video Views Owned Facebook"
    type: number
    sql: ${TABLE}.video_views_facebook_dimension;;
    hidden: yes
  }

  measure: video_views_facebook {
    label: "Video Views Facebook"
    type: sum
    sql: ${video_views_facebook_dimension} ;;
    hidden: yes
  }

  measure: video_views_owned_facebook {
    label: "Views Owned and Facebook"
    type: number
    sql: ${video_views_facebook} + ${views_owned} ;;
    hidden: yes
  }

  dimension: views_10s_managed_dimension {
    type: number
    sql: ${TABLE}.views_10s ;;
    hidden: yes
  }

  measure: views_10s_managed {     # used for calculation
    label: "Facebook 10s Views"
    type: sum
    sql:  ${views_10s_managed_dimension} ;;
    value_format: "#,##0.00"
    group_label: "[MHAI000031]"
    hidden: yes
  }

  dimension: views_30s_managed_dimension {
    sql: ${TABLE}.views_30s ;;
    hidden: yes
  }

  measure: views_30s_managed {
    label: "Facebook 30s Views"
    type: sum
    sql:${views_30s_managed_dimension} ;;
    value_format: "#,##0.00"
    group_label: "[MHAI000034]"
    hidden: yes
  }

  dimension: video_10_second_view_id_dimension {
    sql: IF (${TABLE}.video_10_second_view = 1 , ${video_play_id_tec}, Null);;
    hidden: yes
  }

  measure: views_10s_owned_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${video_10_second_view_id_dimension} ;;
    hidden: yes
  }

  measure: views_10s_owned_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${video_10_second_view_id_dimension} ;;
    hidden: yes
  }

  measure: views_10s_owned {
    label: "Owned 10s Views"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${views_10s_owned_exact} {% else %} ${views_10s_owned_approximate} {% endif %} ;;
    value_format: "#,##0.00"
    group_label: "[MHAI000031]"
    hidden: yes
  }


  measure: video_10_second_view {
    label: "10s Views"
    type: number
    sql: ${views_10s_owned} + ${views_10s_managed} ;;
    group_label: "[Video Metrics]"
    description: "Video Views that lasted longer than 10sec [MHAI000032]"
    hidden: no
  }

  dimension: video_30_second_view_id_dimension {
    type: string
    sql: IF (${TABLE}.video_10_second_view = 1 , ${video_play_id_tec}, Null);;
    hidden: yes
  }

  measure: views_30s_owned_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${video_30_second_view_id_dimension} ;;
    hidden: yes
  }

  measure: views_30s_owned_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${video_30_second_view_id_dimension} ;;
    hidden: yes
  }

  measure: views_30s_owned {
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${views_30s_owned_exact} {% else %} ${views_30s_owned_approximate} {% endif %} ;;
    hidden: yes
  }

  measure: video_30_second_view {
    label: "30s Views"
    type: number
    sql:  ${views_30s_owned} + ${views_30s_managed} ;;
    group_label: "[Video Metrics]"
    description: "Video Views that lasted longer than 30sec [MHAI000036]"
    hidden: no
  }

  measure: conversion_10sec_view {
    label: "Conversions to 10s Views"
    type: number
    value_format: "0.00"
    sql: IF (${video_views_owned_facebook} =0,0, ${video_10_second_view}/${video_views_owned_facebook} );;
    group_label: "[Video Metrics]"
    description: "Percentage of views that lasted at least 10 seconds. Owned and Facebook [MHAI000054]"
  }


  measure: conversion_30sec_view {
    label: "Conversions to 30s Views"
    type: number
    value_format: "0.00"
    sql:  IF (${video_views_owned_facebook} =0,0, ${video_30_second_view}/${video_views_owned_facebook} ) ;;
    group_label: "[Video Metrics]"
    description: "Percentage of views that lasted at least 30 seconds. Owned and Facebook [MHAI000055]"
  }

  measure: conversion_1030sec_view {
    label: "Conversions from 10s Views to 30s Views"
    type: number
    value_format: "0.00"
    sql: IF (${video_10_second_view} =0,0, ${video_30_second_view}/${video_10_second_view} );;
    group_label: "[Video Metrics]"
    description: "Percentage of views that lasted 10seconds and reached also 30seconds watchtime for Owned and Facebook. [MHAI000121]"
  }

  # ------------------ video metrics owned --------------

  dimension: video_60_second_view_dimension {
    type: string
    sql: IF (${TABLE}.video_60_second_view = 1 , ${video_play_id_tec}  , Null);;
    hidden: yes
  }

  measure: video_60_second_view_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${video_60_second_view_dimension} ;;
    hidden: yes
  }

  measure: video_60_second_view_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${video_60_second_view_dimension} ;;
    hidden: yes
  }

  measure: video_60_second_view {
    label: "60s Views"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${video_60_second_view_exact} {% else %} ${video_60_second_view_approximate} {% endif %} ;;
    group_label: "[Video Metrics]"
    description: "Video Views that lasted longer than 60sec [MHAI000038]"
    hidden: no
  }


  measure: conversion_60sec_view {
    label: "Conversions to 60s Views"
    type: number
    value_format: "0.00"
    sql: IF (${views_owned} =0,0, ${video_60_second_view}/${views_owned} ) ;;
    group_label: "[Video Metrics]"
    description: "Percentage of views that lasted at least 60 seconds. Owned only [MHAI000056]"
    hidden: no
  }

  measure: conversion_1060sec_view  {
    label: "Conversions from 10s Views to 60s Views"
    type: number
    value_format: "0.00"
    sql: IF (${views_10s_owned} = 0,0, ${video_60_second_view}/ ${views_10s_owned}) ;;
    group_label: "[Video Metrics]"
    description: "Percentage of views that lasted 10seconds and reached also 60seconds watchtime. Owned only [MHAI000052]"
    hidden: no
  }

  measure: conversion_3060sec_view  {
    label: "Conversions from 30s Views to 60s Views"
    type: number
    value_format: "0.00"
    sql: IF (${views_30s_owned} = 0,0, ${video_60_second_view}/${views_30s_owned}) ;;
    group_label: "[Video Metrics]"
    description: "Percentage of views that lasted 30seconds and reached also 60seconds watchtime. Owned only [MHAI000053]"
    hidden: no
  }

  dimension: subtitle_language_video_view_id_dimension {
    type: string
    sql: ${TABLE}.subtitle_language_video_view_id;;
    hidden: yes
  }

  measure: subtitle_language_video_views_exact {
    allow_approximate_optimization: no
    type: count_distinct
    sql: ${subtitle_language_video_view_id_dimension};;
    hidden: yes
  }

  measure: subtitle_language_video_views_approximate {
    allow_approximate_optimization: yes
    type: count_distinct
    sql: ${subtitle_language_video_view_id_dimension};;
    hidden: yes
  }

  measure: subtitle_language_video_views {
    label: "Video Subtitle Language Views"
    group_label: "[Owned Metrics]"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${subtitle_language_video_views_exact} {% else %} ${subtitle_language_video_views_approximate} {% endif %} ;;
    description: "Number of unique views for each subtitle language of an asset [MHAI000067]"
    hidden: no
  }

  dimension: audio_language_video_view_id_dimension {
    type: string
    sql: ${TABLE}.audio_language_video_view_id;;
    hidden: yes
  }

  measure: audio_language_video_views_exact {
    allow_approximate_optimization: no
    type: count_distinct
    sql: ${audio_language_video_view_id_dimension};;
    hidden: yes
  }

  measure: audio_language_video_views_approximate {
    allow_approximate_optimization: yes
    type: count_distinct
    sql: ${audio_language_video_view_id_dimension};;
    hidden: yes
  }

  measure: audio_language_video_views {
    label: "Video Audio Language Views"
    group_label: "[Owned Metrics]"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${audio_language_video_views_exact} {% else %} ${audio_language_video_views_approximate} {% endif %};;
    description: "Sum of unique views for each language of an asset. If an asset has multiple audio stream versions available and a users switches between these, a view for each unique language will be counted [MHAI000066]"
    hidden: no
  }

  dimension: video_viewer_id_dimension {
    type: string
    sql: ${TABLE}.video_viewer_id;;
    hidden: yes
  }

  measure: video_viewers_exact {
    allow_approximate_optimization: no
    type:  count_distinct
    sql: ${video_viewer_id_dimension};;
    hidden: yes
  }

  measure: video_viewers_approximate {
    allow_approximate_optimization: yes
    type:  count_distinct
    sql: ${video_viewer_id_dimension};;
    hidden: yes
  }

  measure: video_viewers {
    label: "Viewers (DEPR)"
    group_label: "[Deprecated]"
    type:  number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${video_viewers_exact} {% else %} ${video_viewers_approximate} {% endif %};;
    description: "Viewers is a visitors (device/cookie) who started at least one video. [MHAI000002]"
    hidden: yes
  }



  measure: views_per_viewer {
    label: "Views per Viewer (DEPR)"
    group_label: "[Deprecated]"
    type:  number
    value_format: "#,##0.00"
    sql:IF (${video_viewers} =0,0, ${views_owned}/${video_viewers});;
    description: "Views per Viewer is the average number of times a unique viewer watched videos in a certain time period. [MHAI000016]"
    hidden: yes
  }

  dimension: video_10_second_viewer_id_dimension {
    type: string
    sql: IF (${TABLE}.video_10_second_view = 1 , ${TABLE}.video_viewer_id  , Null);;
    hidden: yes
  }

  measure: video_10_second_viewer_exact {
    allow_approximate_optimization: no
    type: count_distinct
    sql: ${video_10_second_viewer_id_dimension} ;;
    hidden: yes
  }

  measure: video_10_second_viewer_approximate {
    allow_approximate_optimization: yes
    type: count_distinct
    sql: ${video_10_second_viewer_id_dimension} ;;
    hidden: yes
  }

  measure: video_10_second_viewer {
    label: "10 Seconds Viewers (DEPR)"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${video_10_second_viewer_exact} {% else %} ${video_10_second_viewer_approximate} {% endif %}  ;;
    group_label: "[Deprecated]"
    description: "Viewers that watched a video for longer than 10sec [MHAI000029]"
    hidden: yes
  }

  dimension: video_30_second_viewer_id_dimension {
    type: string
    sql: IF (${TABLE}.video_30_second_view = 1 , ${TABLE}.video_viewer_id  , Null);;
    hidden: yes
  }

  measure: video_30_second_viewer_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${video_30_second_viewer_id_dimension} ;;
    hidden: yes
  }

  measure: video_30_second_viewer_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${video_30_second_viewer_id_dimension} ;;
    hidden: yes
  }

  measure: video_30_second_viewer {
    label: "30 Seconds Viewers (DEPR)"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${video_30_second_viewer_exact} {% else %} ${video_30_second_viewer_approximate} {% endif %};;
    group_label: "[Deprecated]"
    description: "Viewers that watched a video for longer than 30sec [MHAI000033]"
    hidden: yes
  }

  dimension: video_60_second_viewer_id_dimension {
    type: string
    sql: IF (${TABLE}.video_60_second_view = 1 , ${TABLE}.video_viewer_id  , Null);;
    hidden: yes
  }

  measure: video_60_second_viewer_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${video_60_second_viewer_id_dimension} ;;
    hidden: yes
  }

  measure: video_60_second_viewer_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${video_60_second_viewer_id_dimension} ;;
    hidden: yes
  }

  measure: video_60_second_viewer {
    label: "60 Seconds Viewers (DEPR)"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${video_60_second_viewer_exact} {% else %} ${video_60_second_viewer_approximate} {% endif %};;
    group_label: "[Deprecated]"
    description: "Viewers that watched a video for longer than 60sec [MHAI000037]"
    hidden: yes
  }

  dimension: number_owned_video_assets_platform_id_dimension {
    type: string
    sql: if(${video_play_id_tec}>0, ${general_performance.platform_video_id}, Null);;
    hidden: yes
  }

  measure: number_owned_video_assets_platform_exact {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${number_owned_video_assets_platform_id_dimension};;
    hidden: yes
  }

  measure: number_owned_video_assets_platform_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${number_owned_video_assets_platform_id_dimension};;
    hidden: yes
  }

  measure: number_owned_video_assets_platform {
    label: "# Video Assets (Platform Video ID)"
    type: number
    value_format: "#,##0"
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${number_owned_video_assets_platform_exact} {% else %} ${number_owned_video_assets_platform_approximate} {% endif %};;
    group_label: "[Video Metrics]"
    description: "Number of owned video assets that received traffic within the timeframe (based on platform video id). [MHAI000226]"
    hidden: yes
  }

  dimension: owned_video_assets_id_dimension {
    type: string
    sql: if(${video_play_id_tec}>0, ${general_performance.harmonized_video_id}, Null);;
    hidden: yes
  }

  measure: number_owned_video_assets_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${owned_video_assets_id_dimension};;
    hidden: yes
  }

  measure: number_owned_video_assets_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${owned_video_assets_id_dimension};;
    hidden: yes
  }

  measure: number_owned_video_assets {
    label: "# Video Assets"
    type: number
    value_format: "#,##0"
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${number_owned_video_assets_exact} {% else %} ${number_owned_video_assets_approximate} {% endif %};;
    group_label: "[Video Metrics]"
    description: "Number of Owned Video Assets that received traffic within the timeframe. [MHAI000075]"
    hidden: no
  }


  dimension: video_publishing_volume_dimension {
    type: string
    sql:  if( DATE (${general_performance.video_first_seen_raw}) = DATE (${view_date_raw}), ${general_performance.harmonized_video_id} , null) ;;
    hidden: yes
  }

  measure: video_publishing_volume_excat {
    type: count_distinct
    allow_approximate_optimization: no
    sql:  ${video_publishing_volume_dimension} ;;
    hidden: yes
  }

  measure: video_publishing_volume_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql:  ${video_publishing_volume_dimension} ;;
    hidden: yes
  }

  measure: video_publishing_volume {
    label: "Video Publishing Volume"
    type: number
    value_format: "#,##0"
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${video_publishing_volume_excat} {% else %} ${video_publishing_volume_approximate} {% endif %} ;;
    group_label: "[Video Metrics]"
    description: "Number of assets first seen within the reporting period [MHAI000076]"
  }



  #----------------  TIME WATCHED ---------------

  dimension: total_time_watched_dimension {
    type: number
    sql: ${TABLE}.total_time_watched;;
    hidden: yes
  }

  measure: total_time_watched {
    type: sum
    value_format: "#,##0"
    sql: ${total_time_watched_dimension} ;;
    hidden: yes
  }


  measure: total_time_watched_minutes {           # cross platform
    label: "Total Time Watched (min)"
    group_label: "[Framework Metrics]"
    type: number
    sql: ${total_time_watched}/60 ;;
    value_format: "#,##0.00"
    description: "Total time spent watching videos in minutes [MHAI000128]"
    hidden: no
  }

  measure: total_time_watched_seconds {             # cross platform
    label: "Total Time Watched (secs)"
    group_label: "[Framework Metrics]"
    type: number
    sql: 0 + ${total_time_watched} ;;
    value_format: "#,##0.00"
    description: "Total time spent watching videos in seconds [MHAI000022]"
    hidden: no
  }

  measure: avg_time_watched_per_view_seconds {                  # with calculated views
    label: "Avg. Time Watched per View (secs)"
    group_label: "[Framework Metrics]"
    type: number
    value_format: "#,##0.00"
    sql:IF (${total_calculated_video_views} =0,0, ${total_time_watched_seconds}/${total_calculated_video_views}) ;;
    description: "Average time watched per View is the average seconds watched once a video starts. For Facebook views under 3sec are included. [MHAI000163]"
    hidden: no
  }

  measure: avg_time_watched_per_view_minutes {          # with calculated views
    label: "Avg. Time Watched per View (min)"
    group_label: "[Framework Metrics]"
    type: number
    value_format: "#,##0.00"
    sql: IF (${total_calculated_video_views} =0,0, ${total_time_watched_minutes}/${total_calculated_video_views}) ;;
    description: "Average time watched per View is the average minutes watched once a video starts. For Facebook views under 3sec are included. [MHAI000019]"
    hidden:  no
  }


  dimension: engaged_time_owned_onsite_dimension {
    type: number
    sql:  Coalesce (IF (${general_performance.website_categories} in ('redbulltv-apps', 'servustv-app', 'servus-app'),
      ${total_time_watched_dimension},${total_time_spent_s_dimension}),0) ;;
    hidden: yes
  }

  dimension: engaged_time_owned_offsite_dimension {
    type: number
    sql: ${TABLE}.engaged_time_owned_offsite;;
    hidden: yes
  }

  dimension: engaged_time_managed_dimension {
    type: number
    sql:${TABLE}.engaged_time_managed;;
    hidden: yes
  }

  measure: engaged_time_owned_onsite {
    type: sum
    sql: ${engaged_time_owned_onsite_dimension} ;;
    hidden: yes
  }

  measure: engaged_time_owned_offsite {
    type: sum
    sql: ${engaged_time_owned_offsite_dimension} ;;
    hidden: yes
  }

  measure: engaged_time_managed {
    type: sum
    sql:${engaged_time_managed_dimension};;
    hidden: yes
  }

  measure: engaged_time_seconds {
    label: "Engaged Time (secs)"
    group_label: "[Framework Metrics]"
    type: number
    value_format: "#,##0.00"
    sql:  ${engaged_time_owned_onsite} + ${engaged_time_owned_offsite} + ${engaged_time_managed} ;;
    description: "The total time (in seconds) a user engaged with our content. Time spent on owned web on-site + watchtime on rbtv apps + time spent on games apps + embedded watchtime + managed watchtime (FB, YT). [MHAI000059]"
    hidden: no
  }

    measure: engaged_time_minutes  {
    label: "Engaged Time (min)"
    group_label: "[Framework Metrics]"
    type: number
    value_format: "#,##0.00"
    sql: ${engaged_time_seconds} / 60;;
    description: "The total time (in minutes) a user engaged with our content (depending on the data we can get from the platforms, derived from the performance of the videos, apps, or sites). [MHAI000058]"
    hidden: no
  }

  measure: engaged_time_per_visit_seconds {
    label: "Avg. Engaged Time per Visit (secs)"
    group_label: "[Framework Metrics]"
    type: number
    value_format: "#,##0.00"
    sql:IF( ${visits} = 0,0, (${engaged_time_owned_onsite} + ${engaged_time_owned_offsite})/${visits});;
    description: ""
    hidden: yes
  }

  measure: engaged_time_per_visit_minutes  {
    label: "Avg. Engaged Time per Visit (min)"
    group_label: "[Framework Metrics]"
    type: number
    value_format: "#,##0.00"
    sql: ${engaged_time_per_visit_seconds} / 60;;
    description: "Average Engaged Time per Visit is the average number of minutes users engage with assets e.g. pages or videos overall.[MHAI000334]"
    hidden: no
  }

  dimension: engaged_time_seconds_dimension { # old calculation
    type: number
    sql: Coalesce (IF (${general_performance.website_categories} in ('redbulltv-apps', 'servustv-app', 'servus-app'),
          ${total_time_watched_dimension},${total_time_spent_s_dimension}),0)
            + Coalesce (IF (${environment} ='off-site',${total_time_watched_dimension},0),0)
             + Coalesce (IF (${platform_overall} = 'Managed', ${total_time_watched_dimension},0),0) ;;
    hidden: yes
  }

  measure: engaged_time_seconds_old {
    label: "Engaged Time (secs) Old"
    group_label: "[Framework Metrics]"
    type: sum
    value_format: "#,##0.00"
    sql:  ${engaged_time_seconds_dimension} ;;
    description: "The total time (in seconds) a user engaged with our content (depending on the data we can get from the platforms, derived from the performance of the videos, apps, or sites). [MHAI000059]"
    hidden: yes
  }






# ------------------ Completion Rate -------------------

  measure: completion_rate_old {
    label: "Completion Rate % old"
    type:  number
    sql:
          IF (SUM (IF (coalesce (${general_performance.video_duration},0) > 0, coalesce ( ${TABLE}.total_time_watched,0),0)) = 0 ,0 ,
          SUM (IF (coalesce (${general_performance.video_duration},0) > 0, coalesce ( ${TABLE}.total_time_watched,0),0)) /
                SUM (IF (coalesce (${general_performance.video_duration},0) > 0,${general_performance.video_duration} *
                coalesce ( ${TABLE}.calculated_views,0) + coalesce ( ${TABLE}.owned_helper_views,0) * ${general_performance.video_duration}   ,0) ))   ;;
    value_format: "0.00%"
    group_label: "[Video Metrics]"
    description: "Measures how much of the total video duration on average a user completes. MHAI000096"
    hidden: yes
  }

  dimension: total_time_watched_w_duration_dimension {
    type: string
    sql: IF (coalesce (${general_performance.video_duration},0) > 0, coalesce ( ${TABLE}.total_time_watched,0),0) ;;
    hidden: yes
  }

  measure: total_time_watched_w_duration {
    type: sum
    sql: ${total_time_watched_w_duration_dimension} ;;
    hidden: yes
  }

  dimension: owned_helper_views_dimension {
    type: number
    sql: ${TABLE}.owned_helper_views;;
    hidden: yes
  }

  measure: owned_helper_views {
    type: sum
    sql: ${owned_helper_views_dimension} ;;
    hidden: yes
  }

  measure: max_watchtime_owned {
    type: sum
    sql: ${owned_helper_views_dimension} * ${general_performance.video_duration}  ;;
    hidden: yes
  }

  measure: max_watchtime_managed {
    type: sum
    sql:${general_performance.video_duration} *  ${calculated_views_dimension};;
    hidden: yes
  }

  measure: max_watchtime {
    type: number
    sql: ${max_watchtime_owned} + ${max_watchtime_managed} ;;
    hidden: yes
  }

  measure: completion_rate {
    label: "% Completion Rate"
    type: number
    #sql: IF (${total_time_watched_w_duration} = 0,0,${total_time_watched_w_duration} / ${max_watchtime});;
    sql: IF (${max_watchtime} = 0,0,${total_time_watched_w_duration} / ${max_watchtime});;
    value_format: "0.00%"
    group_label: "[Video Metrics]"
    description: "Measures how much of the total video duration on average a user completes. [MHAI000096]"
  }




#----------------  Per Capita Metrics ---------------


  measure: video_views_per_capita {
    label: "Views Per Capita"
    type: number
    value_format: "#,##0.0000000000"
    sql: ${video_views} / ${population};;
    group_label: "[Per Capita]"
    description: "It defines the # video views per the country population [MHAI000106]"
  }

  measure: total_time_watched_sec_per_capita {
    label: "Total Time Watched Per Capita (secs)"
    type: number
    value_format: "#,##0.0000000000"
    sql: ${total_time_watched_seconds} /  ${population} ;;
    group_label: "[Per Capita]"
    description: "It defines the # seconds watched per the country population [MHAI000231]"
  }

  measure: total_time_watched_min_per_capita {
    label: "Total Time Watched Per Capita (min)"
    type: number
    value_format: "#,##0.0000000000"
    sql: ${total_time_watched_minutes} /  ${population} ;;
    group_label: "[Per Capita]"
    description: "It defines the # minutes watched per the country population [MHAI000107]"
  }

  measure: visitors_per_capita {
    label: "Visitors Per Capita (DEPR)"
    type: number
    value_format: "#,##0.0000000000"
    sql: ${visitors} /  ${population} ;;
    group_label: "[Deprecated]"
    description: "It defines the owned penetration in term of visitors in a country [MHAI000109]"
    hidden: yes
  }


  measure: network_impressions_per_capita {
    label: "Network Impressions Per Capita"
    type: number
    value_format: "#,##0.0000000000"
    sql: ${impressions} /  ${population} ;;
    group_label: "[Per Capita]"
    description: "The calculation of Network Impressions (across Earned, Managed and Owned channels) divided by a country's population. [MHAI000230]"
  }

  #----------------  TIME WATCHED OWNED ---------------



# dimension: total_time_watched_owned_dimension {
#    type: number
#    sql: IF (${platform} = 'Owned', ${total_time_watched_dimension},0 ) ;;
#    hidden: yes
#  }

  dimension: total_time_watched_owned_dimension {
    type: number
    sql: ${TABLE}.total_time_watched_owned;;
    hidden: yes
  }

  measure: total_time_watched_owned {
    type: sum
    sql: ${total_time_watched_owned_dimension} ;;
    hidden: yes
  }

  measure: avg_time_watched_per_viewer_seconds {
    label: "Avg. Time Watched per Viewer (secs) (DEPR)"
    group_label: "[Deprecated]"
    type: number
    value_format: "#,##0.00"
    sql: IF (${video_viewers} =0,0,${total_time_watched_owned}   /${video_viewers});;
    description: "Average minutes spent watching a video by each unique viewer in a certain time period. [MHAI000046]"
    hidden: yes
  }

  measure: avg_time_watched_per_viewer_minutes {
    label: "Avg. Time Watched per Viewer (min) (DEPR)"
    group_label: "[Deprecated]"
    type: number
    value_format: "#,##0.00"
    sql: IF (${video_viewers} =0,0, (${total_time_watched_owned}/60)   /${video_viewers});;
    description: "Average minutes spent watching a video by each unique viewer in a certain time period.  [MHAI000018]"
    hidden: yes
  }

  dimension: time_watchted_10_views_sec_dimension {
    type: number
    sql: IF (${TABLE}.video_10_second_view = 1 , ${total_time_watched_dimension}  , Null) ;;
    hidden: yes
  }

  measure: time_watchted_10_views_sec {
    label: "Total Time Watched from 10s Views (secs)"
    type: sum
    value_format: "#,##0.00"
    sql: ${time_watchted_10_views_sec_dimension} ;;
    group_label: "[Video Metrics]"
    description: "Sum of time watched from views that lasted longer than 10seconds [MHAI000083]"
  }

  measure: time_watchted_10_views_min {
    label: "Total Time Watched from 10s Views (min)"
    type: number
    value_format: "#,##0.00"
    sql: ${time_watchted_10_views_sec}/60 ;;
    group_label: "[Video Metrics]"
    description: "Sum of time watched from views that lasted longer than 10seconds [MHAI000082]"
  }


  dimension: time_watchted_30_views_sec_dimension {
    type: number
    sql: IF (${TABLE}.video_30_second_view = 1 , ${total_time_watched_dimension}  , Null) ;;
    hidden: yes
  }

  measure: time_watchted_30_views_sec {
    label: "Total Time Watched from 30s Views (secs)"
    type: sum
    value_format: "#,##0.00"
    sql: ${time_watchted_30_views_sec_dimension} ;;
    group_label: "[Video Metrics]"
    description: "Sum of time watched from views that lasted longer than 30seconds [MHAI000085]"
  }

  measure: time_watchted_30_views_min {
    label: "Total Time Watched from 30s Views (min)"
    type: number
    value_format: "#,##0.00"
    sql: ${time_watchted_30_views_sec}/60 ;;
    group_label: "[Video Metrics]"
    description: "Sum of time watched from views that lasted longer than 30seconds [MHAI000084]"
  }

  dimension: time_watchted_60_views_sec_dimension {
    type: number
    sql: IF (${TABLE}.video_60_second_view = 1 , ${total_time_watched_dimension}  , Null) ;;
    hidden: yes
  }

  measure: time_watchted_60_views_sec {
    label: "Total Time Watched from 60s Views (secs)"
    type: sum
    value_format: "#,##0.00"
    sql: ${time_watchted_60_views_sec_dimension} ;;
    group_label: "[Video Metrics]"
    description: "Sum of time watched from views that lasted longer than 60seconds [MHAI000087]"
  }

  measure: time_watchted_60_views_min {
    label: "Total Time Watched from 60s Views (min)"
    type: number
    value_format: "#,##0.00"
    sql:  ${time_watchted_60_views_sec}/60 ;;
    group_label: "[Video Metrics]"
    description: "Sum of time watched from views that lasted longer than 60seconds [MHAI000086]"
  }

# ----------  Cross Platform Measures --------------

  dimension: impressions_owned_app_dimension {
    sql: IF ( ${general_performance.is_app} = 1 ,${video_play_id_tec} ,Null)  ;;
    hidden: yes
  }

  measure: impressions_owned_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${impressions_owned_app_dimension} ;;
    hidden: yes
  }

  measure: impressions_owned_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${impressions_owned_app_dimension} ;;
    hidden: yes
  }
  measure: impressions_owned_app {
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${impressions_owned_exact} {% else %} ${impressions_owned_approximate} {% endif %};;
    hidden: yes
  }


  dimension: impressions_owned_managed_dimension {  #should only be managed!
    type: number
    sql: ${TABLE}.impressions ;;
    hidden: yes
  }

  measure: impressions_owned_managed {
    type: sum
    sql: ${impressions_owned_managed_dimension} ;;
    hidden: yes
  }

  measure: impressions {
    label: "Impressions (EMO)"
    type: number
    value_format: "#,##0"
    sql:  ${impressions_owned_app} + ${impressions_owned_managed} + ${cumulated_impressions} + ${page_views};;
    group_label: "[Framework Metrics]"
    description: "Sum of Owned, Managed and Earned Impressions. [MHAI000012]"
  }



# ------------- Owned Measures --------------

  dimension: interactive_session_id {
    label: "interactive_session_id"
    group_label: "Admin"
    type: string
    sql: IF (${TABLE}.session_is_interactive = 1,${TABLE}.session_id, Null) ;;
    hidden: yes
  }

  measure: visits_exact {
    type:  count_distinct
    allow_approximate_optimization: no
    sql: ${interactive_session_id} ;;
    hidden: yes
  }

  measure: visits_approximate {
    type:  count_distinct
    allow_approximate_optimization: yes
    sql: ${interactive_session_id} ;;
    hidden: yes
  }

  measure: visits {
    label: "Visits"
    group_label: "[Owned Metrics]"
    type:  number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${visits_exact} {% else %} ${visits_approximate} {% endif %} ;;
    description: "A Visit (sessions) is a group of user interactions with your website that take place within a given timeframe. For example, a single session can contain multiple page views, events, views. Session is attributed to every hit in an interactive session. [MHAI000003]"
    hidden: no
  }

  dimension: session_id {
    label: "Session ID"
    group_label: "Admin"
    type: string
    sql: ${TABLE}.session_id ;;
    hidden: yes
  }

  dimension: full_visitor_id {
    label: "Full Visitor ID"
    sql: ${TABLE}.full_visitor_id ;;
    hidden: yes
  }

  measure: visitors_exact{
    type:  count_distinct
    allow_approximate_optimization: no
    sql: ${full_visitor_id} ;;
    hidden: yes
  }

  measure: visitors_approximate{
    type:  count_distinct
    allow_approximate_optimization: yes
    sql: ${full_visitor_id} ;;
    hidden: yes
  }

  measure: visitors {
    label: "Visitors (DEPR)"
    group_label: "[Deprecated]"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${visitors_exact} {% else %} ${visitors_approximate} {% endif %} ;;
    description: "Visitors is the number of a unique identifier associated with each user is send with each hit. This identifier can be a single, first-party cookie or a client ID. [MHAI000001]"
    hidden: yes
  }

  measure: visits_per_visitor {
    label: "Visits per Visitor (DEPR)"
    group_label: "[Deprecated]"
    type:  number
    value_format: "0.##"
    sql: IF(${visitors} =0,0, ${visits}/${visitors});;
    description: "Visits per Visitor is the average number of times a unique visitor returned in a certain time period. [MHAI000015]"
    hidden: yes
  }


  dimension: pageviews_dimension {
    type: number
    sql: ${TABLE}.pageviews ;;
    hidden: yes
  }

  measure: page_views {
    label: "Pageviews"
    group_label: "[Owned Metrics]"
    type: sum
    sql: ${pageviews_dimension} ;;
    description: "Total number of pages views. Repeated views of a single page are counted. [MHAI000077]"
    hidden: no
  }

  dimension: single_page_session_id {
    type: string
    sql: IF (${TABLE}.session_is_single_page_view = 1,${TABLE}.session_id, Null) ;;
    hidden: yes
  }

  measure: single_page_session_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${single_page_session_id} ;;
    hidden: yes
  }

  measure: single_page_session_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${single_page_session_id} ;;
    hidden: yes
  }

  measure: single_page_session {
    label: "Single Page Sessions"
    group_label: "[Owned Metrics]"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${single_page_session_exact} {% else %} ${single_page_session_approximate} {% endif %};;
    description: "Number of visits that contain 1 pageview only [MHAI000028]]"
    hidden: no
  }

  measure: share_single_page_session {
    label: "% Single Page Sessions"
    group_label: "[Owned Metrics]"
    type: number
    value_format: "#,##0.00"
    sql: IF (${visits} =0,0,${single_page_session}/${visits});;
    description: "% of visits that only contained one pageview [MHAI000027]"
    hidden: no
  }

  dimension: page_view_id_dimension {
    sql: ${TABLE}.page_view_id ;;
    hidden: yes
  }

  measure: unique_pageviews_exact {
    allow_approximate_optimization: no
    type: count_distinct
    sql: ${page_view_id_dimension};;
    hidden: yes
  }

  measure: unique_pageviews_approximate {
    allow_approximate_optimization: yes
    type: count_distinct
    sql: ${page_view_id_dimension};;
    hidden: yes
  }

  measure: unique_pageviews {
    label: "Unique Pageviews"
    group_label: "[Owned Metrics]"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${unique_pageviews_exact} {% else %} ${unique_pageviews_approximate} {% endif %} ;;
    description: "Deduplicated pageviews (at session level). If a user refreshes a page, it would be counted as 2 pageviews but only 1 unique pageview [MHAI000093]"
    hidden: no
  }

  dimension: hit_is_exit_hit_dimension {
    type: number
    sql: IF ( ${TABLE}.hit_is_exit_hit = 1 , 1, 0);;
    hidden: yes
  }

  measure: exits {
    label: "Exits"
    type: sum
    sql: ${hit_is_exit_hit_dimension} ;;
    group_label: "[Owned Metrics]"
    description: "Number of exits from a page or specified set of pages. [MHAI000026]"
    hidden: no
  }

  measure: share_exits {
    label: "% Exits"
    type: number
    value_format: "#,##0.00"
    sql: IF( ${visits} = 0,0 , ${exits}/${visits}) ;;
    group_label: "[Owned Metrics]"
    description: "% of exits on a page across all devices [MHAI000025]"
    hidden: no
  }

  dimension: total_time_spent_s_dimension {     # to be hidden
    type: number
    sql: ${TABLE}.total_time_spent_s;;
    hidden: yes
  }

  measure: total_time_spent_owned_seconds {
    label: "Total Time Spent (secs)"
    group_label: "[Owned Metrics]"
    type: sum
    sql: ${total_time_spent_s_dimension} ;;
    value_format: "#,##0.00"
    description: "Total time spent on owned platforms in seconds. [MHAI000124]"
    hidden: no
  }

  measure: total_time_spent_owned_minutes {
    label: "Total Time Spent (min)"
    group_label: "[Owned Metrics]"
    type: number
    sql: ${total_time_spent_owned_seconds}/60 ;;
    value_format: "#,##0.00"
    description: "Total time spent on owned platforms in minutes. [MHAI000080]"
    hidden: no
  }

  measure: time_spent_per_visit_seconds {
    label: "Avg. Time Spent per Visit (secs)"
    group_label: "[Owned Metrics]"
    type: number
    sql:IF( ${visits} = 0,0, ${total_time_spent_owned_seconds}/${visits});;
    value_format: "#,##0.00"
    description: "Average amount of time spent on any of our owned properties within a visit in seconds [MHAI000043]"
    hidden: no
  }


  measure: time_spent_per_visit_minutes {
    label: "Avg. Time Spent per Visit (min)"
    group_label: "[Owned Metrics]"
    type: number
    sql: IF (${visits} = 0,0, ( ${total_time_spent_owned_minutes})/${visits});;
    value_format: "#,##0.00"
    description: "Average amount of time spent on any of our owned properties within a visit in minutes [MHAI000042]"
    hidden: no
  }

  measure: time_spent_per_visitor_seconds {
    label: "Avg. Time Spent per Visitor (secs) (DEPR)"
    group_label: "[Deprecated]"
    type: number
    sql:IF( ${visitors} = 0,0, ${total_time_spent_owned_seconds}/${visitors});;
    value_format: "#,##0.00"
    description: "Average amount of time spent on any of our owned properties within a visitors cookie lifetime [MHAI000044]"
    hidden: yes
  }

  measure: time_spent_per_visitor_minutes {
    label: "Avg. Time Spent per Visitor (min) (DEPR)"
    group_label: "[Deprecated]"
    type: number
    sql: IF (${visitors} = 0,0, ( ${total_time_spent_owned_minutes})/${visitors});;
    value_format: "#,##0.00"
    description: "Average amount of time spent on any of our owned properties within a visitors cookie lifetime [MHAI000122]"
    hidden: yes
  }

  dimension: total_time_spent_pages_dimension {
    type: number
    sql: IF(${general_performance.is_app} = 1 , 0,  ${TABLE}.total_time_spent_s) ;;
    hidden: yes
  }

  measure: total_time_spent_owned_seconds_pages {     # needed for calulating the correntc time spent per page view
    type: sum
    sql: ${total_time_spent_pages_dimension} ;;
    hidden: yes
  }

  measure: time_spent_per_pageview_seconds {
    label: "Time Spent per Pageview (secs)"
    group_label: "[Owned Metrics]"
    type: number
    sql:IF( ${page_views} = 0,0, ${total_time_spent_owned_seconds_pages}/${page_views});;
    value_format: "#,##0.00"
    description: "The average number of seconds spent on a particular page. [MHAI000100]"
    hidden: no
  }

  measure: time_spent_per_pageview_minutes {
    label: "Time Spent per Pageview (min)"
    group_label: "[Owned Metrics]"
    type: number
    sql: IF( ${page_views} = 0,0, (${total_time_spent_owned_seconds_pages}/60)/${page_views});;
    value_format: "#,##0.00"
    description: "The average number of minutes spent on a particular page. [MHAI000101]"
    hidden: no
  }

  dimension: page_visits_id_dimension {
    type: string
    sql: IF(${general_performance.is_app} = 1, NULL , IF (${TABLE}.session_is_interactive = 1,${TABLE}.session_id, NULL)) ;;
    hidden: yes
  }

  measure: page_visits_exact {
    allow_approximate_optimization: no
    type: count_distinct
    sql: ${page_visits_id_dimension} ;;
    hidden: yes
  }

  measure: page_visits_approximate {
    allow_approximate_optimization: yes
    type: count_distinct
    sql: ${page_visits_id_dimension} ;;
    hidden: yes
  }

  measure: page_visits {      #  needed for calulating  avg pageviews per visit
    label: "Visits Pages"
    group_label: "[Owned Metrics]"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${page_visits_exact} {% else %} ${page_visits_approximate} {% endif %};;
    value_format: "#,##0.00"
    description: "Total time spent on Owned Platforms in seconds"
    hidden: yes
  }

  measure: pageview_per_visit {
    label: "Avg. Pageviews per Visit"
    group_label: "[Owned Metrics]"
    type: number
    sql: IF(${page_visits} = 0,0, ${page_views} /${page_visits});;
    value_format: "#,##0.00"
    description: "Average number of pages consumed within a visit [MHAI000040]"
    hidden: no
  }

  dimension: page_visitors_id_dimension {
    type: string
    sql: IF(${general_performance.is_app} = 1, NULL ,${TABLE}.full_visitor_id) ;;
    hidden: yes
  }

  measure: page_visitors_exact {     # only needed for calulating - sum of agg
    allow_approximate_optimization: no
    type: count_distinct
    sql: ${page_visitors_id_dimension};;
    hidden: yes
  }

  measure: page_visitors_approximate {      # only needed for calulating - sum of agg
    allow_approximate_optimization: yes
    type: count_distinct
    sql: ${page_visitors_id_dimension};;
    hidden: yes
  }

  measure: page_visitors {     # only needed for calulating - sum of agg
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${page_visitors_exact} {% else %} ${page_visitors_approximate} {% endif %};;
    hidden: yes
  }

  measure: pageview_per_visitor {
    label: "Avg. Pageviews per Visitor (DEPR)"
    group_label: "[Deprecated]"
    type: number
    sql: IF(${page_visitors} = 0,0, ${page_views} /${page_visitors});;
    value_format: "#,##0.00"
    description: "Average number of pages consumed within the lifetime of the visitor cookie [MHAI000041]"
    hidden: yes
  }


  dimension: thirty_seconds_on_page_dimension {
    type: string
    sql: ${TABLE}.thirty_seconds_on_page ;;
    hidden: yes
  }

  measure: page30s_events {
    label: "30s on Page"
    group_label: "[Owned Metrics]"
    type: sum
    sql: ${thirty_seconds_on_page_dimension} ;;
    description: "Sum of 30 seconds timing events of a page [MHAI000097]"
    hidden: no
  }

  dimension: sixty_seconds_on_page_dimension {
    type: string
    sql: ${TABLE}.sixty_seconds_on_page ;;
    hidden: yes
  }

  measure: page60s_events {    # missing in table
    label: "60s on Page"
    group_label: "[Owned Metrics]"
    type: sum
    sql: ${sixty_seconds_on_page_dimension} ;;
    description: "Sum of 60 seconds timing events of a page [MHAI000098]"
    hidden: no
  }


# ------------------------   Live Event Owned ---------------------------------


  dimension_group: audience_curve_timestamp { # only needed for curve calculation - includes hittimestamps for all live assets for all time
    label: "Audience Curve Timestamp"
    type: time
    timeframes: [
      raw,
      time,
      date
    ]
    sql: CAST (${TABLE}.audience_curve_timestamp as TIMESTAMP);;
    #sql: ${TABLE}.audience_curve_timestamp;;
    #sql: CAST (FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', ${TABLE}.audience_curve_timestamp, 'Europe/Berlin') as TIMESTAMP);;
    description: "Minute by minute live concurrents viewers. [ZPE000063]"
    hidden: yes
  }

  dimension: live_event_audience_curve {
    label: "Live Event Audience Curve"
    type:  date_time
    sql:CASE
          WHEN ${general_performance.audience_curve_timestamp_raw}  >= ${general_performance.livestream_start_raw}
          AND  ${general_performance.audience_curve_timestamp_raw} <= ${general_performance.livestream_end_raw}
          THEN ${general_performance.audience_curve_timestamp_raw}
          ELSE NULL END;;
    description: "Minute by minute live concurrents viewers. [ZPE000063]"
    group_label: "[Video Asset Metadata]"
    hidden: no
  }

  dimension: video_stream_type {
    label: "Video Stream Type"
    type: string
    sql:${TABLE}.video_stream_type;;
    group_label: "[Video Asset Metadata]"
    description: "Splits the performance of an asset, depending on whether it was streamed live or not. [ZPE000039]"
    hidden: no
    #suggest_persist_for: "12 hours"
    suggestions: ["After Live, before Replay","Live","Not A Live","Pre-Live Testing", "Replay" ]
  }

  dimension: concurrent_live_viewer_id_dimension {
    type: string
    sql: if(${live_event_audience_curve} is not NULL, ${TABLE}.video_viewer_id,NULL);;
    hidden: yes
  }

  measure: concurrent_live_viewers_exact {
    type:  count_distinct
    allow_approximate_optimization: no
    sql:  ${concurrent_live_viewer_id_dimension} ;;
    hidden: yes
  }

  measure: concurrent_live_viewers_approximate {
    type:  count_distinct
    allow_approximate_optimization: yes
    sql:  ${concurrent_live_viewer_id_dimension} ;;
    hidden: yes
  }

  measure: concurrent_live_viewers {
    label: "Live Concurrents"
    type:  number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${concurrent_live_viewers_exact} {% else %} ${concurrent_live_viewers_approximate} {% endif %} ;;
    group_label: "[Video Metrics]"
    description: "Number of Live Viewers at every minute for owned performance only. [MHAI000050]"
    hidden: no
  }



# ------------ Performance Dimensions ---------------


  dimension: is_paid_traffic {   # used for calculation
    type: number
    sql: ${TABLE}.is_paid_traffic ;;
    group_label: "Admin"
    hidden: yes
    description: "ZPE000395"
  }

  dimension: paid_organic {
    label: "Paid or Organic Split"
    type: string
    sql: CASE
          WHEN ${is_paid_traffic} = 1 THEN 'Paid'
          WHEN ${is_paid_traffic} = 0 THEN 'Organic'
          ELSE 'Split Unavailable'
      END;;
    group_label: "[Traffic Dimension]"
    description: "Separates the paid and organic performance, lists unknown performance if it cannot be defined. [ZPE000084]"
    suggestions: ["Paid","Organic","Split Unavailable"]
  }

  # ig paid adoption
  dimension: is_paid_account_data {   # used for calculation
    label: "Is IG Paid (0 or 1)"
    type: number
    sql: ${TABLE}.is_paid_account_data ;;
    group_label: "[Traffic Dimension]"
    hidden: yes
    description: "ZPE000574"
  }

  dimension: platform {
    label: "Platform (Owned Overall)"
    type: string
    sql: ${TABLE}.platform ;;
    group_label: "[Platform Categorization]"
    description: "Combination of Platforms in which Owned performance from Core Owned and Other Owned sources are combined into a single Platform name of 'Owned'. [ZPE000087]"
    hidden: no
    suggestions: ["Earned","Facebook","Instagram","Twitch","Twitter","YouTube","Owned", "TikTok"]
  }

  dimension: platform_overall {   # in ETL?
    label: "Platform (EMO)"
    type: string
    sql: ${TABLE}.platform_overall;;
    group_label: "[Platform Categorization]"
    description: "Highlevel grouping of owned and managed platforms [ZPE000089]"
    hidden: no
    suggestions: ["Earned","Managed","Owned"]
  }


# ------------ Dimensions Owned Performance ---------------


 dimension: total_playtime_owned  {
    label: "Total Playtime Per Video Play ID"
    type: number
    sql: ${TABLE}.total_playtime_s_per_video_play_id ;;
    group_label: "Admin"
    description: "[MHAI000199]"
    hidden: yes
  }

  dimension: watchtime_duration_categories {
    label: "Watchtime Duration Categories"
    type: string
    sql:
    CASE
    WHEN ${total_playtime_owned} >= 0 and ${total_playtime_owned} < 10
    THEN '01) < 10s'
    WHEN ${total_playtime_owned} >= 0 and ${total_playtime_owned} < 30
    THEN '02) < 30s'
    WHEN ${total_playtime_owned} >= 30 and ${total_playtime_owned} < 60
    THEN '03) 30s - 1min'
    WHEN ${total_playtime_owned} >= 60 and ${total_playtime_owned} < 180
    THEN '04) 1min - 3min'
    WHEN ${total_playtime_owned} >= 180 and ${total_playtime_owned} < 300
    THEN '05) 3min - 5min'
    WHEN ${total_playtime_owned} >= 300 and ${total_playtime_owned} < 600
    THEN '06) 5min - 10min'
    WHEN ${total_playtime_owned} >= 600 and ${total_playtime_owned} < 900
    THEN '07) 10min - 15min'
    WHEN ${total_playtime_owned} >= 900 and ${total_playtime_owned} < 1200
    THEN '08) 15min - 20min'
    WHEN ${total_playtime_owned} >= 1200 and ${total_playtime_owned} < 1800
    THEN '09) 20min - 30min'
    WHEN ${total_playtime_owned} >= 1800 and ${total_playtime_owned} < 3600
    THEN '10) 30min - 1h'
    WHEN ${total_playtime_owned} >= 3600 and ${total_playtime_owned} < 7200
    THEN '11) 1h - 2h'
    WHEN ${total_playtime_owned} >= 7200 and ${total_playtime_owned} < 10800
    THEN '12) 2h - 3h'
    WHEN ${total_playtime_owned} >= 10800
    THEN '13) > 3h'
    ELSE 'N/A'
    END;;
    group_label: "[Video Metrics]"
    description: "Allows to group videos based on the total time watched [ZPE000154]"
  }

  dimension: ab_test {
    label: "AB Test"
    type: string
    sql: ${TABLE}.ab_test;;
    group_label: "[Owned Dimensions]"
    description: "Name of the AB test [ZPE000001]"
  }

  dimension: ab_test_version {
    label: "AB Test Version"
    type: string
    sql: ${TABLE}.ab_test_version ;;
    group_label: "[Owned Dimensions]"
    description: "Comparison of two variations of a webpage, ad, design, module on one of our owned platforms [ZPE000002]"
  }

  dimension: app_version {
    label: "App Version"
    type: string
    sql: ${TABLE}.app_version;;
    group_label: "[User Dimensions]"
    description: "Version number of an app [ZPE000004]"
  }

  dimension: browser_name {
    label: "Browser Name"
    type: string
    sql:  ${TABLE}.browser_name;;
    group_label: "[User Dimensions]"
    description: "The browsers used by visitors to our website or app [ZPE000013]"
  }

  dimension: browser_version {
    label: "Browser Version (DEPR)"
    type: string
    sql:${TABLE}.browser_version;;
    group_label: "[Deprecated]"
    description: "The browser version used by visitors to our website or app [ZPE000014]"
    hidden: yes
  }

  dimension: build_version {
    label: "Build Version"
    type: string
    sql: ${TABLE}.build_version;;
    group_label: "[User Dimensions]"
    description: "Defines the build version of an app version [ZPE000015]"
  }

  dimension: geo_city {
    label: "Geo City (DEPR)"
    type: string
    sql: ${TABLE}.geo_city;;
    group_label: "[Deprecated]"
    description: "The city from which the session originated, based on the IP-Adresses as GA defines it [ZPE000019]"
    hidden: yes
  }

  dimension: device_advertising_id {
    label: "Device Advertising ID (DEPR)"
    type: string
    sql: ${TABLE}.device_advertising_id;;
    group_label: "[Deprecated]"
    description: "Indicates the unique identifier for device needed for advertising tracking [ZPE000032]"
    hidden: yes
  }

  dimension: video_account_name {
    label: "Video Account Name"
    type: string
    sql: ${TABLE}.video_account_name;;
    group_label: "[Video Asset Metadata]"
    description: "'Virtual' Video Account name to classify in which 'bigger' bucket the video belongs to [ZPE000357]"
  }

  dimension: video_display_domain {
    label: "Video Display Domain"
    type: string
    sql: ${TABLE}.video_display_domain;;
    group_label: "[Owned Dimensions]"
    description: "The domain of where the player was embedded. Can be different from the hostname as GA only captures it for our owned properties [ZPE000143]"
  }

  dimension: video_display_url {
    label: "Video Display URL"
    type: string
    sql: ${TABLE}.video_display_url;;
    group_label: "[Owned Dimensions]"
    description: "The URL of where the player was embedded. [ZPE000142]"
  }

  dimension: environment {
    label: "Environment"
    type: string
    sql: ${TABLE}.environment;;
    group_label: "[Owned Dimensions]"
    description: "Indicates whether the content was hosted on our own site, or via a third party platform such as Facebook Instant Articles or Google AMP. Default value: on-site [ZPE000036]"
  }

  dimension: is_onsite_traffic {
    label: "Is On-Site Traffic (yes/no)"
    type: string
    sql: ${TABLE}.is_onsite_traffic;;
    group_label: "[Owned Dimensions]"
    description: "Indicates whether the content was hosted on our own site, or via a third party platform. Based on the environment dimension from GA. [ZPE000053]"
  }

  dimension: video_autoplay {
    label: "Video Autoplay (yes/no)"
    type: string
    sql: ${TABLE}.video_autoplay;;
    group_label: "[Owned Dimensions]"
    description: "Indication of whether the video play was an autoplay or not [ZPE000138]"
  }

  dimension: logged_in_status {
    label: "Logged In Status (DEPR)"
    type: string
    sql:${TABLE}.logged_in_status;;
    group_label: "[Deprecated]"
    description: "Indicates if a visitor is logged in - Red Bull Account [ZPE000067]"
    hidden: yes
  }

  dimension: video_player_mode {
    label: "Video Player Mode"
    type: string
    sql: ${TABLE}.video_player_mode;;
    group_label: "[Owned Dimensions]"
    description: "State of the player (eg: fullscreen) [ZPE000092]"
  }

  dimension: type_of_stream {
    label: "Type of Stream"
    type: string
    sql: ${TABLE}.type_of_stream;;
    group_label: "[Video Asset Metadata]"
    description: "Dimension coming from GA on hit level which identifies if the stream was in live, linear or vod mode. [ZPE000150]"
    suggest_persist_for: "12 hours"
  }

  dimension: device_platform_subtype {
    label: "Device Platform Subtype"
    type: string
    sql: ${TABLE}.device_platform_subtype;;
    group_label: "[Owned Dimensions]"
    description: "Subtype of the device platform [ZPE000501]"
  }

  dimension: query_params {
    label: "Query Params"
    type: string
    sql: ${TABLE}.query_params;;
    group_label: "[Owned Dimensions]"
    description: "Query parameter that is added to the Url [ZPE000102]"
  }

  dimension: utm_campaign {
    label: "UTM Campaign"
    type: string
    sql:${TABLE}.utm_campaign;;
    group_label: "[Owned Dimensions]"
    description: "Used to define the overarching marketing campaign. Derived from the query string [ZPE000132]"
  }

  dimension: utm_content {
    label: "UTM Content"
    type: string
    sql: ${TABLE}.utm_content;;
    group_label: "[Owned Dimensions]"
    description: "Derived from the query string. Additional campaign keywords. [ZPE000133]"
  }

  dimension: utm_medium {
    label: "UTM Medium"
    type: string
    sql:  ${TABLE}.utm_medium;;
    group_label: "[Owned Dimensions]"
    description: "Used to undertand where the link was shared. Derived from the query string [ZPE000134]"
  }

  dimension: utm_source {
    label: "UTM Source"
    type: string
    sql: ${TABLE}.utm_source;;
    group_label: "[Owned Dimensions]"
    description: "Used to define the source of the campaign (Where is the message seen?). Derived from the query string [ZPE000135]"
  }

  dimension: utm_term {
    label: "UTM Term"
    type: string
    sql: ${TABLE}.utm_term;;
    group_label: "[Owned Dimensions]"
    description: "Used for analyzing paid keywords. [ZPE000355]"
  }

  dimension: rbcid {
    label: "RBCID"
    type: string
    sql:${TABLE}.rbcid;;
    group_label: "[Owned Dimensions]"
    description: "Unique campaign ID generated in RAMP NG that identifies and ties a campaign together in order to have a holistic view of RAMP NG and marketing performance data. [ZATRBCIDC]"
  }

  dimension: rbcom_source {
    label: "redbull.com Source"
    type: string
    sql: ${TABLE}.redbullcom_source;;
    group_label: "[Owned Dimensions]"
    description: "Site section on redbull.com, like theredbulletin, redbull.com, innovator [ZPE000106]"
  }

  dimension: player_page_position {
    label: "Player Page Position"
    type: string
    sql: ${TABLE}.player_page_position;;
    group_label: "[Owned Dimensions]"
    description: "Position of the video player on a redbull.com page. [ZPE000093]"
  }

  dimension: owned_channel {
    label: "Channel"
    type: string
    sql:${TABLE}.channel;;
    group_label: "[Owned Dimensions]"
    description: "RBTV Channel name (Content Vertical) [ZPE000016]"
  }

  dimension: search_term {
    label: "Search Term (DEPR)"
    type: string
    sql:${TABLE}.search_term;;
    group_label: "[Deprecated]"
    description: "Particular terms people are using as they search the website [ZPE000113]"
    hidden: yes
  }

  dimension: number_search_results {
    label: "# Search Results (DEPR)"
    type: string
    sql:${TABLE}.number_search_results;;
    group_label: "[Deprecated]"
    description: "The number of results returned for an internal site search [ZPE000076]"
    hidden: yes
  }

  dimension: referrer_domain {
    label: "Referrer Domain"
    type: string
    sql:${TABLE}.referrer_domain;;
    group_label: "[Owned Dimensions]"
    description: "Domain of the site the user comes from [ZPE000108]"
  }

  dimension: referrer_url {
    label: "Referrer URL"
    type: string
    sql: ${TABLE}.referrer_url;;
    group_label: "[Owned Dimensions]"
    description: "Full URL of where the user comes from [ZPE000109]"
  }

  dimension: referral_category {
    label: "Referral Category"
    type: string
    sql:${TABLE}.referral_category;;
    group_label: "[Owned Dimensions]"
    description: "A referral is reported when a user clicks through to your website from another third-party website. [ZPE000107]"
    suggest_persist_for: "12 hours"
  }

  dimension: traffic_source_category {
    label: "Traffic Source Category"
    type: string
    sql: ${TABLE}.traffic_source_category;;
    group_label: "[Owned Dimensions]"
    description: "Aggregation of referral categories for streamlined reporting. [ZPE000356]"
  }




#-------------- Story Editorial Metrics  -----------------------


  measure: count_asset_id_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql:  ${general_performance.asset_translation_link} ;;
    hidden: yes
  }

  measure: count_asset_id_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql:  ${general_performance.asset_translation_link} ;;
    hidden: yes
  }
  measure: count_asset_id {
    label: "Count of Asset IDs"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${count_asset_id_exact} {% else %} ${count_asset_id_approximate} {% endif %} ;;
    group_label: "[Owned Asset Reporting]"
    description: "Count of Asset Translation Links that received traffic in the selected period [MHAI000228]"
    hidden: no
  }

  dimension: asset_id_volume_dimension {
    type: string
    sql: IF (DATE (${general_performance.page_first_seen_raw}) = DATE (${view_date_raw}) ,  ${general_performance.asset_translation_link}, null)  ;;
    hidden: yes
  }

  measure: asset_id_volume_excat {
    type: count_distinct
    allow_approximate_optimization: no
    sql:  ${asset_id_volume_dimension} ;;
    hidden: yes
  }

  measure: asset_id_volume_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql:  ${asset_id_volume_dimension} ;;
    hidden: yes
  }

  measure: asset_id_volume {
    label: "Asset ID Publishing Volume"
    type: number
    value_format: "#,##0"
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${asset_id_volume_excat} {% else %} ${asset_id_volume_approximate} {% endif %} ;;
    group_label: "[Owned Asset Reporting]"
    description: "Count of Asset Translation Links that have been published in the selected period and have received traffic [MHAI000229]"
    hidden: no
  }

  dimension: master_id_volume_dimension {
    type: string
    sql: IF (DATE ( ${first_published}) = DATE (${view_date_raw}), ${crepo_master_id_page}, null)  ;;
    hidden: yes
  }

  measure: master_id_volume_excat {
    type: count_distinct
    allow_approximate_optimization: no
    sql:  ${master_id_volume_dimension} ;;
    hidden: yes
  }

  measure: master_id_volume_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql:  ${master_id_volume_dimension} ;;
    hidden: yes
  }

  measure: master_id_volume {
    label: "Master ID Publishing Volume"
    type: number
    value_format: "#,##0"
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${master_id_volume_excat} {% else %} ${master_id_volume_approximate} {% endif %} ;;
    group_label: "[Owned Asset Reporting]"
    description: "Count of Master IDs that were published in the selected period. [MHAI000078]"
    hidden: no
  }

  measure: count_master_id_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql:  ${crepo_master_id_page} ;;
    hidden: yes
  }

  measure: count_master_id_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql:  ${crepo_master_id_page} ;;
    hidden: yes
  }
  measure: count_master_id {
    label: "Count of Master IDs"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${count_master_id_exact} {% else %} ${count_master_id_approximate} {% endif %} ;;
    group_label: "[Owned Asset Reporting]"
    description: "Count of MasterIDs that received traffic in the selected period [MHAI000057]"
    hidden: no
  }


# ----------- Earned Measures and Dimensions -------------------------------

  measure: cumulated_impressions {
    type: sum_distinct
    label: "Cumulated Impressions"
    sql_distinct_key: ${general_performance.item_id};;
    sql: ${TABLE}.cumulated_impressions ;;
    value_format: "#,##0"
    group_label: "[Earned Metrics]"
    description: "Maximum number of impressions that could be generated through editorial, Red Bull-relevant coverage in print, TV and online media. [MHAI000010]"
  }

  measure: number_item_id_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${general_performance.item_id} ;;
    hidden: yes
  }

  measure: number_item_id_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${general_performance.item_id} ;;
    hidden: yes
  }

  measure: number_item_id {
    label: "# Items (E)"
    type: number
    sql:  0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${number_item_id_exact} {% else %} ${number_item_id_approximate} {% endif %} ;;
    group_label: "[Earned Metrics]"
    description: "Sum of the number of Red Bull relevant print articles, online news articles or TV broadcasts. [MHAI000013]"
    hidden: no
  }

  measure: number_media_outlets_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${general_performance.media_outlet_id} ;;
    hidden: yes
  }

  measure: number_media_outlets_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${general_performance.media_outlet_id} ;;
    hidden: yes
  }

  measure: number_media_outlets {
    label: "# Media Outlets (E)"
    type: number
    sql:  0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${number_media_outlets_exact} {% else %} ${number_media_outlets_approximate} {% endif %} ;;
    description: "Sum of the number of distinct newspapers, magazines, online news websites, TV channels, etc. that published at least one Red Bull relevant item. [MHAI000014]"
    group_label: "[Earned Metrics]"
    hidden: no
  }

  dimension: item_id {   # used for calculation
    label: "Item ID (E)"
    type: string
    sql: ${TABLE}.item_id ;;
    group_label: "[Earned Dimensions]"
    description: "Identifies the unique ID of the item in the Coverage Database. [ZPE000297]"
    hidden: yes
    view_label: "General Metadata"
  }

  # !!! still needed?
  dimension: item_playground_id_hidden {
    type: string
    sql: ${TABLE}.item_playground_id;;
    hidden:yes
    view_label: "General Metadata"
  }
  # !!! still needed?
  dimension: business_unit_classification_hidden {
    type: string
    sql: ${TABLE}.business_unit_classification;;
    hidden:yes
    view_label: "General Metadata"
  }



#------------  Managed Measures  ----------------------------

  dimension: calculated_views_dimension {
    label: "Calculated views"
    type: number
    sql: ${TABLE}.calculated_views ;;
    hidden: yes
  }

  measure: calculated_views {
    label: "Managed Calculated Views"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "Total time watched / avg time watched to retrieve overall video starts including the once under 3 seconds (Facebook); Backend calculation for weighted Avg Time Watched across platforms. [MHAI000079]"
    sql: ${calculated_views_dimension} ;;
    hidden: yes
  }

  dimension: comments_dimension {
    type: number
    sql: ${TABLE}.comments;;
    hidden: yes
  }

  measure: comments {
    label: "Comments"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "Number of comments on a managed asset. [MHAI000049]"
    sql: ${comments_dimension};;
    hidden: no
  }

  dimension: dislikes_dimension {
    type: number
    sql: ${TABLE}.dislikes ;;
    hidden: yes
  }

  measure: dislikes {
    label: "Dislikes"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "The number of dislikes a video has on YouTube. Part of the Social Engagements (shares, likes, comments, reactions). [MHAI000095]"
    sql: ${dislikes_dimension};;
    hidden: no
  }

  dimension: instagram_stories_impressions_dimension {
    type: number
    sql: ${TABLE}.instagram_stories_impressions ;;
    hidden: yes
  }

  measure: instagram_stories_impressions {
    label: "Instagram Stories Impressions"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "The total number of times our Instagram Story content has been seen. [MHAI000065]"
    sql: ${instagram_stories_impressions_dimension} ;;
    hidden: no
  }

  dimension: instagram_tap_backs_dimension {
    type: number
    sql: ${TABLE}.instagram_tap_backs ;;
    hidden: yes
  }

  measure: instagram_tap_backs {
    label: "Instagram Story Taps Back"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description:"The number of taps back on a Instagram Story. Part of the calculation for Instagram Story Engagements. [ZPE000405]"
    sql: ${instagram_tap_backs_dimension};;
    hidden: no
  }

  dimension: likes_dimension {
    type: number
    sql: ${TABLE}.likes ;;
    hidden: yes
  }

  dimension: saves_dimension {
    type: number
    sql: ${TABLE}.saves ;;
    hidden: yes
  }

  measure: saves {
    label: "Saves"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "It indicates the total number of unique accounts that have saved the media object (post). [MHAI000280]"
    sql: ${saves_dimension} ;;
    hidden: no
  }




  measure: likes {
    label: "Likes"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "The number of likes on a social post. Part of the Social Engagements (shares, likes, comments, reactions). [MHAI000068]"
    sql: ${likes_dimension} ;;
    hidden: no
  }

  dimension: link_clicks_dimension {
    type: number
    sql: ${TABLE}.link_clicks ;;
    hidden: yes
  }

  measure: link_clicks {
    label: "Link Clicks"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "The number of times a link within a managed post is clicked, taking the user to the url destination. [MHAI000099]"
    sql: ${link_clicks_dimension};;
    hidden: no
  }

  dimension: shares_dimension {
    type: number
    sql: ${TABLE}.shares ;;
    hidden: yes
  }

  measure: shares {
    label: "Shares"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "How many times a post was 'shared' by our audience. Part of the Engagements (shares, likes, comments, reactions). [MHAI000070]"
    sql: ${shares_dimension};;
    hidden: no
  }

  dimension: twitter_retweets_dimension {
    type: number
    sql: ${TABLE}.twitter_retweets ;;
    hidden: yes
  }

  measure: twitter_retweets {
    label: "Twitter Retweets"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "The volume of 'retweets' on Twitter. Part of the Engagements (shares, likes, comments, reactions). [MHAI000090]"
    sql: ${twitter_retweets_dimension} ;;
    hidden: no
  }

  dimension: managed_impressions_dimension {
    type: number
    sql: ${TABLE}.managed_impressions ;;
    hidden: yes
  }

  measure: managed_impressions {
    label: "Impressions (M)"
    type: sum
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "Impressions are the number of times a post from your page is displayed. People may see multiple impressions of the same post. For Twitter and Instagram, the impression number is an estimated number based on the number of followers at the post time. For YouTube and Twitch video views are considered as impressions. [MHAI000009]"
    sql: ${managed_impressions_dimension} ;;
    hidden: no
  }

  dimension: social_followers_dimension {
    type: number
    sql: ${TABLE}.social_followers ;;
    hidden: yes
  }

  dimension: month_end_social_followers {
    label: "month_end_social_followers"
    type: number
    sql: ${TABLE}.month_end_social_followers;;
    hidden: yes
  }

  dimension: year_end_social_followers {
    label: "year_end_social_followers"
    type: number
    sql: ${TABLE}.year_end_social_followers;;
    hidden: yes
  }

  dimension: week_end_social_followers {
    label: "week_end_social_followers"
    type: number
    sql: ${TABLE}.week_end_social_followers;;
    hidden: yes
  }

  dimension: month_start_social_followers {
    label: "month_start_social_followers"
    type: number
    sql: ${TABLE}.month_start_social_followers;;
    hidden: yes
  }

  dimension: week_start_social_followers {
    label: "week_start_social_followers"
    type: number
    sql: ${TABLE}.week_start_social_followers;;
    hidden: yes
  }

  dimension: year_start_social_followers {
    label: "year_start_social_followers"
    type: number
    sql: ${TABLE}.year_start_social_followers;;
    hidden: yes
  }

  dimension: replies_dimension {
    type: number
    sql: ${TABLE}.replies ;;
    hidden: yes
  }

  measure: replies {
    type: sum
    value_format: "#,##0"
    label: "Replies"
    description: "The volume of 'replies' on Twitter & Instagram. Part of the Engagements (shares, likes, comments, reactions). [MHAI000089]"
    group_label: "[Managed Metrics]"
    sql: ${replies_dimension} ;;
    hidden: no
  }

  dimension: twitch_social_engagements_dimension {
    type: number
    sql: ${TABLE}.twitch_social_engagements ;;
    hidden: yes
  }

  measure: twitch_social_engagments {    # deactivated in Taxo?? no mapping
    label: "Twitch Social Engagements"
    type: sum
    value_format: "#,##0"
    description: ""
    group_label: "[Managed Metrics]"
    sql: ${twitch_social_engagements_dimension} ;;
    hidden: yes
  }
# --------------------- Managed Organic Calculations --------------------

  dimension: comments_organic_dimension {
    type: string
    sql: IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.comments, 0 ) ;;
    hidden: yes
  }

  measure: comments_organic {
    type: sum
    sql: ${comments_organic_dimension} ;;
    hidden: yes
  }

  dimension: likes_organic_dimension {
    type: string
    sql: IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.likes, 0 ) ;;
    hidden: yes
  }

  measure: likes_organic {
    type: sum
    sql: ${likes_organic_dimension} ;;
    hidden: yes
  }

  dimension: shares_organic_dimension {
    type: string
    sql: IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.shares, 0 ) ;;
    hidden: yes
  }

  measure: shares_organic {
    type: sum
    sql: ${shares_organic_dimension} ;;
    hidden: yes
  }

  dimension: saves_organic_dimension {
    type: string
    sql: IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.saves, 0 ) ;;
    hidden: yes
  }

  measure: saves_organic {
    type: sum
    sql: ${saves_organic_dimension} ;;
    hidden: yes
  }

  measure: social_engagements {
    label: "Engagements"
    type: number
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "Engagements is the number of times a post has been engaged with (shares, likes, comments, reactions, saves). [MHAI000007]"
    sql:  Coalesce (${comments_organic} + ${likes_organic} + ${shares_organic}+ ${saves_organic} +${replies}+${twitter_retweets}+${instagram_tap_backs}+${dislikes}+${twitch_social_engagments}  ,0)  ;;
  }

# to be removed
  measure: social_engagements_organic {
    label: "Social Engagements (IG Organic)"
    type: number
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "Engagements is the number of times a post has been engaged with (shares, likes, comments, reactions). [MHAI000007]"
    sql:  Coalesce (sum (if  ( ${TABLE}.is_paid_account_data = 0, Coalesce (${TABLE}.comments ,  0)+ Coalesce (${TABLE}.likes,0)+ Coalesce (${TABLE}.shares ,0),0)) +${replies}+${twitter_retweets}+${instagram_tap_backs}+${dislikes}+${twitch_social_engagments}  ,0)  ;;
    hidden: yes
  }

  dimension: views_organic_dimension {
    type: string
    sql: IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.views, 0 ) ;;
    hidden: yes
  }

  measure: views_organic {
    type: sum
    sql: ${views_organic_dimension} ;;
    hidden: yes
  }

  measure: avg_views_per_managed_video {
    label: "Avg. Views per Video"
    description: "The average number of views on a managed video. [MHAI000048]"
    type: number
    value_format: "#,##0.00"
    group_label: "[Managed Metrics]"
    sql: if(${managed_videos_with_views}=0,0, ${views_organic}/${managed_videos_with_views});;
    hidden: no
  }

# to be removed
  measure: avg_views_per_managed_video_organic {
    label: "Avg. Views per Video (IG Organic)"
    description: "MHAI000048"
    type: number
    value_format: "#,##0.00"
    group_label: "[Managed Metrics]"
    sql: if(${managed_videos_with_views}=0,0,Coalesce(sum(IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.views, 0 )),0)/${managed_videos_with_views});;
    hidden: yes
  }

  measure: avg_managed_engagements_per_post {
    label: "Avg. Engagements per Post"
    type: number
    value_format: "#,##0.00"
    description: "The average number of engagements per post. [MHAI000039]"
    group_label: "[Managed Metrics]"
    sql: if(${number_managed_assets}=0,0,${social_engagements}/${number_managed_assets});;
    hidden: no
  }

  dimension: impressions_organic_dimension {
    type: string
    sql: IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.managed_impressions, 0 ) ;;
    hidden: yes
  }

  measure: impressions_organic {
    type: sum
    sql: ${impressions_organic_dimension} ;;
    hidden: yes
  }

  measure: avg_impressions_per_post {
    label: "Avg. Impressions per Post"
    type: number
    value_format: "#,##0.00"
    description: "The total impressions divided by the number of Posts published. [MHAI000218]"
    group_label: "[Managed Metrics]"
    sql: if(${number_managed_assets}=0,0, ${impressions_organic}/${number_managed_assets});;
    hidden: no
  }

# to be removed
  measure: avg_impressions_per_post_organic {
    label: "Avg. Impressions per Post (IG Organic)"
    type: number
    value_format: "#,##0.00"
    description: "The total impressions divided by the number of Posts published. [MHAI000218]"
    group_label: "[Managed Metrics]"
    sql: if(${number_managed_assets}=0,0,Coalesce(sum(IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.managed_impressions, 0 )),0)/${number_managed_assets});;
    hidden: yes
  }

  measure: engagement_rate {
    label: "% Engagement Rate (Impressions)"
    type: number
    value_format: "0.00%"
    group_label: "[Managed Metrics]"
    description: "A percentage calculation of engagements per impressions. [MHAI000060]"
    sql: if(${impressions_organic} = 0, 0, ${social_engagements}/ ${impressions_organic});;
    hidden: no
  }

# to be removed
  measure: engagement_rate_organic {
    label: "Engagement Rate (Impressions) % (IG Organic)"
    type: number
    value_format: "0.00%"
    group_label: "[Managed Metrics]"
    description: "A percentage calculation of engagements per impressions. [MHAI000060]"
    sql: if(Coalesce(sum(IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.managed_impressions, 0 )),0)=0, 0, ${social_engagements_organic}/Coalesce(sum(IF ( ${TABLE}.is_paid_account_data = 0 , ${TABLE}.managed_impressions, 0 )),0));;
    hidden: yes
  }



#------------  Managed Calculations  -------------


  # Marks Metric - TBD
  measure: social_engagements_old {
    label: "Social Engagements"
    type: number
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "Social Engagements is the number of times a post has been engaged with (shares, likes, comments, reactions). [MHAI000007]"
    sql: ${comments}+${shares}+${likes}+${replies}+${twitter_retweets}+${instagram_tap_backs}+${dislikes}+${twitch_social_engagments};;
    hidden: yes
  }
# to be removed
  measure: engagement_rate_old {
    label: "Engagement Rate (Impressions) %"
    type: number
    value_format: "0.00%"
    group_label: "[Managed Metrics]"
    description: "A percentage calculation of engagements per impressions. [MHAI000060]"
    sql: if(${managed_impressions}=0, 0, ${social_engagements_old}/${managed_impressions});;
    hidden: yes
  }

  dimension: managed_publishing_volume_dimension {
    type: string
    #not working for youtube as post_first_seen < first day of perfromance
    #sql:  if( DATE (${general_performance.managed_post_first_seen_raw}) = DATE ( ${view_date_raw}),${general_performance.post_url} , null) ;;
    sql:  if( ${general_performance.managed_post_first_seen_date} = ${view_date_date},${general_performance.post_url} , null) ;;
    #workaround (aggregates over trend)
    #sql: if (DATE (${general_performance.managed_post_first_seen_raw}) between ${start_date} and ${end_date} , ${post_url}, NULL) ;;
    #working!
    #sql: if({% if general_performance.view_date_date._is_selected %}
    #      ${general_performance.managed_post_first_seen_hidden_date} = ${view_date_date}
    #     {% elsif general_performance.view_date_week._is_selected %}
    #      ${general_performance.managed_post_first_seen_hidden_week} = ${view_date_week}
    #     {% elsif general_performance.view_date_month._is_selected %}
    #      ${general_performance.managed_post_first_seen_hidden_month} = ${view_date_month}
    #     {% elsif general_performance.view_date_month_num._is_selected %}
    #      ${general_performance.managed_post_first_seen_hidden_month_num} = ${view_date_month_num}
    #     {% elsif general_performance.view_date_quarter._is_selected %}
    #      ${general_performance.managed_post_first_seen_hidden_quarter} = ${view_date_quarter}
    #     {% elsif general_performance.view_date_year._is_selected %}
    #      ${general_performance.managed_post_first_seen_hidden_year} = ${view_date_year}
    #     {% else %}
    #      1=1
    #     {% endif %}
    #      , ${general_performance.post_url} , null) ;;
    hidden: yes
  }

  measure: managed_publishing_volume_excat {
    type: count_distinct
    allow_approximate_optimization: no
    sql:  ${managed_publishing_volume_dimension} ;;
    hidden: yes
  }

  measure: managed_publishing_volume_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql:  ${managed_publishing_volume_dimension} ;;
    hidden: yes
  }

  measure: managed_publishing_volume {
    label: "Publishing Volume (M)"
    type: number
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "The volume of posts published during the chosen timeframe. [MHAI000069]"
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${managed_publishing_volume_excat} {% else %} ${managed_publishing_volume_approximate} {% endif %} ;;
    hidden: no
 }

  dimension: managed_videos_with_views_dimension {
    label: "twitch_social_engagements"
    type: string
    sql: if(${TABLE}.views>0, ${general_performance.post_url}, NULL) ;;
    hidden: yes
  }

  measure: managed_videos_with_views_exact {   #used for avg_views_per_managed_video calc
    type: count_distinct
    group_label: "[Managed Metrics]"
    allow_approximate_optimization: no
    sql: ${managed_videos_with_views_dimension};;
    hidden: yes
  }

  measure: managed_videos_with_views_approximate {   #used for avg_views_per_managed_video calc
    type: count_distinct
    group_label: "[Managed Metrics]"
    allow_approximate_optimization: yes
    sql: ${managed_videos_with_views_dimension};;
    hidden: yes
  }

  measure: managed_videos_with_views {   #used for avg_views_per_managed_video calc
    type: number
    group_label: "[Managed Metrics]"
    sql:0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${managed_videos_with_views_exact} {% else %} ${managed_videos_with_views_approximate} {% endif %} ;;
    hidden: yes
  }

# to be deleted
  measure: avg_views_per_managed_video_old {
    label: "Avg. Views per Managed Video."
    description: "MHAI000048"
    type: number
    value_format: "#,##0.00"
    group_label: "[Managed Metrics]"
    sql: if(${managed_videos_with_views}=0,0,${views_managed}/${managed_videos_with_views});;
    hidden: yes
  }

  dimension: managed_videos_with_impressions_dimension {
    type: string
    sql: if(${TABLE}.managed_impressions>0, ${general_performance.post_url}, NULL) ;;
    hidden: yes
  }

  measure: number_managed_assets_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${managed_videos_with_impressions_dimension};;
    hidden: yes
  }

  measure: number_managed_assets_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${managed_videos_with_impressions_dimension};;
    hidden: yes
  }

  measure: number_managed_assets {
    label: "# Posts"
    type: number
    group_label: "[Managed Metrics]"
    value_format: "#,##0"
    description: "How many managed posts attracted performance (impressions, engagements, views etc.) within the chosen timeframe. [MHAI000074]"
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${number_managed_assets_exact} {% else %} ${number_managed_assets_approximate} {% endif %};;
    hidden: no
  }

  # to be removed
  measure: avg_managed_engagements_per_post_old {
    label: "Avg. Engagements per Post"
    type: number
    value_format: "#,##0.00"
    description: "The average number of engagements per post. [MHAI000039]"
    group_label: "[Managed Metrics]"
    sql: if(${number_managed_assets}=0,0,${social_engagements_old}/${number_managed_assets});;
    hidden: yes
  }

  measure: avg_impressions_per_post_old {
    label: "Avg. Impressions per Post"
    type: number
    value_format: "#,##0.00"
    description: "The total impressions divided by the number of posts published. [MHAI000218]"
    group_label: "[Managed Metrics]"
    sql: if(${number_managed_assets}=0,0,${managed_impressions}/${number_managed_assets});;
    hidden: yes
  }

  dimension: instagram_replies_dimension{
    type: number
    sql: ${TABLE}.instagram_replies ;;
    hidden: yes
  }

  measure: instagram_replies {   # used for ig engagement calculation
    label: "Instagram Replies"
    description: "Part of the Social Engagements. [MHAI000139]"
    type: sum
    group_label: "[Managed Metrics]"
    value_format: "#,##0"
    sql: ${instagram_replies_dimension};;
    hidden: yes
  }

  measure: instagram_story_engagements {
    label: "Instagram Stories Engagements"
    description: "The volume of 'taps back' and 'replies' on Instagram Stories. [MHAI000064]"
    type: number
    group_label: "[Managed Metrics]"
    value_format: "#,##0"
    sql:  ${instagram_replies}+${instagram_tap_backs};;
    hidden: no
  }

  dimension: twitter_replies_dimension{
    type: number
    sql: if(${TABLE}.platform ="Twitter", ${TABLE}.replies, 0) ;;
    hidden: yes
  }

  measure: twitter_replies {  # only replies can be used
    label: "Twitter Replies"
    description: "The volume of 'replies' on Twitter. [MHAI000089]"
    type: sum
    group_label: "[Managed Metrics]"
    value_format: "#,##0"
    sql: ${twitter_replies_dimension};;
    hidden: yes
  }

  dimension: followers_start_dimension{
    type: number
    sql: {% if general_performance.view_date_date._is_selected %}
            if(cast(${TABLE}.view_date as timestamp) = ${view_date_raw}   , ${TABLE}.social_followers, 0)
          {% elsif general_performance.view_date_week._is_selected %}
            ${week_start_social_followers}
          {% elsif general_performance.view_date_month._is_selected %}
           ${month_start_social_followers}
          {% elsif general_performance.view_date_month_num._is_selected %}
           ${month_start_social_followers}
          {% elsif general_performance.view_date_year._is_selected %}
            ${year_start_social_followers}
          {% else %} IF(${TABLE}.view_date = ${start_date}   , ${TABLE}.social_followers, 0) {% endif %}  ;;
    hidden: yes
  }

  measure: followers_start {
    label: "Followers (Start)"
    type: sum
    sql: ${followers_start_dimension} ;;
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "Followers status at the start of a specific period. Used to calculated the followers gain in a specific period. [MHAI000062]"
    hidden: no
  }

  dimension: followers_end_dimension{
    type: number
    sql: {% if general_performance.view_date_date._is_selected %} if(cast(${TABLE}.view_date as timestamp) = ${view_date_raw}   , ${TABLE}.social_followers, 0)
              {% elsif general_performance.view_date_week._is_selected %}
            ${week_end_social_followers}
          {% elsif general_performance.view_date_month._is_selected %}
          ${month_end_social_followers}
          {% elsif general_performance.view_date_month_num._is_selected %}
           ${month_end_social_followers}
          {% elsif general_performance.view_date_year._is_selected %}
            ${year_end_social_followers}
        {% else %} if(${TABLE}.view_date = ${end_date} , ${TABLE}.social_followers, 0) {% endif %}  ;;
    hidden: yes
  }

  measure: followers_end {
    label: "Followers (End)"
    type: sum
    sql: ${followers_end_dimension} ;;
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "Followers status at the end of a specific period. Used to calculated the followers gain in a specific period. [MHAI000061]"
    hidden: no
  }

  measure: followers_gained {
    label: "Followers (Gain)"
    type: number
    value_format: "#,##0"
    group_label: "[Managed Metrics]"
    description: "The gain of social followers in a specific period. Followers Start and End is used to calculated the difference in a specific time period. [MHAI000063]"
    sql: ${followers_end}-${followers_start};;
    hidden: no
  }


#------------  Managed Dimensions  -------------

  dimension: youtube_age_group {
    label: "YouTube Age Group"
    type: string
    group_label: "[Managed Dimensions]"
    description: "Dimension to attribute traffic to a certain age group. [ZPE000402]"
    sql: ${TABLE}.youtube_age_group ;;
    hidden: no
  }

  dimension: youtube_gender {
    label: "YouTube Gender"
    type: string
    description: "Dimension to attribute traffic to a certain gender group. [ZPE000403]"
    group_label: "[Managed Dimensions]"
    sql: ${TABLE}.youtube_gender ;;
    hidden: no
  }

  dimension: youtube_traffic_source {
    label: "YouTube Traffic Source"
    type: string
    group_label: "[Managed Dimensions]"
    description: "How users find the content within YouTube. [ZPE000162]"
    sql: ${TABLE}.youtube_traffic_source ;;
    hidden: no
  }

  dimension: youtube_live_or_on_demand { # needed? this is not used here, I guess only in ETL for live reporting.
    type: number
    group_label: "[Managed Dimensions]"
    sql: ${TABLE}.youtube_live_or_on_demand ;;
    hidden: yes
  }


#------------  Search Console  -------------

  dimension: se_query {
    type: string
    label: "SE Query"
    description: "The specific search query which populated a webpage on a Google search results page which would lead to our site.  [MHAI000119]"
    group_label: "[Search Console Dimensions]"
    sql: ${TABLE}.se_query ;;
    hidden: no
  }

  dimension: se_position {
    type: string
    label: "SE Position"
    description: "Search console dimension. Position of a Google Search results page. [ZPE000587]"
    group_label: "[Search Console Dimensions]"
    sql: ${TABLE}.se_position ;;
    hidden: no
  }

  dimension: se_clicks_dimension {
    type: number
    sql: ${TABLE}.se_clicks ;;
    hidden: yes
  }

  measure: se_clicks {
    type: sum
    value_format: "#,##0"
    label: "SE Clicks"
    description: "Clicks from a specific Google search query to the webpage, as provided from Search Engine Console reporting. [MHAI000117]"
    group_label: "[Search Console Metrics]"
    sql: ${se_clicks_dimension} ;;
    hidden: no
  }

  dimension: se_impressions_dimension {
    type: number
    sql: ${TABLE}.se_impressions ;;
    hidden: yes
  }

  measure: se_impressions {
    type: sum
    value_format:  "#,##0"
    label: "SE Impressions"
    description: "The number of times a google search result leading to our site was populated on the search results page but not necessarily clicked, as provided from Search Engine Console reporting. [MHAI000118]"
    group_label: "[Search Console Metrics]"
    sql: ${se_impressions_dimension} ;;
    hidden: no
  }

  measure: se_ctr {
    type: number
    label: "SE CTR"
    value_format:"0.00%"
    description: "Click-through rate of a Google Search Result. [MHAI000261]"
    group_label: "[Search Console Metrics]"
    sql: if(${se_impressions}=0, 0, ${se_clicks}/${se_impressions}) ;;
    hidden: no
  }


#--------------------- Cross Platform Dimensions ----------------------

  dimension: hostname_account {
    label: "Hostname/Account"
    type: string
    sql: ${TABLE}.hostname_account ;;
    group_label: "[Network Dimensions]"
    description: "Hostname of a website or managed account name on which our content was shown. [ZPE000049]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.hostname_account
  }

  dimension: platform_split {
    label: "Platform Split"
    type: string
    sql:${TABLE}.platform_split ;;
    group_label: "[Network Dimensions]"
    description: "It represents a combination of platform and device category values for RBMN Network reporting. Owned data is broken down to Core Owned and Other Owned. [ZPE000536]"
    hidden: no
    view_label: "General Metadata"
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.platform_split
  }

  dimension: sub_platform {
    label: "Sub-Platform"
    type: string
    sql: ${TABLE}.sub_platform   ;;
    group_label: "[Network Dimensions]"
    description: "Combination of platform and device category for RBMN Network reporting. More granular breakdown of owned. [ZPE000129]"
    hidden: no
    view_label: "General Metadata"
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.sub_platform
  }

# --------------------- Live ------------------------------

  dimension: is_live_asset {
    group_label: "[Live Event Meta Data]"
    label: "Is Live Asset (yes/no)"
    type: string
    #sql:${TABLE}.is_live_asset;;
    sql:   {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.is_live_asset)
    {% else %}
    ${TABLE}.is_live_asset
    {% endif %} ;;
    description: "Indicates if a video asset was live on any platform. This information is part of the global asset and inhertis from other/to other platforms. [ZPE000052]"
    view_label: "General Metadata"
    hidden: no
    suggestions: ["yes","no"]
  }

  dimension_group: livestream_start {
    group_label: "[Live Event Meta Data]"
    label: "Live Stream Start (O)"
    type: time
    timeframes: [
      raw,
      time,
      date
    ]
    sql:CAST (${TABLE}.owned_livestream_start as TIMESTAMP);;
    #sql: CAST (FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', ${TABLE}.owned_livestream_start, 'Europe/Berlin') as TIMESTAMP);;
    description: "Start time of a video content distributed as Live (e.g., live events) in CET. [ZPE000065]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension_group: livestream_end {
    group_label: "[Live Event Meta Data]"
    label: "Live Stream End (O)"
    type: time
    timeframes: [
      raw,
      time,
      date,
    ]
    sql: CAST ( ${TABLE}.owned_livestream_end as TIMESTAMP);;
    #sql: CAST (FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', ${TABLE}.owned_livestream_end, 'Europe/Berlin') as TIMESTAMP);;
    description: "End time of a video content distributed as Live (e.g., live events) in CET. [ZPE000064]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension_group: replay_begins {  # calculation with managed?
    group_label: "[Live Event Meta Data]"
    label: "Replay Begins (O)"
    type: time
    timeframes: [
      raw,
      time,
      date
    ]
    sql: CAST (${TABLE}.owned_replay_begins as TIMESTAMP) ;;
    #sql: CAST (FORMAT_TIMESTAMP('%Y-%m-%d %H:%M:%S', ${TABLE}.owned_replay_begins, 'Europe/Berlin') as TIMESTAMP);;
    description: "Indicates the exact timestamp when the replay starts in CET [ZPE000111]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: days_since_replay_old  {
    group_label: "[Live Event Meta Data]"
    label: "Event Replay Days Owned (#) OLD"
    type: number
    sql:IF (DATE( ${general_performance.view_time_raw}) < DATE ( ${replay_begins_raw}), 99999, DATE_DIFF( date( ${general_performance.view_time_raw}), date (${replay_begins_raw} ), DAY )) ;;
    description: "Days after the live event (number format) [ZPE000040]"
    view_label: "General Metadata"
    hidden: yes
  }

  dimension: days_since_replay  {
    group_label: "[Live Event Meta Data]"
    label: "Event Replay Days Owned (#)"
    type: number
    sql:IF (DATE( ${general_performance.view_date_raw}) < DATE ( ${livestream_start_raw}), 99999, DATE_DIFF( date( ${general_performance.view_date_raw}), date (${livestream_start_raw} ), DAY )) ;;
    description: "Days after the live event (number format) [ZPE000040]"
    view_label: "General Metadata"
    hidden: yes
  }


  dimension:  days_since_replay_text {
    group_label: "[Live Event Meta Data]"
    label: "Event Replay Days Owned (Text)"
    type: string
    sql: 'Replay ' || 'Day ' || ${days_since_replay} ;;
    description: "Days after the live event (text format) [ZPE000041]"
    view_label: "General Metadata"
    hidden: yes
  }


  dimension: yt_days_replay {
    group_label: "[Live Event Meta Data]"
    label: "YouTube Replay days"
    type: number
    sql: IF (DATE( ${general_performance.view_date_raw}) < DATE(${youtube_live_raw}), 99999, DATE_DIFF( date( ${general_performance.view_date_raw}), DATE(${youtube_live_raw}), DAY )) ;;
    description: "[ZPE000557]"
    view_label: "General Metadata"
    hidden: yes
  }


  dimension: fb_days_replay {
    group_label: "[Live Event Meta Data]"
    label: "Facebook Replay days"
    type: number
    sql: IF (DATE( ${general_performance.view_date_raw}) < DATE(${facebook_live_raw}), 99999, DATE_DIFF( date( ${general_performance.view_date_raw}), DATE(${facebook_live_raw}), DAY )) ;;
    description: "[ZPE000558]"
    view_label: "General Metadata"
    hidden: yes
  }

  dimension: th_days_replay {
    group_label: "[Live Event Meta Data]"
    label: "Twitch Replay days"
    type: number
    sql: IF (DATE( ${general_performance.view_date_raw}) < DATE ( ${twitch_live_raw}), 99999, DATE_DIFF( date( ${general_performance.view_date_raw}), date (${twitch_live_raw} ), DAY )) ;;
    description: "It indicates the # of days of replay of Twitch Live video. [ZPE000650]"
    view_label: "General Metadata"
    hidden: yes
  }

  dimension: replay_days_overall { # is a mix of UTC and CET for owned
    group_label: "[Live Event Meta Data]"
    label: "Event Replay Days (Overall)"
    type: number
    sql: CASE
          WHEN ${general_performance.platform} = 'Owned' THEN  ${days_since_replay}
          WHEN ${general_performance.platform} = 'Facebook' THEN  ${fb_days_replay}
          WHEN ${general_performance.platform} = 'YouTube' THEN ${yt_days_replay}
          WHEN ${general_performance.platform} = 'Twitch' THEN ${th_days_replay}
          ELSE NULL
          END    ;;
    description: "Days after the live event (number format) [ZPE000561]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension:  replay_days_overall_text {
    group_label: "[Live Event Meta Data]"
    label: "Event Replay Days Overall (Text)"
    type: string
    sql: 'Replay ' || 'Day ' || ${replay_days_overall} ;;
    description: "Days after the live event (text format) [ZPE000041]"
    view_label: "General Metadata"
    hidden: yes
  }

  dimension_group: facebook_live {
    group_label: "[Live Event Meta Data]"
    label: "Facebook Live"
    type: time
    timeframes: [
      raw,
      date
    ]
    datatype: date
    sql: ${TABLE}.facebook_live_date;;
    description: "The Live Date of a Livestream on Facebook. [ZPE000457]"
    view_label: "General Metadata"
    hidden: yes
  }


  dimension_group: youtube_live {
    group_label: "[Live Event Meta Data]"
    label: "YouTube Live"
    type: time
    timeframes: [
      raw,
      date
    ]
    datatype: date
    sql: ${TABLE}.youtube_live_date;;
    description: "The Live Date of a Livestream on YouTube. [ZPE000458]"
    view_label: "General Metadata"
    hidden: yes
  }

  dimension_group: twitch_live {
    group_label: "[Live Event Meta Data]"
    label: "Twitch Live"
    type: time
    timeframes: [
      raw,
      date
    ]
    datatype: date
    sql: IF (${general_performance.platform} = 'Twitch', ${general_performance.video_first_seen_raw}, Null );;
    description: "The Live Date of a Livestream on Twitch. ZPE000649"
    view_label: "General Metadata"
    hidden: yes
  }

  dimension_group: live_date { # is a mix of UTC and CET for owned
    group_label: "[Live Event Meta Data]"
    label: "Live Start Date (O&M)"
    type: time
    timeframes: [
      raw,
      date
    ]
    datatype: date
    sql: ${TABLE}.live_date ;;
    view_label: "General Metadata"
    description: "ZPE000618"
    hidden: no
  }


  #------------------  Managed Metadata Dimensions -----------------

  dimension: author_country {
    label: "Author Country"
    description: "Sprinklr Author Country, tagged by the countries. [ZPE000012]"
    group_label: "[Managed Dimensions]"
    type: string
    sql: ${TABLE}.author_country ;;
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.author_country
  }

  dimension: country_editorial_tag_sprinklr {
    label: "Country Editorial Tag - Sprinklr"
    description: "Sprinklr Country editorial tags, tagged by the countries. [ZPE000251]"
    group_label: "[Managed Dimensions]"
    type: string
    sql: ${TABLE}.country_editorial_tag_sprinklr ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: headquater_outcome {
    label: "Headquarter Outcome"
    description: "This dimension is used to understand the HQ (global) outcome on managed platforms. Sprinklr Author Country, tagged by the countries with 'missing country' or 'empty' on YouTube being assigned to 'Global'. [ZPE000578]"
    group_label: "[Managed Dimensions]"
    type: string
    sql: ${TABLE}.headquater_outcome ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: instagram_story_id {
    label: "Instagram Story ID"
    description: "The date an IG Story was published (to roll-up performance). [ZPE000050]"
    group_label: "[Managed Dimensions]"
    type: string
    sql: ${TABLE}.instagram_story_id ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: event_initiative {
    label: "Event/Initiative"
    group_label: "[Managed Dimensions]"
    description: "Sprinklr's version of LSC, which event does this content relate to. [ZPE000038]"
    type: string
    sql: ${TABLE}.event_initiative ;;
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.event_initiative
  }

  dimension: is_dark_post {
    label: "Is Dark Post (yes/no)"
    group_label: "[Managed Dimensions]"
    description: "A post which doesn't live on an account's timeline, so will not be seen when looking at an account. It is served to users through paid targeting, but the users who see it can engage with it. In doing so, it may reach some of their own network, doing so organically through their interaction. This means a dark post can also contain both paid and organic performance. [ZPE000365]"
    type: string
    sql: ${TABLE}.is_dark_post ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: is_sponsored {
    label: "Is Sponsored Post (yes/no)"
    group_label: "[Managed Dimensions]"
    description: "A post which was published to an account as an organic post, but received ad spend to help it reach an additional audience. It will contain both paid and organic performance. [ZPE000364]"
    type: string
    sql: ${TABLE}.is_sponsored ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: is_deleted {
    label: "Is Deleted Post (yes/no)"
    group_label: "[Managed Dimensions]"
    description: "This dimension indicates if a post has been deleted. [ZPE000548]"
    type: string
    sql: ${TABLE}.is_deleted ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: is_igtv_post {
    label: "Is IGTV Post (yes/no)"
    group_label: "[Managed Dimensions]"
    description: "This dimension indicates if a post is an IGTV post. [ZPE000549]"
    type: string
    sql:${TABLE}.is_igtv_post;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: is_gif {
    label: "Is GIF (yes/no)"
    group_label: "[Managed Dimensions]"
    description: "This dimension indicates if a post is a GIF. [ZPE000547]"
    type: string
    sql: ${TABLE}.is_gif;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: is_gated {
    label: "Is Gated"
    group_label: "[Managed Dimensions]"
    description: "It shows if managed content is gated i.e. targeting a specific-country audience. [ZPE000675]"
    type: string
    sql: ${TABLE}.is_gated ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: managed_source_country {
    label: "Source Country"
    group_label: "[Managed Dimensions]"
    description: "The country which created/commissioned the content. [ZPE000071]"
    type: string
    sql: ${TABLE}.managed_source_country ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: people_partners {
    label: "People/Partners"
    group_label: "[Managed Dimensions]"
    description: "Filter to view the performance of our athletes or partners. [ZPE000085]"
    type: string
    sql: ${TABLE}.people_partners ;;
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.people_partners
  }

  dimension: message_type {
    label: "Message Type"
    group_label: "[Managed Dimensions]"
    description: "Friendly name of the Sprinklr Message Type code. Mapping based on xsl file received from Sprinklr. [ZPE000069]"
    type: string
    sql:${TABLE}.message_type ;;
    view_label: "General Metadata"
    hidden: no
    suggest_persist_for: "12 hours"
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.message_type
  }

  dimension: post_url {
    label: "Post URL/ID"
    group_label: "[Managed Dimensions]"
    description: "The URL/link to the managed post. [ZPE000563]"
    type: string
    sql: ${TABLE}.post_url;;
    view_label: "General Metadata"
    hidden: no
    suggestable: no
  }

  dimension: source_content_type {
    label: "Source Content Type"
    group_label: "[Managed Dimensions]"
    description: "It indicates the type of content of a managed post (ex VIDEO, PHOTO, LINK, etc). [ZPE000410]"
    type: string
    sql: ${TABLE}.source_content_type  ;;
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.source_content_type
  }


  dimension: sprinklr_post_id {
    label: "Sprinklr Post ID"
    group_label: "[Managed Dimensions]"
    description: "Unique post identifier defined by Sprinklr for all posts. [ZPE000120]"
    type: string
    sql:${TABLE}.sprinklr_post_id;;
    view_label: "General Metadata"
    hidden: no
    suggestable: no
  }

  dimension: sprinklr_post_url {
    label: "Sprinklr Post Url"
    group_label: "[Managed Dimensions]"
    type: string
    sql: ${TABLE}.sprinklr_post_url ;;
    description: "Direct link to post in Sprinklr. [ZPE000564]"
    view_label: "General Metadata"
    hidden: no
  }


  dimension: usa_prog_category {
    label: "Post USA Programming Category"
    group_label: "[Managed Dimensions]"
    description: "Adapted audience naming conventions for US tagging purposes. [ZPE000011]"
    type: string
    sql:${TABLE}.usa_prog_category ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: youtube_description {
    label: "YouTube Description"
    group_label: "[Managed Dimensions]"
    description: "Video Description added in YouTube. [ZPE000160]"
    type: string
    sql: ${TABLE}.youtube_description ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: media_content_link {
    label: "Media Content Link (M)"
    group_label: "[Managed Dimensions]"
    description: "The Content Distribution Network file location of photo or video assets in Sprinklr Asset Manager or the Content Distribution Network file location of any asset that is associated with a post that is visible in Sprinklr. [ZPE000566]"
    type: string
    sql:${TABLE}.media_content_link ;;
    view_label: "General Metadata"
    hidden: no
    suggestable: no
  }

  dimension: managed_post_title {
    label: "Post Title"
    group_label: "[Managed Dimensions]"
    description: "Identifies the title of a managed post, including non-video assets. [ZPE000565]"
    type: string
    sql: ${TABLE}.managed_post_title;;
    view_label: "General Metadata"
    hidden: no
    suggest_explore: video_title_metadata_suggestions
    suggest_dimension: video_title_metadata_suggestions.managed_post_title
  }

  dimension_group: managed_post_first_seen {
    label: "Post First Seen"
    type: time
    timeframes: [
      raw,
      date
    ]
    datatype: date
    sql: ${TABLE}.managed_post_first_seen ;;
    group_label: "[Managed Dimensions]"
    description: "First appearance/ publish date of a managed post. [ZPE000046]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension_group: managed_post_first_seen_hidden {
    label: "Post First Seen"
    type: time
    timeframes: [
      raw,
      date,
      week,
      month,
      month_num,
      quarter,
      year,
    ]
    datatype: date
    sql: ${TABLE}.managed_post_first_seen ;;
    group_label: "[Managed Dimensions]"
    description: "First appearance/ publish date of a managed post. [ZPE000046]"
    view_label: "General Metadata"
    hidden: yes
  }

# ---------------- Video Metadata Dimensions -------------------


  dimension: harmonized_video_id {
    label: "Harmonized Video ID"
    group_label: "[Video Dimensions]"
    description: "If available VIN, otherwise fallback to the original video id. Harmonized across platforms and video ids that are available on the different platforms. [ZPE000048]"
    type: string
    #sql: ${TABLE}.harmonized_video_id ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.harmonized_video_id)
    {% else %}
    ${TABLE}.harmonized_video_id
    {% endif %} ;;
    view_label: "General Metadata"
    hidden: no
    suggestable: no
  }

  dimension: platform_video_title {
    label: "Platform Video Title"
    group_label: "[Video Dimensions]"
    description: "Unharmonized video title that we receive directly from each platform. [ZPE000091]"
    type: string
    #sql: ${TABLE}.platform_video_title;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.platform_video_title)
    {% else %}
    ${TABLE}.platform_video_title
    {% endif %} ;;
    view_label: "General Metadata"
    hidden: no
    suggestable: no
  }


  dimension: video_duration_sec {
    label: "Video Duration (secs)"
    group_label: "[Video Dimensions]"
    description: "Duration of a video in seconds. Metadata derived from Content Hub if essence is available, but falls back to the managed platforms metadata, if the video is trafficked without a VIN. [ZPE000144]"
    type: number
    #sql: ${TABLE}.video_duration ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.video_duration)
    {% else %}
    ${TABLE}.video_duration
    {% endif %} ;;
    view_label: "General Metadata"
    hidden: no
  }

  dimension: video_duration {   #todo
    label: "Video Duration (timestamp)"
    group_label: "[Video Dimensions]"
    description: "Duration Length of a video in following format: hh:mm:ss. Meta data derived from Content Hub if the essence is available, but falls back to the managed platforms metadata if video is trafficked without a VIN."
    type: number
    sql: ${TABLE}.video_duration ;;
    hidden: yes
    view_label: "General Metadata"
  }

  # UPDATE !!!!!!!!
  dimension: video_duration_categories {
    label:"Video Duration Categories"
    type: string
    #sql: ${TABLE}.video_duration_categories;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.video_duration_categories)
    {% else %}
    ${TABLE}.video_duration_categories
    {% endif %} ;;
    group_label: "[Video Dimensions]"
    description: "Video Length in seconds in different buckets [ZPE000145]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension_group: video_first_seen {
    label: "Video First Seen"
    type: time
    timeframes: [
      raw,
      date
    ]
    datatype: date
    #sql: ${TABLE}.video_first_seen ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.video_first_seen)
    {% else %}
    ${TABLE}.video_first_seen
    {% endif %} ;;
    group_label: "[Video Dimensions]"
    description: "First date when the video asset received traffic based on a traffic volumn threshold. [ZPE000047]"
    view_label: "General Metadata"
    hidden: no
  }


  dimension: days_since_video_first_seen  {
    label: "Days Since First Seen (#)"
    type: number
    group_label: "[Video Dimensions]"
    sql:IF (DATE( ${general_performance.view_date_raw}) < DATE ( ${video_first_seen_raw}), -99999, DATE_DIFF( date( ${general_performance.view_date_raw}), date (${video_first_seen_raw} ), DAY )) ;;
    description: "Indicates #days after the video has been first seen [ZPE000027]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension:  days_since_video_first_seen_text {
    label: "Days Since First Seen (Text)"
    type: string
    group_label: "[Video Dimensions]"
    sql: ${days_since_video_first_seen} ;;
    description: "Indicates #days after the video has been first seen [ZPE000028]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: video_title {
    label: "Video Title"
    group_label: "[Video Dimensions]"
    description: "Video Asset title assigned in CREPO (en-int if available) [ZPE000152]"
    type: string
    #sql: ${TABLE}.video_title ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.video_title)
    {% else %}
    ${TABLE}.video_title
    {% endif %} ;;
    view_label: "General Metadata"
    hidden: no
    suggest_explore: video_title_metadata_suggestions
    suggest_dimension: video_title_metadata_suggestions.video_title
  }

  dimension: video_full_title {
    label: "Video Full Title"
    group_label: "[Video Dimensions]"
    description: "Video title with more context. Rule set for different content formats on owned in place e.g Show title + season + episode title. [ZPE000146]"
    type: string
    #sql: ${TABLE}.video_full_title ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.video_full_title)
    {% else %}
    ${TABLE}.video_full_title
    {% endif %} ;;
    view_label: "General Metadata"
    hidden: no
    suggest_explore: video_title_metadata_suggestions
    suggest_dimension: video_title_metadata_suggestions.video_full_title
  }

  dimension: platform_video_id {
    label: "Platform Video ID"
    group_label: "[Video Dimensions]"
    description: "Original Video ID reported from each platform. [ZPE000504]"
    type: string
    #sql: ${TABLE}.platform_video_id ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.platform_video_id)
    {% else %}
    ${TABLE}.platform_video_id
    {% endif %} ;;
    view_label: "General Metadata"
    hidden: no
  }




# -----------   Content Hub Video Meta Data --------------------

  dimension: label_group {
    group_label: "[Video Metadata]"
    label: "Label Group"
    type: string
    #sql: ${TABLE}.label_group ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.label_group)
    {% else %}
    ${TABLE}.label_group
    {% endif %} ;;
    description: "RBMH Content Model Structure (LSC) [ZPE000465]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: lsc_metadata_suggestions
    suggest_dimension: lsc_metadata_suggestions.label_group
  }

  dimension: label {
    group_label: "[Video Metadata]"
    label: "Label"
    type: string
    #sql: ${TABLE}.label ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.label)
    {% else %}
    ${TABLE}.label
    {% endif %} ;;
    description: "RBMH Content Model Structure (LSC) [ZPE000058]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: lsc_metadata_suggestions
    suggest_dimension: lsc_metadata_suggestions.label
  }

  dimension: season {
    group_label: "[Video Metadata]"
    label: "Season"
    type: string
    #sql: ${TABLE}.season ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.season)
    {% else %}
    ${TABLE}.season
    {% endif %} ;;
    description: "RBMH Content Model Structure (LSC) [ZPE000114]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: lsc_metadata_suggestions
    suggest_dimension: lsc_metadata_suggestions.season
  }

  dimension: chapter {
    group_label: "[Video Metadata]"
    label: "Chapter"
    type: string
    #sql: ${TABLE}.chapter ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.chapter)
    {% else %}
    ${TABLE}.chapter
    {% endif %} ;;
    description: "RBMH Content Model Structure (LSC) [ZPE000017]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: lsc_metadata_suggestions
    suggest_dimension: lsc_metadata_suggestions.chapter
  }

  dimension: media_group {
    group_label: "[Video Metadata]"
    label: "Media Group"
    type: string
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
          if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.media_group)
          {% else %}
          ${TABLE}.media_group
          {% endif %} ;;
    description: "RBMH Content Model Structure (LSC) [ZPE000572]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: lsc_metadata_suggestions
    suggest_dimension: lsc_metadata_suggestions.media_group
  }






  dimension: vin {
    group_label: "[Video Metadata]"
    label: "VIN"
    type: string
    #sql: ${TABLE}.vin ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.vin)
    {% else %}
    ${TABLE}.vin
    {% endif %} ;;
    description: "Unique Identifier in Content Hub. Equals Video Asset ID. [ZPE000153]"
    view_label: "General Metadata"
    hidden: no
    suggestable: no
  }

  dimension: language {
    group_label: "[Video Metadata]"
    label: "Video Main Language"
    type: string
    #sql: ${TABLE}.language ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.language)
    {% else %}
    ${TABLE}.language
    {% endif %} ;;
    description: "Main language spoken in the video [ZPE000148]"
    view_label: "General Metadata"
    hidden: no
  }


  dimension: asset_id {
    group_label: "[Video Metadata]"
    label: "Asset ID (Content Hub)"
    type: string
    #sql: ${TABLE}.asset_id ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.asset_id)
    {% else %}
    ${TABLE}.asset_id
    {% endif %} ;;
    description: "Content Hub Asset ID (AA-xxx) [ZPE000136]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: video_content_type_level_2 {
    group_label: "[Video Metadata]"
    label: "Video Content Type (Level 2)"
    type: string
    #sql: ${TABLE}.video_content_type_level_2 ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.video_content_type_level_2)
    {% else %}
    ${TABLE}.video_content_type_level_2
    {% endif %} ;;
    description: "In the Content Terminology each content type can be broken down into one or more asset types. [ZPE000140]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: video_content_type_level_3 {
    group_label: "[Video Metadata]"
    label: "Video Content Type (Level 3)"
    type: string
    #sql: ${TABLE}.video_content_type_level_3 ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.video_content_type_level_3)
    {% else %}
    ${TABLE}.video_content_type_level_3
    {% endif %} ;;
    description: "In the Content Terminology each asset type can be broken down into one or more content formats, also called Video Type. [ZPE000141]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: topic_level_3 {
    group_label: "[Video Metadata]"
    label: "Topic (Level 3)"
    type: string
    #sql: ${TABLE}.topic_level_3  ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.topic_level_3)
    {% else %}
    ${TABLE}.topic_level_3
    {% endif %} ;;
    description: "The Content Hub topic structure for content tagging, level 3 (i.e., Bike Sports) [ZPE000476]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: topic_level_4 {
    group_label: "[Video Metadata]"
    label: "Topic (Level 4)"
    type: string
    #sql: ${TABLE}.topic_level_4 ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.topic_level_4)
    {% else %}
    ${TABLE}.topic_level_4
    {% endif %} ;;
    description: "The Content Hub topic structure for content tagging, level 4 (i.e., BMX) [ZPE000477]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: topic_level_5 {
    group_label: "[Video Metadata]"
    label: "Topic (Level 5)"
    type: string
    #sql: ${TABLE}.topic_level_5 ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.topic_level_5)
    {% else %}
    ${TABLE}.topic_level_5
    {% endif %} ;;
    description: "The Content Hub topic structure for content tagging, level 5. [ZPE000554]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: topic_level_6 {
    group_label: "[Video Metadata]"
    label: "Topic (Level 6)"
    type: string
    #sql: ${TABLE}.topic_level_6 ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.topic_level_6)
    {% else %}
    ${TABLE}.topic_level_6
    {% endif %} ;;
    description: "The Content Hub topic structure for content tagging, level 6 (i.e., BMX Freestyle) [ZPE000478]"
    view_label: "General Metadata"
  }

  dimension: tags {
    group_label: "[Video Metadata]"
    label: "Tags"
    type: string
    #sql: ${TABLE}.tags ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.tags)
    {% else %}
    ${TABLE}.tags
    {% endif %} ;;
    description: "This field is maintained by the Content Tagging team and used to add descriptions on content using single words. [ZPE000473]"
    view_label: "General Metadata"
  }



#------------------  Account Metadata -----------------

  dimension: native_account_id {
    group_label: "[Managed Dimensions]"
    label: "Native Account ID"
    description: "Account ID that is provided by the source. [ZPE000414]"
    type: string
    sql: ${TABLE}.native_account_id ;;
    hidden: no
    view_label: "General Metadata"
  }

  dimension: sprinklr_account_id {
    group_label: "[Managed Dimensions]"
    label: "Sprinklr Account ID"
    description: "Account ID that is provided by sprinklr. [ZPE000415]"
    type: number
    sql: ${TABLE}.sprinklr_account_id ;;
    hidden: no
    view_label: "General Metadata"
  }

  dimension: media_outlet_id {  # used for calculation
    label: "Media Outlet ID (E)"
    type: string
    sql: ${TABLE}.media_outlet_id ;;
    description: "Identifies the unique ID of the media outlet where the item is published. [ZPE000305]"
    group_label: "[Earned Dimensions]"
    hidden: yes
    view_label: "General Metadata"
  }

  dimension: media_type {
    group_label: "[Earned Dimensions]"
    label: "Media Type (E)"
    type: string
    sql: ${TABLE}.media_type ;;
    description: "Identifies the media platform where the item is published. [ZPE000308]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.media_type
  }

  dimension: media_that_matter {
    group_label: "[Earned Dimensions]"
    label: "Media That Matter (yes/no)"
    type: string
    sql: ${TABLE}.media_that_matter ;;
    description: "Identifies if the item is published on a 'Media that Matter' outlet or not. [ZPE000307]"
    view_label: "General Metadata"
    hidden: no
    suggestions: ["yes","no"]
  }



# ------------------   Owned Page Meta Data ----------------------------------

  dimension: app_name {
    group_label: "[Owned Page Meta Data]"
    label: "App Name"
    type: string
    sql:  ${TABLE}.app_name ;;
    description: "Official name of the app as it's designated by the developer [ZPE000003]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: hostname {
    group_label: "[Owned Page Meta Data]"
    label: "Hostname"
    type: string
    sql:${TABLE}.hostname;;
    description: "Either displays the hostname of a website, or the property name (website_categories) for apps. [ZPE000183]"
    view_label: "General Metadata"
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.hostname
    hidden: no
  }

  dimension: asset_translation_link {
    group_label: "[Owned Page Meta Data]"
    label: "Asset Translation Link"
    type: string
    sql:  ${TABLE}.asset_translation_link ;;
    description: "Concatenation of Asset ID plus current language / locale used to track the performance of specific translations. [ZPE000007]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: language_page {
    group_label: "[Owned Page Meta Data]"
    label: "Language"
    type: string
    sql: ${TABLE}.language_page ;;
    description: "The language of the site. [ZPE000060]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: locale {
    group_label: "[Owned Page Meta Data]"
    label: "Locale"
    type: string
    sql: ${TABLE}.locale ;;
    description: "The country that owns the site. Change value occording to the country-version of your site. [ZPE000066]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: languag_locale {
    group_label: "[Owned Page Meta Data]"
    label: "Language Locale"
    type: string
    sql: ${TABLE}.language_locale;;
    description: "Concatination of language and locale of the site.  [ZPE000061]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: macro_categories {
    group_label: "[Owned Page Meta Data]"
    label: "Macro Categories"
    type: string
    sql: ${TABLE}.macro_categories;;
    description: "The Google Analytics account, and overall grouping this site belongs to. [ZPE000068]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.macro_categories
  }

  dimension: website_categories {
    group_label: "[Owned Page Meta Data]"
    label: "Website Categories"
    type: string
    sql: ${TABLE}.website_categories;;
    description: "Google Analytics property [ZPE000155]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.website_categories
  }

  dimension: site_type {   # used for calclulations - is this still used or in etl?
    group_label: "[Owned Page Meta Data]"
    label: "Site Type"
    type: string
    sql:  ${TABLE}.site_type ;;
    description: ""
    hidden: yes
    view_label: "General Metadata"
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.site_type
  }

  dimension_group: page_first_seen {
    group_label: "[Owned Page Meta Data]"
    type: time
    timeframes: [
      raw,
      date,
    ]
    datatype: date
    sql: ${TABLE}.page_first_seen ;;
    description: "First appearance of a site [ZPE000078]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: days_since_page_first_seen  {
    group_label: "[Owned Page Meta Data]"
    label: "Days Since Page First Seen (#)"
    type: number
    sql:IF (DATE( ${general_performance.view_time_raw}) < DATE ( ${page_first_seen_raw}), -99999, DATE_DIFF( date( ${general_performance.view_time_raw}), date (${page_first_seen_raw} ), DAY )) ;;
    description: "Indicates #days after the page has been first seen [ZPE000029]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension:  days_since_page_first_seen_text {
    group_label: "[Owned Page Meta Data]"
    label: "Days Since Page First Seen (Text)"
    type: string
    sql: ${days_since_page_first_seen} ;;
    description: "Indicates #days after the page has been first seen [ZPE000030]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: page_url {
    group_label: "[Owned Page Meta Data]"
    label: "Page Url"
    type: string
    sql: ${TABLE}.page_url ;;
    description: "Indicates the address of the page of a website [ZPE000083]"
    view_label: "General Metadata"
    hidden: no
    suggestable: no
  }

  dimension: page_name_url {           # contains page_name for rbtv apps
    group_label: "[Owned Page Meta Data]"
    label: "Page Name/URL"
    type: string
    sql:  ${TABLE}.page_name_url;;
    description: "Indicates the address of the page of a website or app [ZPE000559]"
    view_label: "General Metadata"
    hidden: no
    suggestable: no
  }

  dimension: page_type {
    group_label: "[Owned Page Meta Data]"
    label: "Page Type"
    type: string
    sql: ${TABLE}.page_type;;
    description: "Classification of different types of pages [ZPE000082]"
    view_label: "General Metadata"
    hidden: no
    suggest_explore: metadata_suggestions
    suggest_dimension: metadata_suggestions.page_type
  }

  dimension: page_sub_type {
    group_label: "[Owned Page Meta Data]"
    label: "Page Sub Type"
    type: string
    sql: ${TABLE}.page_sub_type ;;
    description: "More granular classification of all page types on the site, can be used in conjunction with Page Type [ZPE000080]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: page_title {    # harmonized with Crepo
    group_label: "[Owned Page Meta Data]"
    label: "Page Title"
    type: string
    sql: ${TABLE}.page_title ;;
    description: "Headline displayed on the page [ZPE000081]"
    view_label: "General Metadata"
    hidden: no
  }

  measure: unique_pages_exact {
    allow_approximate_optimization: no
    type: count_distinct
    sql: ${page_url} ;;
    hidden: yes
    view_label: "General Metadata"
  }
  measure: unique_pages_approximate {
    allow_approximate_optimization: yes
    type: count_distinct
    sql: ${page_url} ;;
    hidden: yes
    view_label: "General Metadata"
  }

  measure: unique_pages {
    group_label: "[Owned Page Metrics]"
    label: "Unique Pages"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${unique_pages_exact} {% else %} ${unique_pages_approximate} {% endif %};;
    description: "Count of all page urls that received traffic in the selected period [MHAI000092]"
    view_label: "General Metadata"
    hidden: no
  }

  measure: unique_languages_exact {
    allow_approximate_optimization: no
    type: count_distinct
    sql: ${language_page} ;;
    hidden: yes
    view_label: "General Metadata"
  }

  measure: unique_languages_approximate {
    allow_approximate_optimization: yes
    type: count_distinct
    sql: ${language_page} ;;
    hidden: yes
    view_label: "General Metadata"
  }

  measure: unique_languages {
    group_label: "[Owned Page Metrics]"
    label: "Unique Languages"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${unique_languages_exact} {% else %} ${unique_languages_approximate} {% endif %};;
    description: "Count of all languages that received traffic in the selected period [MHAI000091]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: is_app {
    label: "is App Flag"
    type: string
    sql: ${TABLE}.is_app ;;
    description: "[ZPE000555]"
    hidden: yes
    view_label: "General Metadata"
  }

  # ----------------------  LCM  -----------------

  dimension: business_unit_classification {
    group_label: "[LCM Metadata]"
    label: "Business Unit Classification"
    type: string
    sql: ${TABLE}.business_unit_classification ;;
    description: "Custom domain classification.RBMN, RBMH, Total [ZPE000103]"
    view_label: "General Metadata"
    hidden: no
  }

  dimension: is_rbmn {
    group_label: "[LCM Metadata]"
    label: "Is RBMN (yes/no)"
    type: string
    sql: ${TABLE}.is_rbmn;;
    description: "Business Unit Classification. Sites managed by RBMN (eg. excluding Servustv) [ZPE000055]"
    view_label: "General Metadata"
    hidden: no
    suggestions: ["yes","no"]
  }

  dimension: is_rbmh {
    group_label: "[LCM Metadata]"
    label: "Is RBMH (yes/no)"
    type: string
    sql: ${TABLE}.is_rbmh;;
    description: "Business Unit Classification. Red Bull Media House & Red Bull Media Network relevant and maintened sites (eg. includes Servustv & RB.com) [ZPE000054]"
    view_label: "General Metadata"
    hidden: no
    suggestions: ["yes","no"]
  }

  dimension: is_total {        # naming - should that be total?
    group_label: "[LCM Metadata]"
    label: "Is Total (yes/no)"
    type: string
    sql: ${TABLE}.is_total;;
    description: "Business Unit Classification. All Sites/Managed Accounts linked to our analytics systems [ZPE000056]"
    view_label: "General Metadata"
    hidden: no
    suggestions: ["yes","no"]
  }

  dimension: is_other {
    group_label: "[LCM Metadata]"
    label: "Is Other (yes/no)"   #  _v2??
    type: string
    sql: ${TABLE}.is_other;;
    description: "Business Unit Classificaiton. All non Red Bull branded Sites, which don't belong to RBMH and RBMN (e.g. afrocafe.at) [ZPE000057]"
    view_label: "General Metadata"
    hidden: no
    suggestions: ["yes","no"]
  }

  dimension: is_syndicated {
    group_label: "[LCM Metadata]"
    label: "Is Syndicated (yes/no)"
    type: string
    sql: ${TABLE}.is_syndicated;;
    description: "Based on the domain classification. All traffic that lives outside of our 'Tracking eco system' are syndicated. [ZPE000130]"
    view_label: "General Metadata"
    hidden: no
    suggestions: ["yes","no"]
  }



#### ------------------------ COUNTRY MAPPING -------------------------

  dimension: country_iso2 {
    label: "Performance Country (ISO2)"
    type: string
    sql: TRIM(${TABLE}.performance_country_iso2) ;;
    tags: ["ZPE000020"]
    description: "Two letter performance country ISO code. [ZPE000020]"
    view_label: "Country Dimensions"
    hidden: no
    map_layer_name: countries
    suggest_explore: country_mapping_suggestions
    suggest_dimension: country_mapping_suggestions.country_iso2
  }

  dimension: performance_country {
    label: "Performance Country"
    type: string
    sql: ${TABLE}.performance_country ;;
    description: "Harmonized across platforms. User country where available and author country where not. USA is 'United States' + 'Global-US' [ZPE000022]"
    view_label: "Country Dimensions"
    hidden: no
    suggest_explore: country_mapping_suggestions
    suggest_dimension: country_mapping_suggestions.performance_country
  }

  dimension: hc_region {
    label: "Headquater Region Code"
    type: string
    sql: ${TABLE}.hc_region   ;;
    view_label: "Country Dimensions"
    hidden: yes
    suggest_explore: country_mapping_suggestions
    suggest_dimension: country_mapping_suggestions.hc_region
  }


  dimension: hc_region_text {
    label: "Headquater Region"
    type: string
    sql: ${TABLE}.hc_region_text ;;
    description: "Based on Red Bull Headquarter Region in CDM as dimension. [ZPE000110]"
    view_label: "Country Dimensions"
    hidden: no
    suggest_explore: country_mapping_suggestions
    suggest_dimension: country_mapping_suggestions.hc_region_text
  }

  dimension: mpct {
    label: "Management Profit Center"
    type: string
    sql: ${TABLE}.mpct;;
    description: "[ZPE000556]"
    view_label: "Country Dimensions"
    hidden: no
    suggest_explore: country_mapping_suggestions
    suggest_dimension: country_mapping_suggestions.mpct
  }

  dimension: rb_country {
    label: "Red Bull Country (yes/no)"
    type: string
    sql: CASE WHEN ${mpct} is NOT NULL then 'yes' ELSE 'no' END;;
    description: "Country classifcation based on Red Bull head coaches [ZPE000105]"
    view_label: "Country Dimensions"
    hidden: no
    suggestions: ["yes","no"]
  }

  measure: population {    # average is used for per capita calculation)
    label: "# Population National"
    type: number
    sql: AVG (${TABLE}.population) ;;
    description: "Total population by country sourced from Michael Bauer Research. [XFGD000031]"
    view_label: "Country Dimensions"
    hidden: no
  }


## --------------- CREPO EDITIORIAL META -----------------------

  dimension: crepo_id {
    label: "Crepo ID"
    type: string
    sql: ${TABLE}.crepo_id;;
    group_label: "Admin"
    description: "ZPE000366"
    view_label: "Crepo Page Meta Data"
    hidden: yes
  }

  dimension: author {
    label: "Author"
    type: string
    sql: ${TABLE}.author;;
    description: "Author of the content [ZPE000005]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: content_category {
    label: "Content Category"
    type: string
    sql: ${TABLE}.content_category;;
    description: "Editorial Content Type, used to classify content [ZPE000121]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: content_language_locale {             # hidden?
    label: "Content Language Locale"
    type: string
    sql: ${TABLE}.content_language_locale ;;
    description: "Language locale information from the page asset id from crepo [ZPE000512]"
    hidden: yes
    view_label: "Crepo Page Meta Data"
    suggest_explore: crepo_metadata_suggestions
    suggest_dimension: crepo_metadata_suggestions.content_language_locale
  }

  dimension: content_number_of_photos {
    label: "Content Number of Photos"
    type: number
    sql: ${TABLE}.content_number_of_photos ;;
    description: "Number of Photos embedded in the story [ZPE000379]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: content_number_of_social_embeddings {   # missing
    label: "Content Number of Social Embeds"
    type: number
    sql: ${TABLE}.content_number_of_social_embeddings ;;
    description: "Used to analyze how stories with social media embeds perform e.g. 2. [ZPE000453]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: content_number_of_videos {
    label: "Content Number of Videos"
    type: number
    sql: ${TABLE}.content_number_of_videos ;;
    description: "Number of Videos embedded in the story [ZPE000380]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: content_number_of_words {
    label: "Content Number of Words"
    type: number
    sql: ${TABLE}.content_number_of_words ;;
    description: "Number of words, bucketed in 100 steps on redbull.com stories [ZPE000381]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: created_vs_translated {
    label: "Created vs Translated"
    type: string
    sql: ${TABLE}.created_vs_translated;;
    description: "Shows whether the piece of content was originally created, or is a translation of another piece of content. [ZPE000024]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: creator_locale {
    label: "Creator Locale"
    type: string
    sql:${TABLE}.creator_locale;;
    description: "Shows the language and locale of the country that originally created the content. This allows analysis of the impact of translations of a story. [ZPE000025]"
    view_label: "Crepo Page Meta Data"
    hidden: no
    suggest_explore: crepo_metadata_suggestions
    suggest_dimension: crepo_metadata_suggestions.creator_locale
 }

  dimension: custom_title {
    label: "Custom Title"
    type: string
    sql:${TABLE}.custom_title;;
    description: "Possibility to custom group content in the editor app. [ZPE000387]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: disciplines_all {
    label: "Disciplines All"
    type: string
    sql: ${TABLE}.disciplines_all ;;
    description: "Populated with all discipline tags within the content. [ZPE000131]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: crepo_master_id_page {  # used for calculation 'count of master id, master id publishing volume'
    label: "Master ID (Page)"
    type: string
    sql: ${TABLE}.crepo_crepo_master_id;;
    description: "Used to group together multiple pieces of the same content [ZPE000072]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension_group: editorial_publishing_date {    # fallback in outbound zone
    label: "Editorial Publishing"
    type: time
    timeframes: [  date, raw  ]
    sql: ${TABLE}.editorial_publishing_date;;
    description: "Editorial date set by the editor. Used for eg evergreen content. [ZPE000169]"
    view_label: "Crepo Page Meta Data"
    datatype: date
    hidden: no
  }

  dimension_group: original_publishing_date {
    label: "Original Publishing"
    type: time
    timeframes: [  raw, date  ]
    sql: ${TABLE}.original_publishing_date ;;
    description: "Date when the content piece was the first time published. [ZPE000168]"
    view_label: "Crepo Page Meta Data"
    datatype: date
    hidden: no
  }

  dimension: crepo_editorial_content_type {        # issue
    label: "Content Type (Page)"
    type: string
    sql: ${TABLE}.crepo_editorial_content_type ;;
    description: "The content type listed for videos and pages in CREPO. [ZPE000128]"
    view_label: "Crepo Page Meta Data"
    hidden: no
    suggest_explore: crepo_metadata_suggestions
    suggest_dimension: crepo_metadata_suggestions.content_type
  }

# ------------ First Published --------------


  dimension: first_published_language {
    label: "First Published Language"
    type: string
    sql:  ${TABLE}.first_published_language ;;
    description: "First published language, based on the locale which originally created the content [ZPE000122]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: first_published_locale {
    label: "First Published Locale"
    type: string
    sql: ${TABLE}.first_published_locale ;;
    description: "First published locale, based on the locale which originally created the content [ZPE000123]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: first_published {
    label: "First Published"
    type: date
    sql: ${TABLE}.first_published ;;
    description: "First published date, based on the locale which originally created the content [ZPE000125]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: first_published_disciplines_all {
    label: "First Published Disciplines All"
    type: string
    sql: ${TABLE}.first_published_disciplines_all ;;
    description: "First published disciplines, based on the locale which originally created the content [ZPE000127]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: first_published_page {       # to check, does not seem right
    label: "First Published Page"
    type: string
    sql: ${TABLE}.first_published_page;;
    description: "First published page, based on the locale which originally created the content [ZPE000126]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: first_published_title {
    label: "First Published Title"
    type: string
    sql: ${TABLE}.first_published_title;;
    description: "First published page title, based on the locale which originally created the content [ZPE000382]"
    view_label: "Crepo Page Meta Data"
    hidden: no
  }

  dimension: mediaplanet_id {
    type: string
    sql: ${TABLE}.mediaplanet_id ;;
    group_label: "Admin"
    hidden: yes
    view_label: "Crepo Page Meta Data"
  }

  dimension: meppconnect_id {
    type: string
    sql: ${TABLE}.meppconnect_id ;;
    group_label: "Admin"
    hidden: yes
    view_label: "Crepo Page Meta Data"
  }

## ----------------- CREPO BUNDLE META --------------------------

  dimension: event_profile_country_code {
    type: string
    sql: ${TABLE}.event_profile_country_code ;;
    hidden: yes
    view_label: "Crepo Video Bundle"
  }

  dimension: crepo_video_content_type {
    label: "Content Type (Video)"
    type: string
    sql: ${TABLE}.crepo_content_type;;
    description: "content type in crepo - video metadata [ZPE000128]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }

  dimension: crepo_master_id_video {
    label: "Master ID (Video)"
    type: string
    #sql: ${TABLE}.crepo_master_id;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.crepo_master_id)
    {% else %}
    ${TABLE}.crepo_master_id
    {% endif %} ;;
    description: "Used to group together multiple pieces of the same content [ZPE000072]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }



# -------------------Event Bundle ----------------------


  dimension: event_titel {  # harmonized
    label: "Event Title"
    type: string
    sql:
    CASE WHEN ${event_series_title} is NOT NULL THEN ${event_series_title}
    ELSE ${event_profile_title} END;;
    group_label: "[Event Bundle]"
    description: "Title of an event series or an single stop event [ZPE000043]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }

  dimension: event_season_number {    # ZPE000374 is a duplicate
    label: "Event Year Title"
    type: number
    value_format: "0"
    sql: COALESCE ( ${TABLE}.event_season_number, 0) ;;
    group_label: "[Event Bundle]"
    description: "Title of a year [ZPE000044]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }

  dimension: event_profile_country_name {
    label: "Event Profile Country Name"
    type: string
    sql: ${TABLE}.event_profile_country_name ;;
    group_label: "[Event Bundle]"
    description: "[ZPE000377]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }

  dimension: event_profile_label {
    label: "Event Stop Title"
    type: string
    sql: ${TABLE}.event_stop_title ;;
    group_label: "[Event Bundle]"
    description: "Event Profile Label [ZPE000042]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }

  dimension: event_profile_title {   # used for Event Title rule
    type: string
    sql: ${TABLE}.event_profile_title ;;
    hidden: yes
    view_label: "Crepo Video Bundle"
  }

  dimension: event_series_title {  # used for Event Title rule
    type: string
    sql: ${TABLE}.event_series_title ;;
    hidden: yes
    view_label: "Crepo Video Bundle"
  }

# ------------ Show Bundle --------------

  dimension: show_title {
    label: "Show Title"
    type: string
    sql: ${TABLE}.show_title;;
    group_label: "[Show Bundle]"
    description: "Title of a Show [ZPE000118]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }

  dimension: episode_title {
    label: "Episode Title"
    type: string
    sql: ${TABLE}.episode_title  ;;
    group_label: "[Show Bundle]"
    description: "Title of an episode [ZPE000037]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }

  dimension: season_title {
    label: "Season Title"
    type: string
    sql: ${TABLE}.season_title ;;
    group_label: "[Show Bundle]"
    description: "Title of a Show Season [ZPE000116]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }

  dimension: season_number {
    label: "Season Number"
    type: string
    sql: CAST ( ${TABLE}.season_number as string);;
    group_label: "[Show Bundle]"
    description: "[ZPE000370]"
    hidden: yes
    view_label: "Crepo Video Bundle"
  }

# ----------------- Film Bundle ------------------

  dimension: film_title {
    label: "Film Title"
    type: string
    sql: ${TABLE}.film_title  ;;
    group_label: "[Film Bundle]"
    description: "Title of a Film [ZPE000045]"
    view_label: "Crepo Video Bundle"
    hidden: no
  }


  ## ---------------  DEVICE MAPPING ------------------------

  dimension: device {
    label: "Device"
    type: string
    sql: ${TABLE}.device;;
    description: "Indicates the individual device platform (Owned and Managed) [ZPE000031]"
    view_label: "Device and Platform Mapping"
    hidden: no
    suggest_explore: device_mapping_suggestions
    suggest_dimension: device_mapping_suggestions.device
  }

  dimension: device_category {
    label: "Device Category"
    type: string
    sql: ${TABLE}.device_category;;
    description: "Harmonized across all platforms with YT device split [ZPE000033]"
    view_label: "Device and Platform Mapping"
    hidden: no
    suggest_explore: device_mapping_suggestions
    suggest_dimension: device_mapping_suggestions.device_category
  }

  dimension: platform_reporting_category {
    label: "Platform Reporting Category"
    type: string
    sql: ${TABLE}.platform_reporting_category ;;
    description: "Combination of platform and device category for the Owned & Managed RBMN Network reporting. Owned data is split into Owned Web, Owned Mobile Apps, Owned TV Apps, Owned Games. [ZPE000090]"
    view_label: "Device and Platform Mapping"
    hidden: no
    suggest_explore: device_mapping_suggestions
    suggest_dimension: device_mapping_suggestions.platform_reporting_category
  }


  ## ----------------- IML MAPPING -------------------------


  dimension: project_group_id {
    label: "Project Group ID"
    type: string
    #sql: ${TABLE}.project_group_id ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_group_id)
    {% else %}
    ${TABLE}.project_group_id
    {% endif %} ;;
    description: "The Project Group ID (IML) identifies the harmonized ID for Events & Projects. [ZPE000361]"
    view_label: "IML Mapping"
    hidden: no
    suggest_explore: iml_mapping_suggestions
    suggest_dimension: iml_mapping_suggestions.project_group_id
  }

  dimension: project_group_title {
    label: "Project Group"
    type: string
    #sql:${TABLE}.project_group_title;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_group_title)
    {% else %}
    ${TABLE}.project_group_title
    {% endif %} ;;
    description: "The IML Project Group classifies as our highest PEMO project reporting level within the IML tree structure. It acts as a harmonised parent object for Events & Projects, followed by their related IML Seasons and the IML Single Stops. [ZPE000544]"
    view_label: "IML Mapping"
    hidden: no
    suggest_explore: iml_mapping_suggestions
    suggest_dimension: iml_mapping_suggestions.project_group_title
  }

  dimension: project_season_id {
    label: "Project Season ID"
    type: string
    #sql: ${TABLE}.project_season_id ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_season_id)
    {% else %}
    ${TABLE}.project_season_id
    {% endif %} ;;
    description: "The Project Season (IML) ID acts as a unique identifier for our second harmonized PEMO project reporting level. [ZPE000362]"
    view_label: "IML Mapping"
    hidden: no
    suggest_explore: iml_mapping_suggestions
    suggest_dimension: iml_mapping_suggestions.project_season_id
  }

  dimension: project_season_title {
    label: "Project Season"
    type: string
    #sql: ${TABLE}.project_season_title;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_season_title)
    {% else %}
    ${TABLE}.project_season_title
    {% endif %} ;;
    description: "The IML Project Season classifies either the year of the first airing of the project or the season for episodical content within the IML tree structure. It acts as a harmonised middle layer for Events & Projects, followed by their related IML Single Stops and parented by the IML Group. [ZPE000545]"
    view_label: "IML Mapping"
    hidden: no
    suggest_explore: iml_mapping_suggestions
    suggest_dimension: iml_mapping_suggestions.project_season_title
  }

  dimension: project_single_stop_id {
    label: "Project Single Stop ID"
    type: string
    #sql: ${TABLE}.project_single_stop_id ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_single_stop_id)
    {% else %}
    ${TABLE}.project_single_stop_id
    {% endif %} ;;
    description: "The Project Single Stop ID (IML) acts as a unique identifier for our lowest harmonized PEMO project reporting level. [ZPE000363]"
    view_label: "IML Mapping"
    hidden: no
    suggest_explore: iml_mapping_suggestions
    suggest_dimension: iml_mapping_suggestions.project_single_stop_id
  }

  dimension: project_single_stop_title {
    label: "Project Single Stop"
    type: string
    #sql: ${TABLE}.project_single_stop_title;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_single_stop_title)
    {% else %}
    ${TABLE}.project_single_stop_title
    {% endif %} ;;
    description: "The IML Project Single Stop Title acts as a harmonised layer for Events & Projects, parented by the IML Season and IML Group. [ZPE000546]"
    view_label: "IML Mapping"
    hidden: no
    suggest_explore: iml_mapping_suggestions
    suggest_dimension: iml_mapping_suggestions.project_single_stop_title
  }

  dimension: project_status {
    label: "Project Status"
    type: string
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
          if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_status)
          {% else %}
          ${TABLE}.project_status
          {% endif %} ;;
    description: "Shows the project status captured in MEPP and/or MediaPlanet on the lowest possible level - the lowest level can be a Group, Season, or Single Stop. [ZPE000677]"
    view_label: "IML Mapping"
    hidden: no
    suggest_explore: iml_mapping_suggestions
    suggest_dimension: iml_mapping_suggestions.project_status
  }


  ##  --------------  PLAYGROUND MAPPING  ------------------
  ##    ----- ASSET -----
  dimension: asset_option_value_path {
    label: "Asset Playground Path"
    type: string
    #sql: ${TABLE}.asset_option_value_path ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.asset_option_value_path)
    {% else %}
    ${TABLE}.asset_option_value_path
    {% endif %} ;;
    description: ""
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.option_value_path
  }

  dimension: asset_playground_category {
    label: "Asset Playground Category (Level 1)"
    type: string
    #sql: ${TABLE}.asset_playground_category;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.asset_playground_category)
    {% else %}
    ${TABLE}.asset_playground_category
    {% endif %} ;;
    description: "Identifies the playground category tagged on the item. [ZPE000524]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.playground_category
  }

  dimension: asset_playground {
    label: "Asset Playground (Level 2)"
    type: string
    #sql:${TABLE}.asset_playground;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.asset_playground)
    {% else %}
    ${TABLE}.asset_playground
    {% endif %} ;;
    description: "Identifies the playground tagged on the item.[ZPE000250]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.playground
  }

  dimension: asset_playground_type {
    label: "Asset Playground Type (Level 3)"
    type: string
    #sql: ${TABLE}.asset_playground_type;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.asset_playground_type)
    {% else %}
    ${TABLE}.asset_playground_type
    {% endif %} ;;
    description: "Identifies the playground typetagged on the item.[ZPE000525]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.playground_type
  }

  dimension: asset_playground_discipline {
    label: "Asset Playground Discipline (Level 4) "
    type: string
    #sql:${TABLE}.asset_playground_discipline;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.asset_playground_discipline)
    {% else %}
    ${TABLE}.asset_playground_discipline
    {% endif %} ;;
    description: "Identifies the playground discipline tagged on the item.[ZPE000526]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.playground_discipline
  }

  dimension: asset_sap_playground_key {
    label: "Asset Playground SAP ID"
    type: string
    #sql: ${TABLE}.asset_sap_playground_key ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.asset_sap_playground_key)
    {% else %}
    ${TABLE}.asset_sap_playground_key
    {% endif %} ;;
    description: "Official Asset Playground ID SAP [ZPE000413]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.sap_playground_key
  }

  dimension: asset_sap_playground_key_path {
    type: string
    #sql: ${TABLE}.asset_sap_playground_key_path ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.asset_sap_playground_key_path)
    {% else %}
    ${TABLE}.asset_sap_playground_key_path
    {% endif %} ;;
    hidden: yes
    view_label: "Playground Mapping"
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.sap_playground_key_path
  }

  ## ------  PROJECT  -----

  dimension: project_option_value_path {
    label: "Project Playground Path"
    type: string
    #sql: ${TABLE}.project_option_value_path ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_option_value_path)
    {% else %}
    ${TABLE}.project_option_value_path
    {% endif %} ;;
    description: ""
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.option_value_path
  }

  dimension: project_playground_category {
    label: "Project Playground Category (Level 1)"
    type: string
    #sql: ${TABLE}.project_playground_category;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_playground_category)
    {% else %}
    ${TABLE}.project_playground_category
    {% endif %} ;;
    description: "Identifies the playground category of the event/project tagged on the item. [ZPE000246]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.playground_category
  }

  dimension: project_playground {
    label: "Project Playground (Level 2)"
    type: string
    #sql:${TABLE}.project_playground;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_playground)
    {% else %}
    ${TABLE}.project_playground
    {% endif %} ;;
    description: "Identifies the playground of the event/project tagged on the item.[ZPE000247]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.playground
  }

  dimension: project_playground_type {
    label: "Project Playground Type (Level 3)"
    type: string
    #sql: ${TABLE}.project_playground_type;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_playground_type)
    {% else %}
    ${TABLE}.project_playground_type
    {% endif %} ;;
    description: "Identifies the playground type of the event/project tagged on the item.[ZPE000248]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.playground_type
  }

  dimension: project_playground_discipline {
    label: "Project Playground Discipline (Level 4) "
    type: string
    #sql:${TABLE}.project_playground_discipline;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_playground_discipline)
    {% else %}
    ${TABLE}.project_playground_discipline
    {% endif %} ;;
    description: "Identifies the playground discipline of the event/project tagged on the item.[ZPE000249]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.playground_discipline
  }

  dimension: project_sap_playground_key {
    label: "Project Playground SAP ID"
    type: string
    #sql: ${TABLE}.project_sap_playground_key ;;
    sql: {% if disable_linear_parsing._parameter_value == "'yes'" %}
    if(${linear_stream_type}= 'Linear (unparsed)',NULL, ${TABLE}.project_sap_playground_key)
    {% else %}
    ${TABLE}.project_sap_playground_key
    {% endif %} ;;
    description: "Official Playground ID SAP [ZPE000412]"
    view_label: "Playground Mapping"
    hidden: no
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.sap_playground_key
  }

  dimension: project_sap_playground_key_path {
    type: string
    sql: ${TABLE}.asset_sap_playground_key_path ;;
    hidden: yes
    view_label: "Playground Mapping"
    suggest_explore: playground_mapping_suggestions
    suggest_dimension: playground_mapping_suggestions.sap_playground_key_path
  }


  # ------------ Video Language Mapping ---------------

  dimension: video_audio_language {
    label: "Video Audio Language"
    type: string
    sql: ${TABLE}.video_audio_language ;;
    description: "It indicates the audio language of the video in case different audio streams are available for the same asset. [ZPE000584]"
    view_label: "Video Language Mapping"
    hidden: no
  }

  dimension: video_subtitle_language {
    label: "Video Subtitle Language"
    type: string
    sql: ${TABLE}.video_subtitle_language ;;
    description: "It indicates the subtitle language sent by the player if captions are available. [ZPE000581]"
    view_label: "Video Language Mapping"
    hidden: no
  }







## ------------------  MODULE Tracking --------------------

  dimension: module_name {
    label: "Module Name"
    type: string
    sql: ${TABLE}.module_name ;;
    description: "Promotion Module in GA [ZPE000074]"
    view_label: "Module Tracking"
    hidden: no
  }

  dimension: promo_id {
    label: "Promo ID"
    type: string
    sql: ${TABLE}.promo_id ;;
    description: "ID - asset ID (Editor App resource ID) of featured asset. [ZPE000096]"
    view_label: "Module Tracking"
    hidden: no
  }

  dimension: promo_name {
    label: "Promo Name"
    type: string
    sql: ${TABLE}.promo_name ;;
    description: "Name - Link of the destination URL. [ZPE000097]"
    view_label: "Module Tracking"
    hidden: no
  }

  dimension: promo_position {
    label: "Promo Position"
    type: string
    sql: ${TABLE}.promo_position ;;
    description: "Position - number of position within the component where asset was featured (from 1 to n) [ZPE000098]"
    view_label: "Module Tracking"
    hidden: no
  }

  dimension: promo_type {
    label: "Promo Type"
    type: string
    sql: ${TABLE}.promo_type ;;
    description: "Type - differentiates between asset types (story pages, events, athletes, external) [ZPE000099]"
    view_label: "Module Tracking"
    hidden: no
  }

  dimension: module_click_type {
    label: "Module Click Type"
    type: string
    sql: ${TABLE}.module_click_type ;;
    description: "Promotion Click Type in GA [ZPE000073]"
    view_label: "Module Tracking"
    hidden: no
  }

  dimension: elements_available_in_module {
    label: "Elements Available in Module"
    type: string
    sql: ${TABLE}.elements_available_in_module ;;
    description: "Total number of cards displayed in a component (like cardfeed or rail) [ZPE000035]"
    view_label: "Module Tracking"
    hidden: no
  }

  dimension: module_clicks_dimension {
    type: number
    sql: ${TABLE}.module_clicks ;;
    view_label: "Module Tracking"
    hidden: yes
  }

  measure: module_clicks {
    label: "Module Clicks"
    type: sum
    sql: ${module_clicks_dimension} ;;
    description: "Internal Promotion Clicks in GA [MHAI000071]"
    view_label: "Module Tracking"
    hidden: no
  }

  dimension: module_impressions_dimension {
    type: string
    sql: IF ( ${TABLE}.module_impressions >0, ${module_tracking_key}, NULL) ;;
    view_label: "Module Tracking"
    hidden: yes
  }

  measure: module_impressions_exact {
    type: count_distinct
    allow_approximate_optimization: no
    sql: ${module_impressions_dimension} ;;
    view_label: "Module Tracking"
    hidden: yes
  }

  measure: module_impressions_approximate {
    type: count_distinct
    allow_approximate_optimization: yes
    sql: ${module_impressions_dimension} ;;
    view_label: "Module Tracking"
    hidden: yes
  }

  measure: module_impressions {
    label: "Module Impressions"
    type: number
    sql: 0 + {% if general_performance.force_exact_count._parameter_value == "'yes'" %} ${module_impressions_exact} {% else %} ${module_impressions_approximate} {% endif %} ;;
    description: "Internal Promotion Views in GA [MHAI000073]"
    view_label: "Module Tracking"
    hidden: no
  }

  measure: module_ctr {
    label: "Module CTR"
    type: number
    value_format: "0.00"
    sql: IF (${module_impressions}=0,0, ${module_clicks}/ ${module_impressions}) ;;
    description: "Internal Promotion CTR in GA [MHAI000072]"
    view_label: "Module Tracking"
    hidden: no
  }


# ------------- Trend Metrics -------------
  # preperation of dimensions
  dimension: interactive_session_id_per_day {
    label: "interactive_session_id_per_day"
    group_label: "Admin"
    type: string
    sql: IF(${TABLE}.session_is_interactive = 1,CONCAT(${view_date_date},'_',${TABLE}.session_id), Null);;
    hidden: yes
  }

  dimension: interactive_session_id_per_week {
    label: "interactive_session_id_per_week"
    group_label: "Admin"
    type: string
    sql: IF(${TABLE}.session_is_interactive = 1,CONCAT(${view_date_week},'_',${TABLE}.session_id), Null);;
    hidden: yes
  }

  dimension: interactive_session_id_per_month {
    label: "interactive_session_id_per_month"
    group_label: "Admin"
    type: string
    sql: IF(${TABLE}.session_is_interactive = 1,CONCAT(${view_date_month},'_',${TABLE}.session_id), Null);;
    hidden: yes
  }

  dimension: full_visitor_id_per_day {
    label: "full_visitor_id_per_day"
    group_label: "Admin"
    type: string
    sql: CONCAT(${view_date_date},'_',${TABLE}.full_visitor_id);;
    hidden: yes
  }

  dimension: full_visitor_id_per_week {
    label: "full_visitor_id_per_week"
    group_label: "Admin"
    type: string
    sql: CONCAT(${view_date_week},'_',${TABLE}.full_visitor_id);;
    hidden: yes
  }

  dimension: full_visitor_id_per_month {
    label: "full_visitor_id_per_month"
    group_label: "Admin"
    type: string
    sql: CONCAT(${view_date_month},'_',${TABLE}.full_visitor_id);;
    hidden: yes
  }

  dimension: video_play_id_per_day {
    label: "Video video_play_id_per_day ID"
    group_label: "Admin"
    type:  number
    sql:  CONCAT(${view_date_date},'_',{% if general_performance.disable_linear_parsing._parameter_value == "'yes'" %}
          ${TABLE}.video_play_id_excl_borb
          {% else %}
          ${TABLE}.video_play_id
          {% endif %}) ;;
    hidden: yes
  }

  dimension: video_play_id_per_week {
    label: "Video video_play_id_per_month ID"
    group_label: "Admin"
    type:  number
    sql:  CONCAT(${view_date_week},'_',{% if general_performance.disable_linear_parsing._parameter_value == "'yes'" %}
          ${TABLE}.video_play_id_excl_borb
          {% else %}
          ${TABLE}.video_play_id
          {% endif %}) ;;
    hidden: yes
  }

  dimension: video_play_id_per_month {
    label: "Video video_play_id_per_month ID"
    group_label: "Admin"
    type:  number
    sql:  CONCAT(${view_date_month},'_',{% if general_performance.disable_linear_parsing._parameter_value == "'yes'" %}
          ${TABLE}.video_play_id_excl_borb
          {% else %}
          ${TABLE}.video_play_id
          {% endif %}) ;;
    hidden: yes
  }

  dimension: video_viewer_id_per_day {
    label: "video_viewer_id_per_day"
    group_label: "Admin"
    type: string
    sql: CONCAT(${view_date_date},'_',${TABLE}.video_viewer_id);;
    hidden: yes
  }

  dimension: video_viewer_id_per_week {
    label: "video_viewer_id_per_week"
    group_label: "Admin"
    type: string
    sql: CONCAT(${view_date_week},'_',${TABLE}.video_viewer_id);;
    hidden: yes
  }

  dimension: video_viewer_id_per_month {
    label: "video_viewer_id_per_month"
    group_label: "Admin"
    type: string
    sql: CONCAT(${view_date_month},'_',${TABLE}.video_viewer_id);;
    hidden: yes
  }

  # DAILY Trends
  measure: visits_trend_day_avg {
    label: "Visits (day avg)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${interactive_session_id_per_day}) / COUNT(distinct ${view_date_date});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily visits in the selected period. [MHAI000303]"
    hidden: no
  }

  measure: visitors_trend_day_avg {
    label: "Visitors (day avg) (DEPR)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${full_visitor_id_per_day}) / COUNT(distinct ${view_date_date});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily visitors in the selected period. [MHAI000304]"
    hidden: yes
  }

  measure: views_trend_day_avg {
    label: "Views (day avg)"
    type:  number
    value_format: "#,##0"
    sql: (${views_managed} + COUNT(distinct ${video_play_id_per_day})) / COUNT(distinct ${view_date_date});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily views in the selected period. [MHAI000301]"
    hidden: no
  }

  measure: viewers_trend_day_avg {
    label: "Viewers (day avg) (DEPR)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${video_viewer_id_per_day}) / COUNT(distinct ${view_date_date});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily viewers in the selected period. [MHAI000302]"
    hidden: yes
  }

  measure: visits_per_visitor_trend_day_avg {
    label: "Visits per Visitor (day avg) (DEPR)"
    type:  number
    value_format: "0.##"
    sql: IF(COUNT(distinct ${full_visitor_id_per_day}) = 0, 0, (COUNT(distinct ${interactive_session_id_per_day}) / COUNT(distinct ${full_visitor_id_per_day})));;
    #sql: IF(${visitors_trend_day_avg} = 0, 0, ${visits_trend_day_avg} / ${visitors_trend_day_avg});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily visits per visitor in the selected period. [MHAI000306]"
    hidden: yes
  }

  measure: views_per_viewer_trend_day_avg {
    label: "Views per Viewer (day avg) (DEPR)"
    type:  number
    value_format: "0.##"
    sql: IF(COUNT(distinct ${video_viewer_id_per_day}) = 0, 0, (COUNT(distinct ${video_play_id_per_day}) / COUNT(distinct ${video_viewer_id_per_day})));;
    #sql: IF(${viewers_trend_day_avg} = 0, 0, (COUNT(distinct ${video_play_id_tec})) / COUNT(distinct ${view_date_date}) / ${viewers_trend_day_avg});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily views per viewer in the selected period. [MHAI000305]"
    hidden: yes
  }

  measure: total_time_watched_trend_day_avg {
    label: "Total Time Watched (min) (day avg)"
    type:  number
    value_format: "#,##0.00"
    sql: ${total_time_watched_minutes} / COUNT(distinct ${view_date_date});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily total time watched in the selected period. [MHAI000307]"
    hidden: no
  }

  measure: total_time_spent_trend_day_avg {
    label: "Total Time Spent (min) (day avg)"
    type:  number
    value_format: "#,##0.00"
    sql: ${total_time_spent_owned_minutes} / COUNT(distinct ${view_date_date});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily total time spent in the selected period. [MHAI000308]"
    hidden: no
  }

  measure: average_time_watched_per_view_trend_day_avg {
    label: "Avg. Time Watched per View (min) (day avg)"
    type:  number
    value_format: "#,##0.00"
    sql: IF ((COUNT(distinct ${video_play_id_tec}) + ${calculated_views}) =0,0, ${total_time_watched_minutes}/(COUNT(distinct ${video_play_id_tec}) + ${calculated_views}));;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average daily time watched per view in the selected period. [MHAI000309]"
    hidden: no
  }

  # WEEKLY Trends
  measure: visits_trend_week_avg {
    label: "Visits (week avg)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${interactive_session_id_per_week}) / COUNT(distinct ${view_date_week});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly visits in the selected period. [MHAI000294]"
    hidden: no
  }

  measure: visitors_trend_week_avg {
    label: "Visitors (week avg) (DEPR)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${full_visitor_id_per_week}) / COUNT(distinct ${view_date_week});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly visitors in the selected period. [MHAI000295]"
    hidden: yes
  }

  measure: views_trend_week_avg {
    label: "Views (week avg)"
    type:  number
    value_format: "#,##0"
    sql: (${views_managed} + COUNT(distinct ${video_play_id_per_week})) / COUNT(distinct ${view_date_week});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly views in the selected period. [MHAI000292]"
    hidden: no
  }

  measure: viewers_trend_week_avg {
    label: "Viewers (week avg) (DEPR)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${video_viewer_id_per_week}) / COUNT(distinct ${view_date_week});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly viewers in the selected period. [MHAI000293]"
    hidden: yes
  }

  measure: visits_per_visitor_trend_week_avg {
    label: "Visits per Visitor (week avg) (DEPR)"
    type:  number
    value_format: "0.##"
    sql: IF(COUNT(distinct ${full_visitor_id_per_week}) = 0, 0, (COUNT(distinct ${interactive_session_id_per_week}) / COUNT(distinct ${full_visitor_id_per_week})));;
    #sql: IF(${visitors_trend_week_avg} = 0, 0, ${visits_trend_week_avg} / ${visitors_trend_week_avg});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly visits per visitor in the selected period. [MHAI000297]"
    hidden: yes
  }

  measure: views_per_viewer_trend_week_avg {
    label: "Views per Viewer (week avg) (DEPR)"
    type:  number
    value_format: "0.##"
    sql: IF(COUNT(distinct ${video_viewer_id_per_week}) = 0, 0, (COUNT(distinct ${video_play_id_per_week}) / COUNT(distinct ${video_viewer_id_per_week})));;
    #sql: IF(${viewers_trend_week_avg} = 0, 0, (COUNT(distinct ${video_play_id_per_week})) / COUNT(distinct ${view_date_week}) / ${viewers_trend_week_avg});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly views per viewer in the selected period. [MHAI000296]"
    hidden: yes
  }

  measure: total_time_watched_trend_week_avg {
    label: "Total Time Watched (min) (week avg)"
    type:  number
    value_format: "#,##0.00"
    sql: ${total_time_watched_minutes} / COUNT(distinct ${view_date_week});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly total time watched in the selected period. [MHAI000298]"
    hidden: no
  }

  measure: total_time_spent_trend_week_avg {
    label: "Total Time Spent (min) (week avg)"
    type:  number
    value_format: "#,##0.00"
    sql: ${total_time_spent_owned_minutes} / COUNT(distinct ${view_date_week});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly total time spent in the selected period. [MHAI000299]"
    hidden: no
  }

  measure: average_time_watched_per_view_trend_week_avg {
    label: "Avg. Time Watched per View (min) (week avg)"
    type:  number
    value_format: "#,##0.00"
    sql: IF ((COUNT(distinct ${video_play_id_per_week}) + ${calculated_views}) =0,0, ${total_time_watched_minutes}/(COUNT(distinct ${video_play_id_per_week}) + ${calculated_views}));;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average weekly time watched per view in the selected period. [MHAI000300]"
    hidden: no
  }

  # MONTHLY Trends
  measure: visits_trend_month_avg {
    label: "Visits (month avg)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${interactive_session_id_per_month}) / COUNT(distinct ${view_date_month});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly visits in the selected period. [MHAI000285]"
    hidden: no
  }

  measure: visitors_trend_month_avg {
    label: "Visitors (month avg) (DEPR)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${full_visitor_id_per_month}) / COUNT(distinct ${view_date_month});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly visitors in the selected period. [MHAI000286]"
    hidden: yes
  }

  measure: views_trend_month_avg {
    label: "Views (month avg)"
    type:  number
    value_format: "#,##0"
    sql: (${views_managed} + COUNT(distinct ${video_play_id_per_month})) / COUNT(distinct ${view_date_month});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly views in the selected period. [MHAI000283]"
    hidden: no
  }

  measure: viewers_trend_month_avg {
    label: "Viewers (month avg) (DEPR)"
    type:  number
    value_format: "#,##0"
    sql: COUNT(distinct ${video_viewer_id_per_month}) / COUNT(distinct ${view_date_month});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly viewers in the selected period. [MHAI000284]"
    hidden: yes
  }

  measure: visits_per_visitor_trend_month_avg {
    label: "Visits per Visitor (month avg) (DEPR)"
    type:  number
    value_format: "0.##"
    sql: IF(COUNT(distinct ${full_visitor_id_per_month}) = 0, 0, (COUNT(distinct ${interactive_session_id_per_month}) / COUNT(distinct ${full_visitor_id_per_month})));;
    #sql: IF(${visitors_trend_month_avg} = 0, 0, ${visits_trend_month_avg} / ${visitors_trend_month_avg});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly visits per visitor in the selected period. [MHAI000288]"
    hidden: yes
  }

  measure: views_per_viewer_trend_month_avg {
    label: "Views per Viewer (month avg) (DEPR)"
    type:  number
    value_format: "0.##"
    sql: IF(COUNT(distinct ${video_viewer_id_per_month}) = 0, 0, (COUNT(distinct ${video_play_id_per_month}) / COUNT(distinct ${video_viewer_id_per_month})));;
    #sql: IF(${viewers_trend_month_avg} = 0, 0, (COUNT(distinct ${video_play_id_per_month})) / COUNT(distinct ${view_date_month}) / ${viewers_trend_month_avg});;
    group_label: "[Deprecated]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly views per viewer in the selected period. [MHAI000287]"
    hidden: yes
  }

  measure: total_time_watched_trend_month_avg {
    label: "Total Time Watched (min) (month avg)"
    type:  number
    value_format: "#,##0.00"
    sql: ${total_time_watched_minutes} / COUNT(distinct ${view_date_month});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly total time watched in the selected period. [MHAI000289]"
    hidden: no
  }

  measure: total_time_spent_trend_month_avg {
    label: "Total Time Spent (min) (month avg)"
    type:  number
    value_format: "#,##0.00"
    sql: ${total_time_spent_owned_minutes} / COUNT(distinct ${view_date_month});;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly total time spent in the selected period. [MHAI000290]"
    hidden: no
  }

  measure: average_time_watched_per_view_trend_month_avg {
    label: "Avg. Time Watched per View (min) (month avg)"
    type:  number
    value_format: "#,##0.00"
    sql: IF ((COUNT(distinct ${video_play_id_per_month}) + ${calculated_views}) =0,0, ${total_time_watched_minutes}/(COUNT(distinct ${video_play_id_per_month}) + ${calculated_views}));;
    group_label: "[Trend Metrics]"
    view_label: "RBMH Performance"
    description: "It indicates the average monthly time watched per view in the selected period. [MHAI000291]"
    hidden: no
  }

# ------------- ADMIN -------------

  dimension: cd124_device_platform {
    label: "GA Device Platform"
    type: string
    sql: ${TABLE}.cd124_device_platform ;;
    group_label: "[Admin]"
    hidden: yes
  }




}
