FilterVariableMetshi <- function (mSetObj = NA, filter, qcFilter, rsd, max.allow = 20000) 
{
  mSetObj <- MetaboAnalystR:::.get.mSet(mSetObj)
  mSetObj$dataSet$filt <- mSetObj$dataSet$prenorm <- NULL
  int.mat <- as.matrix(mSetObj$dataSet$orig)
  cls <- sapply(mSetObj$dataSet$covars$sample, function(samp) if(grepl("QC", tolower(samp))) "qc" else "normal")
  msg <- ""
  if (qcFilter == "T") {
    rsd <- rsd/100
    qc.hits <- tolower(as.character(cls)) %in% "qc"
    if (sum(qc.hits) > 2) {
      qc.mat <- int.mat[qc.hits, ]
      sds <- apply(qc.mat, 2, sd, na.rm = T)
      mns <- apply(qc.mat, 2, mean, na.rm = T)
      rsd.vals <- abs(sds/mns)
      gd.inx <- rsd.vals < rsd
      int.mat <- int.mat[, gd.inx]
      msg <- paste("Removed ", sum(!gd.inx), " features based on QC RSD values. QC samples are still kept. You can remove them later.")
    }
    else if (sum(qc.hits) > 0) {
      MetaboAnalystR::AddErrMsg("RSD requires at least 3 QC samples, and only non-QC based filtering can be applied.")
      return(0)
    }
    else {
      MetaboAnalystR::AddErrMsg("No QC Samples (with class label: QC) found.  Please use non-QC based filtering.")
      return(0)
    }
  }
  feat.num <- ncol(int.mat)
  feat.nms <- colnames(int.mat)
  nm <- NULL
  if (filter == "none" && feat.num < 5000) {
    remain <- rep(TRUE, feat.num)
    msg <- paste(msg, "No non-QC based data filtering was applied")
  }
  else {
    if (filter == "rsd") {
      sds <- apply(int.mat, 2, sd, na.rm = T)
      mns <- apply(int.mat, 2, mean, na.rm = T)
      filter.val <- abs(sds/mns)
      nm <- "Relative standard deviation"
    }
    else if (filter == "nrsd") {
      mads <- apply(int.mat, 2, mad, na.rm = T)
      meds <- apply(int.mat, 2, median, na.rm = T)
      filter.val <- abs(mads/meds)
      nm <- "Non-paramatric relative standard deviation"
    }
    else if (filter == "mean") {
      filter.val <- apply(int.mat, 2, mean, na.rm = T)
      nm <- "mean"
    }
    else if (filter == "sd") {
      filter.val <- apply(int.mat, 2, sd, na.rm = T)
      nm <- "standard deviation"
    }
    else if (filter == "mad") {
      filter.val <- apply(int.mat, 2, mad, na.rm = T)
      nm <- "Median absolute deviation"
    }
    else if (filter == "median") {
      filter.val <- apply(int.mat, 2, median, na.rm = T)
      nm <- "median"
    }
    else {
      filter.val <- apply(int.mat, 2, IQR, na.rm = T)
      nm <- "Interquantile Range"
    }
    rk <- rank(-filter.val, ties.method = "random")
    var.num <- ncol(int.mat)
    if (var.num < 250) {
      remain <- rk < var.num * 0.95
      msg <- paste(msg, "Further feature filtering based on", 
                   nm)
    }
    else if (ncol(int.mat) < 500) {
      remain <- rk < var.num * 0.9
      msg <- paste(msg, "Further feature filtering based on", 
                   nm)
    }
    else if (ncol(int.mat) < 1000) {
      remain <- rk < var.num * 0.75
      msg <- paste(msg, "Further feature filtering based on", 
                   nm)
    }
    else {
      remain <- rk < var.num * 0.6
      msg <- paste(msg, "Further feature filtering based on", 
                   nm)
      #max.allow <- 5000
      if (mSetObj$analSet$type == "power") {
        #max.allow <- 2500
        max.allow <- max.allow / 2
      }
      if (sum(remain) > max.allow) {
        remain <- rk < max.allow
        msg <- paste(msg, paste("Reduced to", max.allow, 
                                "features based on", nm))
      }
    }
  }
  mSetObj$dataSet$filt <- int.mat[, remain]
  mSetObj$msgSet$filter.msg <- msg
  MetaboAnalystR:::AddMsg(msg)
  return( MetaboAnalystR:::.set.mSet(mSetObj))
}

