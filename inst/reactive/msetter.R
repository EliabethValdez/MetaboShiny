shiny::observe({
  
  if(is.null(mSetter$do)){
    
    NULL # if not subsetting anything, nevermind
    
  }else if(!is.null(mSetter$do)){
    
    if(!is.null(mSet)){
      
      try({
        mSet <- store.mSet(mSet, proj.folder = file.path(lcl$paths$work_dir,
                                                         lcl$proj_name)) # save analyses
        success = F
        
        if("load" %in% mSetter$do){
           # more mem friendly??
          mSet <- load.mSet(mSet, 
                            input$storage_choice, 
                            proj.folder = file.path(lcl$paths$work_dir,
                                                    lcl$proj_name))
        }else{
          
          oldSettings <- mSet$settings

          mSet <- reset.mSet(mSet,
                             fn = file.path(lcl$paths$proj_dir, 
                                            paste0(lcl$proj_name,
                                                   "_ORIG.metshi")))
          
          orig.count <- mSet$metshiParams$orig.count
          
          if(!("unsubset" %in% mSetter$do)){
            mSet.settings <- if("load" %in% mSetter$do) mSet$storage[[input$storage_choice]]$settings else oldSettings
            if(length(mSet.settings$subset) > 0){
              subs = mSet.settings$subset
              subs = subs[!(names(subs) %in% c("sample", "mz"))]
              if(length(subs) > 0){
                for(i in 1:length(subs)){
                  mSet <- subset_mSet(mSet, 
                                      subset_var = names(subs)[i], 
                                      subset_group = subs[[i]])  
                }  
              }
            }
          }else{
            mSet.settings <- oldSettings
          }
          
          mSet$settings <- mSet.settings
          
          if("refresh" %in% mSetter$do | 
             "load" %in% mSetter$do | 
             "subset" %in% mSetter$do | 
             "subset_mz" %in% mSetter$do | 
             "unsubset" %in% mSetter$do){
            mSet$dataSet$ispaired <- mSet.settings$ispaired
          }
          if("change" %in% mSetter$do){
            mSet$dataSet$ispaired <- if(input$stats_type %in% c("t", "t1f") | input$paired) TRUE else FALSE 
          }
          if("subset_mz" %in% mSetter$do){
            if(input$subset_mzs == "prematched"){
              keep.mzs = get_prematched_mz(patdb = lcl$paths$patdb,
                                           mainisos = input$subset_mz_iso)
            }
            mSet <- subset_mSet_mz(mSet,
                                   keep.mzs = keep.mzs)
          }
          if("subset" %in% mSetter$do){
            mSet <- subset_mSet(mSet,
                                subset_var = input$subset_var, 
                                subset_group = input$subset_group)
          }
          if("unsubset" %in% mSetter$do){
            mSet$settings$subset <- list()
          }
          
          mSet$analSet <- list(type = "stat")
          mSet$analSet$type <- "stat"
          
          if("change" %in% mSetter$do){
            if(input$omit_unknown & grepl("^1f", input$stats_type)){
              shiny::showNotification("omitting 'unknown' labeled samples...")
              knowns = mSet$dataSet$covars$sample[which(mSet$dataSet$covars[ , input$stats_var, with=F][[1]] != "unknown")]
              if(length(knowns) > 0){
                mSet <- subset_mSet(mSet,
                                    subset_var = "sample", 
                                    subset_group = knowns) 
              }
            }else{
              knowns = mSet$dataSet$covars$sample
            }
            mSet <- change.mSet(mSet, 
                                stats_var = input$stats_var, 
                                stats_type = input$stats_type, 
                                time_var = input$time_var)
          }else{
            if(input$omit_unknown & grepl("^1f", mSet$settings$exp.type)){
              shiny::showNotification("omitting 'unknown' labeled samples...")
              knowns = mSet$dataSet$covars$sample[which(mSet$dataSet$covars[ , mSet$settings$exp.var, with=F][[1]] != "unknown")]
              if(length(knowns) > 0){
                mSet <- subset_mSet(mSet,
                                    subset_var = "sample", 
                                    subset_group = knowns) 
              }
            }else{
              knowns = mSet$dataSet$covars$sample
            }
            mSet <- change.mSet(mSet, 
                                stats_var = mSet.settings$exp.var, 
                                time_var =  mSet.settings$time.var,
                                stats_type = mSet.settings$exp.type)
          }
          
          samps = mSet$dataSet$covars$sample
          # CHECK IF DATASET WITH SAME SAMPLES ALREADY THERE
          matching.samps = sapply(mSet$storage, function(saved){
            samplist = saved$samples
            if(length(samps) == length(samplist)){
              all(knowns == samplist)  
            }else{
              F
            }
          })
          
          if(!("renorm" %in% names(mSet$metshiParams))){
            mSet$metshiParams$renorm <- TRUE
          }
          
          # === PAIR ===
          
          if(mSet$dataSet$ispaired){
            print("Paired analysis a-c-t-i-v-a-t-e-d")
            mSet$settings$ispaired <- TRUE
            mSet <- pair.mSet(mSet)
          }else{
            mSet.settings$ispaired <- FALSE
          }
          
          # ============
          already.normalized = any(matching.samps) & oldSettings$ispaired == input$paired
          
          if(already.normalized){
            tables = c("orig", "norm", "proc", "prebatch", "covars")
            print("recycling from another meta-dataset!")
            use.dataset = names(which(matching.samps))[1]
            use.dataset = gsub(pattern = "[^\\w]", replacement = "_", x = use.dataset, perl = T)
            recycle.mSet = qs::qread(file.path(lcl$paths$work_dir,
                                               lcl$proj_name,
                                               paste0(use.dataset, ".metshi")))
            for(tbl in tables){
              mSet$dataSet[[tbl]] <- recycle.mSet$dataSet[[tbl]]
            }
            mSet$report <- recycle.mSet$report
          }else{
            if(mSet$metshiParams$renorm){
              mSet$dataSet$orig <- mSet$dataSet$start
              mSet$dataSet$start <- mSet$dataSet$preproc <- mSet$dataSet$proc <- mSet$dataSet$prenorm <- NULL
              mSet <- metshiProcess(mSet, cl = session_cl) #mSet1
            }  
          }
          
          new.name = if(mSetter$do == "load") input$storage_choice else name.mSet(mSet)
          
          if(new.name %in% names(mSet$storage)){
            mSet <- load.mSet(mSet, 
                              new.name, 
                              proj.folder = lcl$paths$proj_dir)
          }
          
          mSet$settings$cls.name <- new.name
          
          if(grepl(mSet$settings$exp.type, pattern = "^1f")){
            if(mSet$dataSet$cls.num == 2){
              mSet$settings$exp.type <- "1fb"
            }else{
              mSet$settings$exp.type <- "1fm"
            }  
          }
        }   
        success=T
      })
      
      if(success){
        if(is.ordered.mSet(mSet)){
          msg = "mSet class label order still correct! :)"
          try({
            shiny::showNotification(msg) 
          })
          print(msg)
          mSet <<- mSet
          lcl$has_changed <<- TRUE
          uimanager$refresh <- c("general", "ml")
        }else{
          msg = "mSet class label order incorrect! Restoring... :("
          try({
            shiny::showNotification(msg)
          })
          print(msg)
        }
      }else{
        metshiAlert("Failed! Restoring old mSet...")
      }
      mSetter$do <- NULL
    }
  }
})