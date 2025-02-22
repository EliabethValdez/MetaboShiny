# triggers when a plotly plot is clicked by user
shiny::observeEvent(plotly::event_data("plotly_click", priority = "event"), {
  
  d <<- plotly::event_data("plotly_click", priority = "event") # get click details (which point, additional included info, etc...
  
  for(pietype in c("add", "iso", "db")){
    try({
      if(input$tab_search == "match_filters_tab" & input$match_filters == paste0("pie_",pietype)){
        i = d$pointNumber + 1
        showsubset = as.character(pieinfo[[pietype]]$Var.1[i])
        print(showsubset)
        mzMode =if(grepl(my_selection$mz, pattern = "-")) "negative" else "positive"
        if(pietype == "add"){
          if(!(showsubset %in% result_filters$add[[mzMode]])){
            result_filters$add[[mzMode]] <- c(result_filters$add[[mzMode]], showsubset)
          }else{
            curr_filt = result_filters$add[[mzMode]]
            result_filters$add[[mzMode]] <- curr_filt[curr_filt != showsubset]
            }
        }else{
          if(!(showsubset %in% result_filters[[pietype]])){
            result_filters[[pietype]] <- c(result_filters[[pietype]], showsubset)
          }else{
            curr_filt = result_filters[[pietype]]
            result_filters[[pietype]] <- curr_filt[curr_filt != showsubset]  
          }
        }
        print(reactiveValuesToList(result_filters))
        search$go <- T
      }
    }, silent = F)
  }
  
  curr_tab <- input$statistics
  
  if(curr_tab %in% c("tt", 
                     "pca",
                     "heatmap",
                     "ml",
                     "plsda", 
                     "fc", 
                     "rf", 
                     "aov", 
                     "corr",
                     "volcano",
                     "network",
                     "enrich",
                     "venn",
                     "meba",
                     "combi",
                     "asca")){ 
    
    if(curr_tab == "ml" & input$ml_results == "roc"){
      
      if(!is.null(d$key)){
        test_set = trimws(gsub("-.*$", "", d$key))
        threshold = trimws(gsub(".*Cutoff:", "", d$key))
        
        # get test set
        
        data = mSet$analSet$ml[[mSet$analSet$ml$last$method]][[mSet$analSet$ml$last$name]]
        if(!is.null(data$res$prediction)){
          data$res$shuffled = FALSE
          data$res = list(data$res)
        }
        xvals = data$res[[which(unlist(sapply(data$res, function(x) !x$shuffled)))]]
        
        probsTest <- xvals$prediction
        lbl = xvals$labels
        
        otherClass = setdiff(colnames(probsTest), input$ml_plot_posclass)
        pred <- factor(ifelse(probsTest[, input$ml_plot_posclass] > threshold, 
                              input$ml_plot_posclass, otherClass))
        conf = caret::confusionMatrix(pred, lbl)
        output$conf_matr_plot <- shiny::renderPlot({
          fourfoldplot(conf$table, color = c("#3399FF",
                                             "#FF6666"),
                       conf.level = 0, margin = 1, main=d$key,
                       ) +
            text(-0.18,0.15, "TN", cex=1.3) + 
            text(0.18, -0.15, "TP", cex=1.3) + 
            text(0.18,0.15, "FN", cex=1.3) + 
            text(-0.18, -0.15, "FP", cex=1.3)
        })  
      }
      
    }else{
      if(curr_tab %in% c("heatmap", "enrich","venn","network")){
        switch(curr_tab,
               heatmap = {
                 if(!is.null(d$y)){
                   if(d$y > length(lcl$vectors$heatmap)) return(NULL)
                   my_selection$mz <<- lcl$vectors$heatmap[d$y]  
                   plotmanager$make <- "summary"
                 }
               },
               network = {
                 if(!is.null(d$y)){
                   if(d$y > length(lcl$vectors$network_heatmap)) return(NULL)
                   my_selection$mz <<- lcl$vectors$network_heatmap[d$y]  
                   plotmanager$make <- "summary"
                 }
               },
               enrich = {
                 curr_pw <- rownames(enrich$overview)[d$pointNumber + 1]
                 pw_i <- which(mSet$analSet$enrich$path.nms == curr_pw)
                 cpds = unlist(mSet$analSet$enrich$path.hits[[pw_i]])
                 hit_tbl = data.table::as.data.table(mSet$analSet$enrich$mumResTable)
                 myHits <- hit_tbl[Matched.Compound %in% unlist(cpds)]
                 myHits$Mass.Diff <- as.numeric(myHits$Mass.Diff)/(as.numeric(myHits$Query.Mass)*1e-6)
                 colnames(myHits) <- c("rn", "identifier", "adduct", "dppm")
                 enrich$current <- myHits
               },
               venn = {
                 if("key" %in% colnames(d)){
                   picked_intersection = d$key[[1]]
                   groups = stringr::str_split(picked_intersection, "<br />")[[1]]
                   shiny::updateSelectInput(session = session, 
                                            inputId = "intersect_venn", 
                                            selected = groups)   
                 }
               })
      }else{
        if('key' %not in% colnames(d)) return(NULL)
        #if(gsub(d$key[[1]],pattern="`",replacement="") %not in% colnames(mSet$dataSet$proc)) return(NULL)
        my_selection$mz <<- gsub(d$key[[1]],pattern="`",replacement="")
        plotmanager$make <- "summary"
      }
    }
  }
})

shiny::observeEvent(input$network_interactive_selected, {
  my_selection$mz <<- input$network_interactive_selected
  plotmanager$make <- "summary"
})