#' @title Check if mSet sample order in peaktable data and metadata are the same
#' @param mSet mSet object
#' @return TRUE/FALSE
#' @rdname is.ordered.mSet
#' @export 
is.ordered.mSet <- function(mSet) {
  covarsMatch = all(mSet$dataSet$covars$sample == rownames(mSet$dataSet$norm))
  exp.type <-
    gsub("^1f.",  "1f", mSet$settings$exp.type)
  expVarsMatch <- switch(
   exp.type,
    "1f" = {
      all(mSet$dataSet$cls == mSet$dataSet$covars[, mSet$settings$exp.fac, with =
                                                    F][[1]])
    },
    "2f" = {
      all(
        mSet$dataSet$facA == mSet$dataSet$covars[, mSet$dataSet$facA.lbl, with =
                                                   F][[1]] &&
          mSet$dataSet$facB == mSet$dataSet$covars[, mSet$dataSet$facB.lbl, with =
                                                     F][[1]]
      )
    },
    "t" = {
      all(
        mSet$dataSet$exp.fac == mSet$dataSet$covars$individual &&
          mSet$dataSet$time.fac == mSet$dataSet$covars[, mSet$dataSet$facA.lbl.orig, with = 
                                                         F][[1]] && 
          mSet$dataSet$facA == mSet$dataSet$time.fac
      )
    },
    "t1f" = {
      all(
        mSet$dataSet$exp.fac == mSet$dataSet$covars[, mSet$dataSet$facA.lbl, with =
                                                      F][[1]] &&
          mSet$dataSet$time.fac == mSet$dataSet$covars[, mSet$dataSet$facB.lbl, with =
                                                         F][[1]]
        &&
          mSet$dataSet$facB == mSet$dataSet$time.fac &&
          mSet$dataSet$facA == mSet$dataSet$covars[, mSet$dataSet$facA.lbl, with =
                                                     F][[1]]
        &&
          mSet$dataSet$facB == mSet$dataSet$covars[, mSet$dataSet$facB.lbl, with =
                                                     F][[1]]
      )
    }
  )
  isOK <- covarsMatch & expVarsMatch
  return(isOK)
}

#' @title Generate mSet name
#' @description For MetShi display purposes. Takes subset and selected variable(s) to generate a name for this subexperiment.
#' @param mSet mSet object
#' @return character object
#' @rdname name.mSet
#' @export 
name.mSet <- function(mSet) {
  info_vec = c()
  if (mSet$settings$exp.type %in% c("t1f", "t")) {
    info_vec = c("timeseries")
  } else if (mSet$settings$ispaired) {
    info_vec = c(info_vec, "paired")
  }
  
  if("mz" %in% names(mSet$settings$subset)){
    info_vec = c(info_vec, "prematched m/z only")
  }
  
  if (length(mSet$settings$subset) > 0) {
    subsetgroups = sapply(1:length(mSet$settings$subset), function(i) {
      if (names(mSet$settings$subset)[i] %in% c("sample", "mz")) {
        NULL
      } else{
        paste0(
          names(mSet$settings$subset)[i],
          "=",
          paste0(mSet$settings$subset[[i]], collapse = "+")
        )
      }
    })
  } else{
    subsetgroups = NULL
  }
  
  subsetgroups <- unlist(subsetgroups)
  
  if (length(info_vec) > 0) {
    extra_info <- paste0("(", paste0(info_vec, collapse = " & "), ")")
  } else{
    extra_info <- ""
  }
  
  if (grepl(mSet$settings$exp.type, pattern = "^1f")) {
    mSet$settings$exp.type <- "1f"
  }
  
  prefix.name <- switch(
    mSet$settings$exp.type,
    "1f" = {
      change_var <-
        if (length(mSet$settings$exp.var) > 1)
          mSet$settings$exp.var[1]
      else
        mSet$settings$exp.var
      change_var
    },
    "2f" = {
      # facB should be time if it is there...
      time.check = grepl("time", mSet$settings$exp.var)
      is.time = any(time.check)
      if (is.time) {
        print("time series potential")
        idx2 = which(time.check)
        idx1 = setdiff(c(1, 2), idx2)
      } else{
        idx1 = 1
        idx2 = 2
      }
      paste0(mSet$settings$exp.var[c(idx1, idx2)], collapse =
               "+")
    },
    "t" = {
      "time"
    },
    "t1f" = {
      change_var <-
        if (length(mSet$settings$exp.var) > 1)
          mSet$settings$exp.var[1]
      else
        mSet$settings$exp.var
      change_var
    }
  )
  mset_name = paste0(prefix.name, extra_info,
                     if (!is.null(subsetgroups))
                       tolower(paste0(":", subsetgroups, collapse = ","))
                     else
                       "")
  mset_name
}

