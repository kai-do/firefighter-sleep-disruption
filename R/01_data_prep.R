library(dotenv)
library(tidyverse)
library(lubridate)
library(digest)
library(stringr)

load_dot_env()
raw_path <- Sys.getenv("FIRE_RAW_DATA")
set.seed(343)

cad_unit_responses_df <- read.csv(file.path(raw_path, "cad_unit_responses.csv"), na.strings = "NULL") %>%
  filter(str_detect(tolower(callsign), 'metro|puck|care|batt', negate = TRUE)) # remove ambulances, cares units, and battalion trucks

incidents_by_type_df <- read.csv(file.path(raw_path, "incidents_by_type.csv"), na.strings = "NULL")

incident_unit_responses_df <- inner_join(incidents_by_type_df, cad_unit_responses_df, relationship = 'many-to-many') %>%
  mutate(station = as.integer(str_extract(callsign, '[0-9]+')),
         station = case_when(station >= 60 ~ 17, 
                             TRUE ~ station),
         unit_type = as.factor(str_extract(callsign, '[^0-9]+')),
         dispatch_dt = ymd_hms(dispatch_dt),
         enroute_dt = ymd_hms(enroute_dt),
         arrival_dt = ymd_hms(arrival_dt),
         clear_dt = ymd_hms(clear_dt)) %>%
  filter(!is.na(unit_type), !is.na(station), between(station, 1, 30)) # remove uncommon units that have out of range station identifiers and uncommon specialty units


# Anonymize stations

station_mapping_df <- incident_unit_responses_df %>% distinct(station)

station_mapping_df$station_id <- sapply(station_mapping_df$station, digest, algo = 'md5')

station_mapping_df <- station_mapping_df %>%
  arrange(station_id) 

station_mapping_df$station_id <- (1:length(unique(incident_unit_responses_df$station))) + 100

incident_number_mapping_df <- incident_unit_responses_df %>% distinct(incident_number)
  
incident_number_mapping_df$incident_id <- sapply(incident_number_mapping_df$incident_number, digest, algo = 'md5')

start_time <- hms('22:00:00')
end_time <- hms('06:00:00')

incident_unit_responses_anon_df <- inner_join(incident_unit_responses_df, incident_number_mapping_df) %>%
  inner_join(station_mapping_df) %>%
  transmute(incident_id, 
            incident_type = as.factor(incident_type), 
            incident_type_code = as.factor(incident_type_code), 
            station_id = as.factor(station_id),
            unit_type = as.factor(unit_type),
            dispatch_hour = hms(paste0(hour(dispatch_dt), ":", minute(dispatch_dt), ":", second(dispatch_dt))),
            clear_hour = hms(paste0(hour(clear_dt), ":", minute(clear_dt), ":", second(clear_dt))),
            dispatch_dt, enroute_dt, arrival_dt, clear_dt,
            cancelled_before_enroute_flag = case_when(is.na(enroute_dt) & is.na(arrival_dt) ~ TRUE, TRUE ~ FALSE),
            cancelled_enroute_flag = case_when(!is.na(enroute_dt) & is.na(arrival_dt) ~ TRUE, TRUE ~ FALSE),
            turnout_time = difftime(enroute_dt, dispatch_dt),
            travel_time = difftime(arrival_dt, enroute_dt),
            enroute_to_clear_time = difftime(clear_dt, enroute_dt),
            scene_time = difftime(clear_dt, arrival_dt),
            commit_time = difftime(clear_dt, dispatch_dt),
            night_call_flag = dispatch_hour >= start_time | dispatch_hour <= end_time | clear_hour >= start_time | clear_hour <= end_time)

saveRDS(incident_unit_responses_anon_df, './datasets/incident_unit_responses.rds')
