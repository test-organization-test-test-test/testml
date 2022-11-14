#connection: "rbmh_emo_bi" old connection
connection: "tray_pemobi_looker"
#connection: "tray_pemobi_looker_staging"
label: "PEMO BI"

include: "/performance_v3/*.view.lkml"                # include all views in the views/ folder in this project
#include: "/performance_v3/*.dashboard.lookml"
# include: "/**/view.lkml"                   # include all views in this project
# include: "my_dashboard.dashboard.lookml"   # include a LookML dashboard called my_dashboard

# # Select the views that should be a part of this model,
# # and define the joins that connect them together.
#include: "*.dashboard.lookml"

explore: general_performance {
  label: "PEMO BI - Performance V3"
  always_filter: {
    filters:[general_performance.date_filter: "7 days ago for 7 days",
      general_performance.platform: "Owned, Instagram, Facebook, Twitter, Twitch, YouTube, TikTok", general_performance.is_rbmn: "yes" ]
  }
}

explore: country_mapping_suggestions {hidden: yes}
explore: playground_mapping_suggestions {hidden: yes}
explore: iml_mapping_suggestions {hidden: yes}
explore: lsc_metadata_suggestions {hidden: yes}
explore: device_mapping_suggestions {hidden: yes}
explore: crepo_metadata_suggestions {hidden: yes}
explore: metadata_suggestions {hidden: yes}
explore: video_title_metadata_suggestions {hidden: yes}


# hardcoded filter:
# platform, platform_overall, video_stream_type