#' @title Reset mSet to original post-normalization format
#' @description Returns mSet to right after normalization, without subsetting or changing the default variable.
#' @param mSet mSet object
#' @param fn filename to load in
#' @return mSet object
#' @rdname reset.mSet
#' @export 
reset.mSet <- function(mSet_new, fn) {
  mSet <- tryCatch({
    load(fn)
    mSet
  },
  error = function(cond){
    mSet <- qs::qread(fn)
    mSet
  })
  mSet_new$dataSet <- mSet$dataSet
  mSet_new$analSet <- mSet$analSet
  mSet_new$settings <- mSet$settings
  mSet_new$report <- mSet$report
  return(mSet_new)
}

#' @title Load mSet from mSet internal storage
#' @description MetShi mSets store previous dataset results and settings in the mSet storage. This loads one of those datasets.
#' @param mSet mSet object
#' @param name Name of subexperiemnt to load, Default: mSet$dataSet$cls.names
#' @return mSet object
#' @rdname load.mSet
#' @export 
load.mSet <- function(mSet, name = mSet$dataSet$cls.name, proj.folder) {
  name = gsub(pattern = "[^\\w]", replacement = "_", x = name, perl = T)
  fn = file.path(proj.folder, paste0(name, ".metshi"))
  print(paste("loading mset:", fn))
  mSet.loaded = qs::qread(fn)
  mSet$dataSet <- mSet.loaded$dataSet
  mSet$analSet <- mSet.loaded$analSet
  mSet$settings <- mSet.loaded$settings
  mSet$report <- mSet.loaded$report
  return(mSet)
}

# setwd(proj.folder)
# for(metshi in list.files(proj.folder)){
#   ext = ".metshi"
#   bn = basename(metshi)
#   name = gsub("\\.metshi$", "", bn)
#   name = gsub(pattern = "[^\\w]", replacement = "_", x = name, perl = T)
#   fixed.name = paste0(name, ".metshi")
#   print(bn)
#   print(fixed.name)
#   from.file = file.path(proj.folder, bn)
#   to.file = file.path(proj.folder, fixed.name)
#   print(from.file)
#   print(to.file)
#   if(bn != fixed.name){
#     went.ok = file.rename(from = from.file,
#                           to = to.file)
#     print(went.ok)   
#   }
# }

#' @title Store mSet analysis and settings in mSet internal storage
#' @description MetShi mSets store previous dataset results and settings in the mSet storage. This saves the current mSet in there.
#' @param mSet mSet object
#' @param name PARAM_DESCRIPTION, Default: mSet$dataSet$cls.name
#' @return Name of current subexperiment
#' @rdname store.mSet
#' @export
store.mSet <- function(mSet, name = mSet$settings$cls.name, proj.folder){

  mSet$storage[[name]] <- list(samples = rownames(mSet$dataSet$norm),
                               settings = mSet$settings,
                               analSet =  mSet$analSet)
  # qs save
  save.item = mSet
  save.item$storage <- NULL
  name = gsub(pattern = "[^\\w]", replacement = "_", x = name, perl = T)
  fn = file.path(proj.folder, paste0(name, ".metshi"))
  print(paste("storing mset as:", fn))
  print(fn)
  ## MORE MEMORY FRIENDLY ##
  qs::qsave(save.item, fn)
  #try({
    #mSet$storage[[name]]$data <- mSet$dataSet
  #})
  return(mSet)
}

