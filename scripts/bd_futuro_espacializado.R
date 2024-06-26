# Calculating BD aggregated value for future scenarios (restor. weight) --------
# use mult_exrik_aggregate do perfil do luga!! e copiar 
# Libraries

# obs: os deltas de rest na verdade tem valores negativos e positivos; isso deve estar certo! mas conferir!


library(devtools)
library(raster)

#devtools::load_all("/dados/pessoal/luga/dev/plangea-pkg/")

# Scenarios combinations
gcms = c("bc", "ca", "cm", "cn", "gf", "ip", "mi", "mr", "ms")
#gcms= gcms[1:8]
# excluir ms por enquanto!

# regions = c("CAN", "CSI", "EAS", "EUR", "LAC", "MNA", "OCE", "SAS", "SEA", "SSA", "USA")

scens <- list.files("/dados/projetos_andamento/TRADEhub/trade_hub_plangea/rawdata/land-use-2050")

# Folder structure to load files and results table
res_tbl = expand.grid(gcms, scens)
names(res_tbl) = c("gcms",  "scens")
#res_tbl$bd_agg = NA

# Input data
# x_vals_folder = "/dados/projetos_andamento/TRADEhub/trade_hub_plangea/restoration_transitions/Deltas/delta_rest"
x_vals_folder = "/dados/projetos_andamento/TRADEhub/trade_hub_plangea/global"
hab_now_folder = "/dados/projetos_andamento/TRADEhub/trade_hub_plangea/global_climate_hab_now/"
hab_pot_folder = "/dados/projetos_andamento/TRADEhub/trade_hub_plangea/global_climate_hab_pot/"

# funcao modificada

source("/dados/pessoal/francisco/TradeHub/scripts/multi_exrisk_aggregate_mod.R")

base_ras <- raster("/dados/projetos_andamento/TRADEhub/trade_hub_plangea/rawdata/variables/ecoregions_2017_1000m_moll_resampled_50km.tif")

# Parallelism setup
num_clusters = 60
cl = snow::makeCluster(num_clusters, outfile = '/dev/null')
doSNOW::registerDoSNOW(cl)

# Setting up the progress bar
iterations = nrow(res_tbl)

# Progress bar object
pb_l = progress::progress_bar$new(
  format = "Loading scenario [:bar] :percent in :elapsed",
  total = iterations, clear = FALSE, width = 70)

progress_number = 1:iterations
progress = function(n) {pb_l$tick(tokens = list(sp = progress_number[n]))}
opts = list(progress = progress)

# Looping over all combinations

#results_list <- list()

# bd_agg_vec = foreach(row_n = 1:nrow(res_tbl),
#                      .combine = 'c',
#                      .packages = c('devtools', 'progress',"raster"),
#                      .options.snow = opts,
#                      .errorhandling = "remove") %dopar% {
for (row_n in 1:nrow(res_tbl)) {
  
  suppressWarnings(suppressMessages(devtools::load_all("/dados/pessoal/luga/dev/plangea-pkg/", quiet = TRUE)))
  
  # Reading line of the table
  row_vals = res_tbl[row_n,]
  
  # Reading required objects
  in_data = aux_load(paste0(hab_now_folder, row_vals$gcms, "/", row_vals$scens, "/processed/harmonize_full_envir.qs"))
  hab_pot_areas = aux_load(paste0(hab_pot_folder, row_vals$scens, "/processed/harmonize_full_envir.qs"))$hab_pot_areas
  #x_vals = aux_load_raster(paste0(x_vals_folder,"/delta_rest_", row_vals$scens, ".tif"), in_data$master_index)
  x_vals = aux_load(paste0(x_vals_folder,"/globiom_iiasa_",row_vals$scens, "/results/solver_runs/", 'solver_future_land_use'))
  
  result = multi_exrisk_aggregate_mod(x_vals = x_vals, prop_restore = in_data$prop_restore, usphab_proc = in_data$usphab_proc, usphab_index = in_data$usphab_index, hab_now_areas = in_data$hab_now_areas,hab_pot_areas = hab_pot_areas, spp_main_range = in_data$spp_main_range,master_index = in_data$master_index,use_restor_weight = T)
  
  raster_resultado = 0* base_ras
  raster_resultado[in_data$master_index] = result 
  scen_nm <- res_tbl[row_n,2]
  gc_nm <- res_tbl[row_n,1]
  #results_list[row_n] <-  raster_resultado   
  raster::writeRaster(x = raster_resultado,paste0("/dados/projetos_andamento/TRADEhub/trade_hub_plangea/bd_future_per_clim_env/",scen_nm,"_",gc_nm,".tif"),overwrite=T)
  #print(row_n)
  #return(results_list)
  
}


# Stop the parallel cluster
stopCluster(cl)

# # Verifying existence of input data for each row
# in_datas = paste0(hab_now_folder, res_tbl$gcms, "/", res_tbl$scens, "/processed/harmonize_full_envir.qs")
# 
# hab_pots = paste0(hab_pot_folder, res_tbl$scens, "/processed/harmonize_full_envir.qs")
# 
# # Excluded rows: input data is not present
# exc_rows = unique(c(which(!file.exists(in_datas)), which(!file.exists(hab_pots))))


# Excluding those lines from original table
#res_tbl = res_tbl[-exc_rows,]

# # Adding results to the final table
# res_tbl[, "bd_agg"] = bd_agg_vec




# avg_bd <- res_tbl%>%
#   group_by(scens)%>%
#   summarise(mean_bd=mean(bd_agg))
# 
# # media da lista de resultados! mas precisava ser por scenario, merda.
# # talvez pela ordem de pra fazer.
# 
# 
# write.csv(avg_tbl,"/dados/pessoal/francisco/TradeHub/output_tables/updated_results/agg_bd_climate_env_global.csv",row.names = F)