#' @title Change mSet
#' @description Wrapper function to change statistics variable(s) and mode (one/two-factor, time series)
#' @param mSet mSet object
#' @param stats_type Statistics category to change to
#' @param stats_var Metadata variable(s) to do statistics on, Default: NULL
#' @param time_var Metadata variable representing time, Default: NULL
#' @return mSet object
#' @seealso 
#'  \code{\link[shiny]{showNotification}}
#'  \code{\link[MetaboAnalystR]{SetDesignType}}
#' @rdname change.mSet
#' @export 
#' @importFrom shiny showNotification
#' @importFrom MetaboAnalystR SetDesignType
change.mSet <-
  function(mSet,
           stats_type,
           stats_var = NULL,
           time_var = NULL) {
    mSet$settings$exp.type <- stats_type
    mSet$settings$exp.var <- stats_var
    mSet$settings$exp.fac <- stats_var
    mSet$settings$time.var <- time_var
    if (grepl(mSet$settings$exp.type, pattern = "^1f")) {
      mSet$settings$exp.type <- "1f"
    }
    
    mSet <- switch(
      mSet$settings$exp.type,
      "1f" = {
        change_var <- if (length(stats_var) > 1)
          stats_var[1]
        else
          stats_var
        mSet$settings$exp.lbl <- change_var
        # change current variable of interest to user pick from covars table
        mSet$dataSet$cls <- mSet$dataSet$orig.cls <-
          as.factor(mSet$dataSet$covars[, ..change_var, with = F][[1]])
        # adjust bivariate/multivariate (2, >2)...
        mSet$dataSet$cls.num <- mSet$dataSet$orig.cls.num <-
          length(levels(mSet$dataSet$cls))
        # - - -
        mSet
      },
      "2f" = {
        time.check = grepl("time", mSet$settings$exp.var)
        is.time = any(time.check)
        if (is.time) {
          shiny::showNotification("One variable may be time-related. Using for visualisation...")
          idx2 = which(time.check)
          idx1 = setdiff(c(1, 2), idx2)
        } else{
          idx1 = 1
          idx2 = 2
        }
        mSet$dataSet$facA <- mSet$dataSet$facA.orig <-
          as.factor(mSet$dataSet$covars[, stats_var, with = F][[idx1]])
        mSet$dataSet$facB <- mSet$dataSet$facB.orig <-
          as.factor(mSet$dataSet$covars[, stats_var, with = F][[idx2]])
        mSet$dataSet$facA.lbl <- stats_var[idx1]
        mSet$dataSet$facB.lbl <- stats_var[idx2]
        mSet$settings$exp.type <- "2f"
        mSet$settings$exp.lbl <- stats_var
        # - - -
        mSet
      },
      "t" = {
        mSet <- MetaboAnalystR::SetDesignType(mSet, "time0")
        mSet$settings$exp.fac <- mSet$dataSet$exp.fac <-
          as.factor(mSet$dataSet$covars$individual)
        if (!any(duplicated(mSet$dataSet$exp.fac))) {
          metshiAlert(
            "This analysis needs multiple of the same sample in the 'individual' metadata column!"
          )
          return(NULL)
        }
        mSet$settings$exp.lbl <- "sample"
        mSet$settings$time.fac <- mSet$dataSet$time.fac <- as.factor(mSet$dataSet$covars[, time_var, with = F][[1]])
        mSet$settings$exp.type <- "t"
        mSet$dataSet$facA <- mSet$dataSet$facA.orig <- mSet$settings$time.fac
        mSet$dataSet$facA.lbl <- "Time"
        mSet$dataSet$facA.lbl.orig <- time_var
        mSet$settings$ispaired <- TRUE
        mSet$dataSet$ispaired <- T
        
        mSet
      },
      "t1f" = {
        print("time series 1 factor")
        mSet <-
          MetaboAnalystR::SetDesignType(mSet, "time")
        if (!any(duplicated(as.factor(mSet$dataSet$covars$individual)))) {
          metshiAlert(
            "This analysis needs multiple of the same sample in the 'individual' metadata column!"
          )
          return(NULL)
        }
        change_var <-
          if (length(stats_var) > 1)
            stats_var[1]
        else
          stats_var

        mSet$dataSet$facA <- mSet$dataSet$facA.orig <- as.factor(mSet$dataSet$covars[, ..change_var, with = F][[1]])
        mSet$dataSet$facB <- mSet$dataSet$facB.orig <-
          as.factor(mSet$dataSet$covars[, ..time_var, with = F][[1]])
        mSet$dataSet$facA.lbl <- change_var
        mSet$dataSet$facB.lbl <- time_var
        mSet$settings$exp.fac <- mSet$dataSet$exp.fac <- mSet$dataSet$facA
        mSet$settings$time.fac  <- mSet$dataSet$time.fac <- mSet$dataSet$facB
        mSet$settings$exp.type <- "t1f"
        mSet$settings$exp.lbl <- change_var
        mSet$settings$ispaired <- TRUE
        mSet$dataSet$ispaired <- T
        
        # - - -
        mSet
      }
    )
    # - - - - - - - - - -
    mSet$analSet <- list(type = "stat")
    return(mSet)
  }


# subset by mz
subset_mSet_mz <- function(mSet, keep.mzs) {
  if (length(keep.mzs) > 0) {
    tables = c("start", "orig", "norm", "proc","preproc","missing", "prebatch", "prenorm")
    combi.tbl = data.table::data.table(tbl = tables)

    for (i in 1:nrow(combi.tbl)){
      try({
        tbl = combi.tbl$tbl[i]
        # convert back
        if(any(grepl(colnames(mSet$dataSet[[tbl]]), pattern="/"))){
          eachPPM = T
          ppm = ceiling(as.numeric(gsub(colnames(tbl), pattern="^.*/", replacement="")))
          fixedCols = gsub(colnames(mSet$dataSet[[tbl]]), pattern="/.*$", replacement="")
        }else{
          eachPPM = F
          ppm = mSet$ppm
          fixedCols = gsub(colnames(mSet$dataSet[[tbl]]), pattern="RT.*$", replacement="")
        }
        keep = which(fixedCols %in% keep.mzs)
        mSet$dataSet[[tbl]] <- mSet$dataSet[[tbl]][, keep]
        mSet$settings$subset$mz <- keep.mzs
      }, silent = T)
    }
  }
  mSet
}

#' @title Subset mSet
#' @description Subset the current dataset based on metadata variables
#' @param mSet mSet object
#' @param subset_var Metadata variable to subset on
#' @param subset_group Within that variable, the categories to include in subset
#' @return mSet object
#' @rdname subset_mSet
#' @export 
#' @importFrom data.table data.table
subset_mSet <- function(mSet, subset_var, subset_group) {
  if (!is.null(subset_var)) {
    keep.i <- which(mSet$dataSet$covars[[subset_var]] %in% subset_group)
    keep.samples <- mSet$dataSet$covars$sample[keep.i]
    mSet$dataSet$covars <-
      mSet$dataSet$covars[sample %in% keep.samples, ]
    
    tables = c("start", "orig", "norm", "proc","preproc","missing", "prebatch", "prenorm")
    clss = c("placeholder", "orig.cls", "cls", "proc.cls", "preproc.cls", "placeholder", "placeholder", "prenorm.cls")
    combi.tbl = data.table::data.table(tbl = tables,
                                       cls = clss)
    
    if (!("subset" %in% names(mSet$settings))) {
      mSet$settings$subset <- list()
    }
    
    for (i in 1:nrow(combi.tbl)) {
      try({
        tbl = combi.tbl$tbl[i]
        cls = combi.tbl$cls[i]
        keep = which(rownames(mSet$dataSet[[tbl]]) %in% keep.samples)
        
        # if(!(tbl %in% c("start", "missing", "prebatch"))){
        #  NULL 
        # }
        
        mSet$dataSet[[tbl]] <- mSet$dataSet[[tbl]][keep, ]
        # sampOrder = match(rownames(mSet$dataSet[[tbl]]),
        #                   mSet$dataSet$covars$sample)
        # reorder table
        sampOrder = match(
          mSet$dataSet$covars$sample,
          rownames(mSet$dataSet[[tbl]]))
        is_there = tbl %in% names(mSet$dataSet)
        
        if(is_there){
          mSet$dataSet[[tbl]] <- mSet$dataSet[[tbl]][sampOrder, ] #reorder
          
          if(!(tbl %in% c("start", "missing", "prebatch"))){
            mSet$dataSet[[cls]] <-
              as.factor(mSet$dataSet$covars[, mSet$settings$exp.var, 
                                            with = F][[1]])
            if (cls == "cls") {
              mSet$dataSet$cls.num <- length(levels(mSet$dataSet[[cls]]))
              if ("facA" %in% names(mSet$dataSet)) {
                mSet$dataSet$facA <-
                  as.factor(mSet$dataSet$covars[, mSet$dataSet$facA.lbl, with =
                                                  F][[1]])
                mSet$dataSet$facB <-
                  as.factor(mSet$dataSet$covars[, mSet$dataSet$facB.lbl, with =
                                                  F][[1]])
              }
              if ("time.fac" %in% names(mSet$dataSet)) {
                mSet$settings$time.fac <-
                  as.factor(mSet$dataSet$covars[, mSet$settings$time.var, with =
                                                  F][[1]])
                mSet$settings$exp.fac <-
                  as.factor(mSet$dataSet$covars[, mSet$settings$exp.var, with = F][[1]])
              }
            }  
          }  
        }
      }, silent = T)
    }
    mSet$settings$subset[[subset_var]] <- subset_group
  }
  mSet
}

#' @title Pair mSet samples
#' @description Some analyses require paired samples. This function takes care of downsampling to achieve that.
#' @param mSet mSet object
#' @return mSet object
#' @seealso 
#'  \code{\link[data.table]{as.data.table}}
#'  \code{\link[pbapply]{pbapply}}
#'  \code{\link[caret]{downSample}}
#' @rdname pair.mSet
#' @export 
#' @importFrom data.table as.data.table
#' @importFrom pbapply pbsapply
#' @importFrom caret downSample
pair.mSet <- function(mSet) {
  stats_var = mSet$settings$exp.var
  time_var = mSet$settings$time.var
  
  overview.tbl <-
    data.table::as.data.table(
      cbind(
        sample = mSet$dataSet$covars$sample,
        individual = mSet$dataSet$covars$individual,
        variable = as.character(mSet$dataSet$covars[, ..stats_var][[1]])
      ) 
    )
  
  # which samples should we keep?
  # A. which individuals are present multiple times in the dataset?
  indiv.samp <- unique(overview.tbl[, c("individual", "sample")])
  indiv.var <- unique(overview.tbl[, c("individual", "variable")])
  
  indiv.present.multiple <-
    unique(indiv.samp$individual[c(which(duplicated(indiv.samp$individual)))])
  
  # A2: mandatory for time series 1 factor. which individuals remain in the same category?
  indiv.cat.change = indiv.var$individual[c(which(duplicated(indiv.var$individual)))]
  indiv.no.cat.change <-
    setdiff(indiv.present.multiple, indiv.cat.change)
  
  # B: we want to balance the classes...
  # DOWNSAMPLE invidiv
  if (mSet$settings$exp.type == "t1f") {
    indiv.times = unique(data.table::as.data.table(
      cbind(
        individual = mSet$dataSet$covars$individual,
        time = mSet$dataSet$covars[, ..time_var][[1]]
      )
    ))
    indiv.all.times <-
      indiv.times$individual[c(which(duplicated(indiv.times$individual)))]
    # which samples are present
    considerations = list(indiv.present.multiple,
                          indiv.no.cat.change,
                          indiv.all.times)
    times = unique(mSet$dataSet$covars[, ..time_var][[1]])
  } else if (mSet$settings$exp.type == "t") {
    considerations = list(indiv.present.multiple)
    times = unique(mSet$dataSet$covars[, ..time_var][[1]])
  } else{
    considerations = list(indiv.present.multiple, indiv.cat.change)
  }
  
  # C. which individuals do we keep?
  keep.indiv <- Reduce(f = intersect, considerations)
  
  req.groups <- unique(mSet$dataSet$covars[, ..stats_var][[1]])
  time_var = mSet$settings$time.var
  
  keep.samp <- pbapply::pbsapply(keep.indiv, function(indiv) {
    # get samples matching
    # if multiple for each, only pick one
    overv = overview.tbl[individual == indiv]
    if (mSet$settings$exp.type %in% c("t", "t1f")) {
      # all time points need a sample, otherwise nvm (TODO: add a check for if only one sample has timepoint 4 and the rest has 3, majority vote...)
      ind.times = unique(mSet$dataSet$covars[individual == indiv, ..time_var][[1]])
      if (length(ind.times) == length(times)) {
        samps = indiv.samp[individual == indiv]$sample
      } else{
        samps = c()
      }
    } else{
      has.all.groups = all(req.groups %in% overv$variable)
      samps = if (!has.all.groups)
        c()
      else{
        spl.overv <- split(overv, overv$variable)
        minsamp = min(unlist(lapply(spl.overv, nrow)))
        samps = Reduce("c", lapply(req.groups, function(grp) {
          rows = spl.overv[[as.character(grp)]]
          rows$sample[sample(1:nrow(rows), minsamp)]
        }))
      }
    }
    list(samps)
  })
  
  names(keep.samp) <- keep.indiv
  keep.samp = keep.samp[sapply(keep.samp, function(x)
    ! is.null(x))]
  
  if (mSet$settings$exp.type == c("t1f")) {
    indiv.final = unique(overview.tbl[sample %in% unlist(keep.samp), c("individual", "variable")])
    downsampled = caret::downSample(indiv.final$individual, as.factor(indiv.final$variable))
    keep.indiv = downsampled$x
    keep.samp <-
      as.character(unlist(keep.samp[which(names(keep.samp) %in% keep.indiv)]))
  }else{
    keep.samp <- as.character(unlist(keep.samp))
  }
  
  if (length(keep.samp) > 2) {
    mSet <- subset_mSet(mSet,
                        subset_var = "sample",
                        subset_group = keep.samp)
    mSet$settings$ispaired <- TRUE
    mSet$dataSet$ispaired = T
    
  } else{
    metshiAlert("Not enough samples for paired analysis!")
    return(NULL)
  }
  mSet
}

batchCorr_mSet <- function(mSet, method, batch_var, cl=0){
  switch(method, 
         pmp = {
           batch.idx <- as.numeric(as.factor(mSet$dataSet$covars$batch))
           seq.idx <- as.numeric(mSet$dataSet$covars$injection)
           dtNorm <- as.data.frame(cbind(name = rownames(mSet$dataSet$proc), 
                                         injection.order = seq.idx,
                                         batch = batch.idx,
                                         class = sapply(mSet$dataSet$covars$sample, function(samp) if(grepl("QC", samp)) "QC" else "nonQC"),
                                         mSet$dataSet$proc))
           dtNorm_merge_order <- dtNorm[order(dtNorm$batch,
                                              dtNorm$injection.order),]
           dtNorm_stat_order <- dtNorm_merge_order[,-c(1:4)]
           dtNorm_numeric = apply(dtNorm_stat_order, 2, as.numeric)
           corrected_data <- pmp::QCRSC(df=t(dtNorm_numeric), 
                                        order=seq.idx, 
                                        batch=batch.idx, 
                                        classes=dtNorm_merge_order$class, 
                                        spar=0, 
                                        minQC=4)
           # TODO: flip, then renormalize
         },
         waveica = {
           csv_edata <- combatCSV(mSet, tbl = "norm")
           batch.idx = as.numeric(as.factor(mSet$dataSet$covars$batch))
           seq.idx = as.numeric(mSet$dataSet$covars$injection)
           dtNorm <- as.data.frame(cbind(name = rownames(mSet$dataSet$norm), 
                                         injection.order = seq.idx,
                                         batch = batch.idx,
                                         group = rep(1, nrow(mSet$dataSet$norm)),
                                         mSet$dataSet$norm))
           dtNorm_merge_order <- dtNorm[order(dtNorm$batch,
                                              dtNorm$injection.order),]
           dtNorm_stat_order <- dtNorm_merge_order[,-c(1:4)]
           
           waveCorr = WaveICA::WaveICA(dtNorm_stat_order, batch = dtNorm_merge_order$batch, cl=cl)
           waveCorr = waveCorr$data_wave
           old.order = rownames(mSet$dataSet$norm)
           new.order = rownames(waveCorr)
           reorder = match(old.order, new.order)
           reorderedCorr = as.data.frame(waveCorr[reorder,])
           rownames(reorderedCorr) = old.order
           data.frame(lapply(reorderedCorr, function(x) as.numeric(as.character(x))),
                      check.names=F, row.names = rownames(reorderedCorr))
         }, 
         batchCorr = {
           smps <- rownames(mSet$dataSet$norm)
           # get which rows are QC samples
           qc_rows <- which(grepl(pattern = "QC", x = smps))
           # get batch for each sample
           batch.idx = as.numeric(as.factor(mSet$dataSet$covars[match(smps, mSet$dataSet$covars$sample),"batch"][[1]]))
           if(length(batch.idx) == 0) return(mSet$dataSet$norm)
           # get injection order for samples
           seq.idx = as.numeric(mSet$dataSet$covars[match(smps, mSet$dataSet$covars$sample),"injection"][[1]])
           # go through all the metabolite columns
           corr_cols <- pbapply::pblapply(1:ncol(mSet$dataSet$norm), function(i){
             # fetch non-corrected values
             vec = mSet$dataSet$norm[,i]
             # correct values using QCs and injectiono rder
             corr_vec = BatchCorrMetabolomics::doBC(Xvec = as.numeric(vec),
                                                    ref.idx = as.numeric(qc_rows),
                                                    batch.idx = batch.idx,
                                                    seq.idx = seq.idx,
                                                    result = "correctedX",
                                                    minBsamp = 1) # at least one QC necessary
             corr_vec
           })
           
           # cbind the corrected columns to re-make table
           batch_normalized <- as.data.frame(do.call(cbind, corr_cols))
           # fix rownames to old rownames
           colnames(batch_normalized) <- colnames(mSet$dataSet$norm)
           rownames(batch_normalized) <- rownames(mSet$dataSet$norm)
           as.data.frame(batch_normalized)
         },
         limma = {
           csv_edata <- combatCSV(mSet, tbl = "norm")
           # create a model table
           csv_pheno <- data.frame(sample = 1:nrow(mSet$dataSet$covars),
                                   batch1 = mSet$dataSet$covars[, batch_var, with=FALSE][[1]]
           )
           # batch correct with limma and two batches
           batch_normalized = t(limma::removeBatchEffect(x = csv_edata,
                                                         #design = mod.pheno,
                                                         batch = csv_pheno$batch1,
                                                         batch2 = csv_pheno$batch2))
           rownames(batch_normalized) <- rownames(mSet$dataSet$norm)
           as.data.frame(batch_normalized)
         },
         covbat = {
           csv_edata <- combatCSV(mSet, tbl = "norm")
           csv_pheno <- data.frame(sample = 1:nrow(mSet$dataSet$covars),
                                   batch1 = mSet$dataSet$covars[, batch_var, with=FALSE][[1]]
           )
           # batch correct with comBat
           batch_normalized = CovBat::covbat(dat = csv_edata, 
                                             bat = csv_pheno$batch1)
           batch_normalized = t(batch_normalized$dat.covbat)
           
           # fix row names
           rownames(batch_normalized) <- rownames(mSet$dataSet$norm)
           batch_normalized
         },
         combat = {
           csv_edata <- combatCSV(mSet, tbl = "norm")
           
           csv_pheno <- data.frame(sample = 1:nrow(mSet$dataSet$covars),
                                   batch1 = mSet$dataSet$covars[, batch_var, with=FALSE][[1]]
           )
           # batch correct with comBat
           batch_normalized = t(sva::ComBat(dat = csv_edata,
                                            batch = csv_pheno$batch1)
           )
           # fix row names
           rownames(batch_normalized) <- rownames(mSet$dataSet$norm)
           batch_normalized
         })
}