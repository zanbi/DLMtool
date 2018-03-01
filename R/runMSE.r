
Names <- c("maxage", "R0", "Mexp", "Msd", "dep", "D", "Mgrad", "SRrel", "hs", "procsd",
           "L50", "L95", "L50_95", "CAL_binsmid", "Len_age", "maxlen", "Linf", 
           "M_at_Length", "Frac_area_1", "Prob_staying", "M_ageArray", "Mat_age",
           "Wt_age", "V", "Spat_targ", "procmu", "recMulti", "Linfrand", "Krand",
           "Abias Aerr", "Brefbias", "CAA_ESS", "CAA_nsamp", "CAL_ESS", "CAL_bins", "CAL_nsamp",
           "Cbias", "Crefbias", "Csd", "Dbias", "Derr", "TAEFrac", "TAESD", "EffLower",
           "EffUpper", "EffYears", "FMSY_Mbias", "Frac_area_1", "Irefbias", "Isd", "K", "Kbias", "Kgrad",
           "Krand", "Ksd", "L5", "L5s", "LFCbias", "LFS", "LFSbias", "LFSs", "LatASD", "Linfbias", "Linfgrad",
           "Linfrand", "Linfsd", "M", "M_ageArray", "Mat_age", "Mbias", "Mrand", "Prob_staying", "Recsd",
           "SLarray", "SizeLimFrac", "SizeLimSD", "Spat_targ", "TACFrac", "TACSD", 
           "Vmaxlen", "Vmaxlens", "Wt_age", "ageM", "betas", "lenMbias", "nCALbins", "procmu", "qcv", "qinc",
           "recMulti",  "t0", "t0bias", "Abias", "Aerr", "Perr", "Esd", "qvar", "Marray",
           "Linfarray", "Karray", "AC", "LenCV", "a", "b", "FinF", 
           "Fdisc", "R50", "Rslope", "retA", "retL", "LR5", "LFR", "Rmaxlen",
           "V2", "SLarray2", "DR", "Asize", "Size_area_1", "L50array", "L95array",
           "Fdisc_array", "Fdisc_array2")


if(getRversion() >= "2.15.1") utils::globalVariables(Names)




#' Run a Management Strategy Evaluation
#' 
#' A function that runs a Management Strategy Evaluation (closed-loop
#' simulation) for a specified operating model
#' 
#' 
#' @param OM An operating model object (class 'OM')
#' @param MPs A vector of methods (character string) of class Output or
#' Input.
#' @param CheckMPs Logical to indicate if Can function should be used to check
#' if MPs can be run.
#' @param timelimit Maximum time taken for a method to carry out 10 reps
#' (methods are ignored that take longer)
#' @param Hist Should model stop after historical simulations? Returns a list 
#' containing all historical data
#' @param ntrials Maximum of times depletion and recruitment deviations are 
#' resampled to optimize for depletion. After this the model stops if more than 
#' percent of simulations are not close to the required depletion
#' @param fracD maximum allowed proportion of simulations where depletion is not 
#' close to sampled depletion from OM before model stops with error
#' @param CalcBlow Should low biomass be calculated where this is the spawning
#' biomass at which it takes HZN mean generation times of zero fishing to reach 
#' Bfrac fraction of SSBMSY
#' @param HZN The number of mean generation times required to reach Bfrac SSBMSY
#' in the Blow calculation
#' @param Bfrac The target fraction of SSBMSY for calculating Blow
#' @param AnnualMSY Logical. Should MSY statistics be calculated for each projection year? 
#' May differ from MSY statistics from last historical year if there are changes in productivity
#' @param silent Should messages be printed out to the console?
#' @param PPD Logical. Should posterior predicted data be included in the MSE object Misc slot?
#' @param parallel Logical. Should the MSE be run using parallel processing?
#' @param save_name Character. Optional name to save parallel MSE list
#' @param checks Logical. Run tests?
#' @param control control options for testing and debugging
#' @return An object of class MSE
#' @author T. Carruthers and A. Hordyk
#' @export
#' 
runMSE <- function(OM = DLMtool::testOM, MPs = c("AvC","DCAC","FMSYref","curE","matlenlim", "MRreal"), 
                   CheckMPs = FALSE, timelimit = 1, Hist=FALSE, ntrials=50, fracD=0.05, CalcBlow=FALSE, 
                   HZN=2, Bfrac=0.5, AnnualMSY=FALSE, silent=FALSE, PPD=FALSE, parallel=FALSE, 
                   save_name=NULL, checks=FALSE, control=NULL) {
  
  if (Hist & parallel) {
    message("Sorry! Historical simulations currently can't use parallel.")
    parallel <- FALSE
  }
  if (parallel) {
    if(!snowfall::sfIsRunning()) stop("Requires parallel. Use 'setup'", call. = FALSE)
    
    ncpu <- snowfall::sfCpus()
    
    if (OM@nsim<48) stop("nsim must be >=48")
    nits <- ceiling(OM@nsim/48)
    
    itsim <- rep(48,nits)
    
    if (nits < ncpu) {
      nits <- ncpu
      itsim <- rep(ceiling(OM@nsim/ncpu), ncpu)
    }
    if(sum(itsim) != OM@nsim) {
      itsim[length(itsim)] <- OM@nsim - sum(itsim[1:(length(itsim)-1)] )
    }
    if (itsim[length(itsim)]==1) {
      itsim[length(itsim)] <- 2
      itsim[length(itsim)-1] <- itsim[length(itsim)-1] - 1
    }
    if (!silent) message("Running MSE in parallel on ", ncpu, ' processors')
    temp <- snowfall::sfClusterApplyLB(1:nits, run_parallel, itsim=itsim, OM=OM, MPs=MPs,  
                             CheckMPs=CheckMPs, timelimit=timelimit, Hist=Hist, ntrials=ntrials, 
                             fracD=fracD, CalcBlow=CalcBlow, 
                             HZN=HZN, Bfrac=Bfrac, AnnualMSY=AnnualMSY, silent=TRUE, PPD=PPD)
  
    if (!is.null(save_name) && is.character(save_name)) saveRDS(temp, paste0(save_name, '.rdata'))
    
    MSE1 <- joinMSE(temp) 
    if (class(MSE1) == "MSE") {
      message("MSE completed")
    } else {
      message("MSE completed but could not join MSE objects. Re-run with `save_name ='MyName'` to debug")
    }
  }

 
  if (!parallel) {
    if (OM@nsim > 48 & !silent & !Hist) message("Suggest using 'parallel = TRUE' for large number of simulations")
    MSE1 <- runMSE_int(OM, MPs, CheckMPs, timelimit, Hist, ntrials, fracD, CalcBlow, 
                       HZN, Bfrac, AnnualMSY, silent, PPD, checks=checks, control=control)
    
  }
  
  return(MSE1)
  
}

runMSE_int <- function(OM = DLMtool::testOM, MPs = c("AvC","DCAC","FMSYref","curE","matlenlim", "MRreal"), 
                      CheckMPs = FALSE, timelimit = 1, Hist=FALSE, ntrials=50, fracD=0.05, CalcBlow=FALSE, 
                      HZN=2, Bfrac=0.5, AnnualMSY=FALSE, silent=FALSE, PPD=FALSE, checks=FALSE,
                      control=NULL) {
  
 
  
  # For debugging - assign default argument values to to current workspace if they don't exist ####
  if (interactive()) { 
    # devtools::load_all()
    DFargs <- formals(runMSE)
    argNames <- names(DFargs)
    for (X in seq_along(argNames)) {
      if (!exists(argNames[X])) {
        tt <- try(as.numeric(DFargs[X]), silent=TRUE)
        if (class(tt) != "try-error") {
          assign(argNames[X], tt)
        } else {
          if (argNames[X] == "OM") OM <- DLMtool::testOM
          if (argNames[X] == "MPs") MPs <- c("AvC","DCAC","FMSYref","curE","matlenlim")
        }
      }
    }
  }
  
  if (class(OM) != "OM") stop("You must specify an operating model")
  Misc<-new('list') #Blank miscellaneous slot created
  if("seed"%in%slotNames(OM)) set.seed(OM@seed) # set seed for reproducibility 
  
  OM <- updateMSE(OM)
  tiny <- 1e-15  # define tiny variable
  
  # Backwards compatible with DLMtool v < 4
  if("nsim"%in%slotNames(OM))nsim<-OM@nsim
  if("proyears"%in%slotNames(OM))proyears<-OM@proyears
  
  # Backwards compatible with DLMtool v < 4.4.2
  if(length(OM@interval)>0) interval <- OM@interval
  if(length(OM@pstar)>0) pstar <- OM@pstar
  if(length(OM@maxF)>0) maxF <- OM@maxF
  if(length(OM@reps)>0) reps <- OM@reps

  OM@interval <- interval 
  OM@pstar <- pstar 
  OM@maxF <- maxF 
  OM@reps <- reps 
  
  OM@nsim<-nsim # number of simulations
  OM@proyears<-proyears # number of projection years
  nyears <- OM@nyears  # number of historical years
  
  OM <- ChkObj(OM) # Check that all required slots in OM object contain values 
  
  if (proyears < 2) stop('OM@proyears must be > 1', call.=FALSE)
  ### Sampling OM parameters ###
  if(!silent) message("Loading operating model")
  
  # --- Sample custom parameters ----
  SampCpars <- list() # empty list 
  # custom parameters exist - sample and write to list
  if(length(OM@cpars)>0){
    ncparsim<-cparscheck(OM@cpars)   # check each list object has the same length and if not stop and error report
    SampCpars <- SampleCpars(OM@cpars, nsim) 
  }
  
  # --- Sample Stock Parameters ----
  StockPars <- SampleStockPars(OM, nsim, nyears, proyears, SampCpars)
  # Assign Stock pars to function environment
  for (X in 1:length(StockPars)) assign(names(StockPars)[X], StockPars[[X]])
  
  # --- Sample Fleet Parameters ----
  FleetPars <- SampleFleetPars(SubOM(OM, "Fleet"), Stock=StockPars, nsim, nyears, proyears, 
                               cpars=SampCpars)
  
  # Assign Fleet pars to function environment
  for (X in 1:length(FleetPars)) assign(names(FleetPars)[X], FleetPars[[X]])
  
  # --- Sample Obs Parameters ----
  ObsPars <- SampleObsPars(OM, nsim)
  # Assign Obs pars to function environment
  for (X in 1:length(ObsPars)) assign(names(ObsPars)[X], ObsPars[[X]])
  
  # --- Sample Imp Paramerers ----
  ImpPars <- SampleImpPars(OM, nsim)
  # Assign Imp pars to function environment
  for (X in 1:length(ImpPars)) assign(names(ImpPars)[X], ImpPars[[X]])
  
  ### End of sampling OM parameters ###
  
  # --- Calculate movement ----
  
  if (!exists("mov", inherits=FALSE)) {
    if(!silent) message("Optimizing for user-specified movement")  # Print a progress update
    # if (snowfall::sfIsRunning()) {
    #   # if the cluster is initiated
    #   # snowfall::sfExport(list = c("Frac_area_1", "Prob_staying"))  # export some of the new arrays
    #   mov <- array(t(snowfall::sfSapply(1:nsim, getmov2, Frac_area_1 = Frac_area_1, 
    #                                     Prob_staying = Prob_staying)), dim = c(nsim, 2, 2))  # numerically determine movement probability parameters to match Prob_staying and Frac_area_1
    # } else {
    #   # no cluster initiated
    #   mov <- array(t(sapply(1:nsim, getmov2, Frac_area_1 = Frac_area_1, 
    #                         Prob_staying = Prob_staying)), dim = c(nsim, 2, 2))  # numerically determine movement probability parameters to match Prob_staying and Frac_area_1
    # }
    # 
    nareas<-2 # default is a 2 area model
    mov1 <- array(t(sapply(1:nsim, getmov2, Frac_area_1 = Frac_area_1, 
                          Prob_staying = Prob_staying)), dim = c(nsim, nareas, nareas))
    mov<-array(NA,c(nsim,maxage,nareas,nareas))
    mind<-as.matrix(expand.grid(1:nsim,1:maxage,1:nareas,1:nareas))
    mov[mind]<-mov1[mind[,c(1,3,4)]]
    
    initdist <- array(0,c(nsim,maxage,nareas))
    initdist[,,1]<-Frac_area_1
    initdist[,,2]<- 1- Frac_area_1  
    
  }else{ # if mov is specified need to calculate age-based spatial distribution (Pinitdist to initdist)
    nareas<-dim(mov)[3]
    message(paste("Custom movement matrix detected, simulating movement among",nareas,"areas"))
    
    mind<-as.matrix(expand.grid(1:nsim,maxage,1:nareas,1:nareas))
    movedarray<-array(0,c(nsim,nareas,nareas))
    Pinitdist<-array(1/nareas,c(nsim,nareas))
    for(i in 1:20){ # convergence in initial distribution is assumed to occur in 20 iterations (generally overkill)
      movedarray[mind[,c(1,3,4)]]<-Pinitdist[mind[,c(1,3)]]*mov[mind] # distribution in from areas mulitplied by movement array
      Pinitdist<-apply(movedarray,c(1,3),sum) # add over to areas
      #print(initdist[1:2,]) # debugging to check convergence
    }
  
  }
  
  N <- array(NA, dim = c(nsim, maxage, nyears, nareas))  # stock numbers array
  Biomass <- array(NA, dim = c(nsim, maxage, nyears, nareas))  # stock biomass array
  VBiomass <- array(NA, dim = c(nsim, maxage, nyears, nareas))  # vulnerable biomass array
  
  SSN <- array(NA, dim = c(nsim, maxage, nyears, nareas))  # spawning stock numbers array
  
  SSB <- array(NA, dim = c(nsim, maxage, nyears, nareas))  # spawning stock biomass array
  FM <- array(NA, dim = c(nsim, maxage, nyears, nareas))  # fishing mortality rate array
  FMret <- array(NA, dim = c(nsim, maxage, nyears, nareas))  # fishing mortality rate array for retained fish 
  Z <- array(NA, dim = c(nsim, maxage, nyears, nareas))  # total mortality rate array
  SPR <- array(NA, dim = c(nsim, maxage, nyears)) # store the Spawning Potential Ratio
  
  Agearray <- array(rep(1:maxage, each = nsim), dim = c(nsim, maxage))  # Age array
  # surv <- exp(-Marray[, 1])^(Agearray - 1)  # Survival array
  
  # Survival array with M-at-age
  surv <- matrix(1, nsim, maxage)
  surv[, 2:maxage] <- t(exp(-apply(M_ageArray[,,1], 1, cumsum)))[, 1:(maxage-1)]
  
  Nfrac <- surv * Mat_age[,,1]  # predicted Numbers of mature ages in first year
  
  SAYR <- as.matrix(expand.grid(1:nareas, 1, 1:maxage, 1:nsim)[4:1])  # Set up some array indexes sim (S) age (A) year (Y) region/area (R)
  SAY <- SAYR[, 1:3]
  SAR <- SAYR[, c(1,2,4)]
  SA <- Sa <- SAYR[, 1:2]
  SR <- SAYR[, c(1, 4)]
  S <- SAYR[, 1]
  SY <- SAYR[, c(1, 3)]
  Sa[,2]<-maxage-Sa[,2]+1 # This is the process error index for initial year
  
  if(!exists('initdist', inherits = FALSE)){ # initdist calculation from Pinitdist and 
    if (!exists('Asize', inherits = FALSE)) {
      message('Asize not set. Assuming all areas equal size')
      Asize <- matrix(1/nareas, nrow=nsim, ncol=nareas)
    }
    #  --- Pre Equilibrium calcs ----
    SSN[SAYR] <- Nfrac[SA] * R0[S] * Pinitdist[SR]  # Calculate initial spawning stock numbers
    N[SAYR] <- R0[S] * surv[SA] * Pinitdist[SR]  # Calculate initial stock numbers
    Neq <- N
    Biomass[SAYR] <- N[SAYR] * Wt_age[SAY]  # Calculate initial stock biomass
    SSB[SAYR] <- SSN[SAYR] * Wt_age[SAY]    # Calculate spawning stock biomass
    VBiomass[SAYR] <- Biomass[SAYR] * V[SAY]  # Calculate vunerable biomass

    if (nsim > 1) {
      SSN0 <- apply(SSN[, , 1, ], c(1, 3), sum)  # Calculate unfished spawning stock numbers
      SSB0 <- apply(SSB[, , 1, ], 1, sum)  # Calculate unfished spawning stock biomass
      SSBpR <- SSB0/R0  # Spawning stock biomass per recruit
      SSBpR <- matrix(SSB0/R0, nrow=nsim, ncol=nareas)  # Spawning stock biomass per recruit
      SSB0a <- apply(SSB[, , 1, ], c(1, 3), sum)  # Calculate unfished spawning stock numbers
      B0 <- apply(Biomass[, , 1, ], 1, sum)
      N0 <- apply(N[, , 1, ], 1, sum)
    } else {
      SSN0 <- apply(SSN[, , 1, ], 2, sum)  # Calculate unfished spawning stock numbers
      SSB0 <-  sum(SSB[, , 1, ])  # Calculate unfished spawning stock biomass
      SSBpR <- SSB0/R0  # Spawning stock biomass per recruit
      SSB0a <- apply(SSB[, , 1, ], 2, sum)  # Calculate unfished spawning stock numbers
      B0 <- apply(Biomass[, , 1, ], 2, sum)
      N0 <- apply(N[, , 1, ], 2, sum)
    }

    bR <- matrix(log(5 * hs)/(0.8 * SSB0a), nrow=nsim)  # Ricker SR params
    aR <- matrix(exp(bR * SSB0a)/SSBpR, nrow=nsim)  # Ricker SR params

    R0a <- matrix(R0, nrow=nsim, ncol=nareas, byrow=FALSE) * 1/nareas # initial distribution of recruits 

    
    Nyrs <- ceiling(3 * maxage) # Project unfished for 3 x maxage
    
    # Set up projection arrays 
    M_ageArrayp <- array(M_ageArray[,,1], dim=c(dim(M_ageArray)[1:2], Nyrs))
    Wt_agep <- array(Wt_age[,,1], dim=c(dim(Wt_age)[1:2], Nyrs))
    Mat_agep <- array(Mat_age[,,1], dim=c(dim(Mat_age)[1:2], Nyrs))
    Perrp <- array(1, dim=c(dim(Perr)[1], Nyrs+maxage)) # no process error 
    # Not used but make the arrays anyway
    retAp <- array(retA[,,1], dim=c(dim(retA)[1:2], Nyrs))
    Vp <- array(V[,,1], dim=c(dim(V)[1:2], Nyrs))
    noMPA <- matrix(1, nrow=Nyrs, ncol=nareas)
    
    # check arrays
    if (checks) {
      sim <- sample(1:nsim,1)
      yrval <- sample(1:Nyrs,1)
      if (!all(M_ageArrayp[sim,,yrval] == M_ageArray[sim,,1] )) warning('problem with M_ageArrayp')
      if(!all(Wt_agep[sim,,yrval] == Wt_age[sim,,1]))  warning('problem with Wt_agep')
      if(!all(Mat_agep[sim,,yrval] == Mat_age[sim,,1])) warning('problem with Mat_agep')
    }

    # Project unfished for Nyrs to calculate equilibrium spatial distribution
    runProj <- lapply(1:nsim, projectEq, Asize, nareas=nareas, maxage=maxage, N=N, pyears=Nyrs,
           M_ageArray=M_ageArrayp, Mat_age=Mat_agep, Wt_age=Wt_agep, V=Vp, retA=retAp,
           Perr=Perrp, mov=mov, SRrel=SRrel, Find=Find, Spat_targ=Spat_targ, hs=hs,
           R0a=R0a, SSBpR=SSBpR, aR=aR, bR=bR, SSB0=SSB0, B0=B0, MPA=noMPA, maxF=maxF,
           Nyrs)
    
    # unpack the list 
    Neq1 <- aperm(array(as.numeric(unlist(runProj)), dim=c(maxage, nareas, nsim)), c(3,1,2))
  
    if (checks)  if(!(all(round(apply(Neq[,,1,], 1, sum) /  apply(Neq1, 1, sum),1) ==1))) warning('eq age structure ')           
    
    # --- Equilibrium spatial / age structure (initdist by SAR)
    initdist <- Neq1/array(apply(Neq1, c(1,2), sum), dim=c(nsim, maxage, nareas))
    if (checks) if(!all(round(apply(initdist, c(1,2), sum),1)==1)) warning('initdist does not sum to one')
  }
  
  R0a <- matrix(R0, nrow=nsim, ncol=nareas, byrow=FALSE) * initdist[,1,]  # !!!! INITDIST OF AGE 1. Unfished recruitment by area
  
  SSN[SAYR] <- Nfrac[SA] * R0[S] * initdist[SAR]  # Calculate initial spawning stock numbers
  N[SAYR] <- R0[S] * surv[SA] * initdist[SAR]  # Calculate initial stock numbers
  Neq <- N
  Biomass[SAYR] <- N[SAYR] * Wt_age[SAY]  # Calculate initial stock biomass
  SSB[SAYR] <- SSN[SAYR] * Wt_age[SAY]    # Calculate spawning stock biomass
  VBiomass[SAYR] <- Biomass[SAYR] * V[SAY]  # Calculate vunerable biomass
  
  if (nsim > 1) {
    SSN0 <- apply(SSN[, , 1, ], c(1, 3), sum)  # Calculate unfished spawning stock numbers  
    SSB0 <- apply(SSB[, , 1, ], 1, sum)  # Calculate unfished spawning stock biomass
    SSBpR <- SSB0/R0  # Spawning stock biomass per recruit
    SSBpR <- matrix(SSB0/R0, nrow=nsim, ncol=nareas)  # Spawning stock biomass per recruit
    SSB0a <- apply(SSB[, , 1, ], c(1, 3), sum)  # Calculate unfished spawning stock numbers
    B0 <- apply(Biomass[, , 1, ], 1, sum)
    N0 <- apply(N[, , 1, ], 1, sum)
  } else {
    SSN0 <- apply(SSN[, , 1, ], 2, sum)  # Calculate unfished spawning stock numbers  
    SSB0 <-  sum(SSB[, , 1, ])  # Calculate unfished spawning stock biomass
    SSBpR <- SSB0/R0  # Spawning stock biomass per recruit
    SSB0a <- apply(SSB[, , 1, ], 2, sum)  # Calculate unfished spawning stock numbers
    B0 <- apply(Biomass[, , 1, ], 2, sum)
    N0 <- apply(N[, , 1, ], 2, sum)
  }
  
  bR <- matrix(log(5 * hs)/(0.8 * SSB0a), nrow=nsim)  # Ricker SR params
  aR <- matrix(exp(bR * SSB0a)/SSBpR, nrow=nsim)  # Ricker SR params
  
  
  #  --- Non-equilibrium calcs ----
  SSN[SAYR] <- Nfrac[SA] * R0[S] * initdist[SAR]*Perr[Sa]  # Calculate initial spawning stock numbers
  N[SAYR] <- R0[S] * surv[SA] * initdist[SAR]*Perr[Sa]  # Calculate initial stock numbers
  
  Biomass[SAYR] <- N[SAYR] * Wt_age[SAY]  # Calculate initial stock biomass
  SSB[SAYR] <- SSN[SAYR] * Wt_age[SAY]    # Calculate spawning stock biomass
  VBiomass[SAYR] <- Biomass[SAYR] * V[SAY]  # Calculate vunerable biomass

  # --- Historical Spatial closures ----
  MPA <- matrix(1, nyears+proyears, ncol=nareas)
  if (all(!is.na(OM@MPA)) && sum(OM@MPA) != 0) { # historical spatial closures have been specified
    yrindex <- OM@MPA[,1]
    if (max(yrindex)>nyears) stop("Invalid year index for spatial closures: must be <= nyears")
    if (min(yrindex)<1) stop("Invalid year index for spatial closures: must be > 1")
    if (ncol(OM@MPA)-1 != nareas) stop("OM@MPA must be nareas + 1")
    for (xx in seq_along(yrindex)) {
      MPA[yrindex[xx]:nrow(MPA),] <- matrix(OM@MPA[xx, 2:ncol(OM@MPA)], nrow=length(yrindex[xx]:nrow(MPA)),ncol=nareas, byrow = TRUE)
    }
  }
  
  # --- Optimize catchability (q) to fit depletion ---- 
  if(!silent) message("Optimizing for user-specified depletion")  # Print a progress update
  
  bounds <- c(0.0001, 15) # q bounds for optimizer
  # if (snowfall::sfIsRunning()) {
  #   # snowfall::sfExport(list = c("D", "Find", "Perr", "M_ageArray", "hs", "Mat_age",
  #   # "Wt_age", "R0", "V", "nyears", "maxage", "SRrel", "aR", "bR"))
  #   # qs <- snowfall::sfSapply(1:nsim, getq2, D, Find, Perr, M_ageArray, hs, Mat_age,
  #   # Wt_age, R0, V, nyears, maxage, mov, Spat_targ, SRrel, aR, bR, bounds)  # find the q that gives current stock depletion
  #   
  #   # snowfall::sfExport(list = c("D", "SSB0", "nareas", "maxage", "N", "nyears", 
  #   #                             "M_ageArray", "Mat_age", "Asize", "Wt_age", "V", "retA", 'Perr', "mov", "SRrel", "Find", 
  #   #                             "Spat_targ", "hs", "R0a", "SSBpR", "aR", 'bR', "bounds", "maxF"))
  #   qs <- snowfall::sfSapply(1:nsim, getq3, D, SSB0, nareas, maxage, N, pyears=nyears, 
  #                            M_ageArray, Mat_age, Asize, Wt_age, V, retA, Perr, mov, SRrel, Find, 
  #                            Spat_targ, hs, R0a, SSBpR, aR, bR, bounds=bounds, MPA=MPA, maxF=maxF) # find the q that gives current stock depletion
  # } else {
  #   # qs <- sapply(1:nsim, getq2, D, Find, Perr, M_ageArray, hs, Mat_age,
  #   #              Wt_age, R0, V, nyears, maxage, mov, Spat_targ, SRrel, aR, bR, bounds)  # find the q that gives current stock depletion
  #   qs <- sapply(1:nsim, getq3, D, SSB0, nareas, maxage, N, pyears=nyears, 
  #                M_ageArray, Mat_age, Asize, Wt_age, V, retA, Perr, mov, SRrel, Find, 
  #                Spat_targ, hs, R0a, SSBpR, aR, bR, bounds=bounds, MPA=MPA, maxF=maxF) # find the q that gives current stock depletion
  # }
  # quicker without parallel
  qs <- sapply(1:nsim, getq3, D, SSB0, nareas, maxage, N, pyears=nyears, 
               M_ageArray, Mat_age, Asize, Wt_age, V, retA, Perr, mov, SRrel, Find, 
               Spat_targ, hs, R0a, SSBpR, aR, bR, bounds=bounds, MPA=MPA, maxF=maxF) # find the q that gives current stock depletion

  
  # --- Check that q optimizer has converged ---- 
  LimBound <- c(1.1, 0.9)*range(bounds)  # bounds for q (catchability). Flag if bounded optimizer hits the bounds 
  probQ <- which(qs > max(LimBound) | qs < min(LimBound))
  Nprob <- length(probQ)
  
  # If q has hit bound, re-sample depletion and try again. Tries 'ntrials' times
  # and then alerts user
  if (length(probQ) > 0) {
    Err <- TRUE
    if(!silent) message(Nprob,' simulations have final biomass that is not close to sampled depletion') 
    if(!silent) message('Re-sampling depletion, recruitment error, and fishing effort')
    
    count <- 0
    OM2 <- OM 
    while (Err & count < ntrials) {
      # Re-sample Stock Parameters 
      Nprob <- length(probQ)
      OM2@nsim <- Nprob
      SampCpars2 <- list()
      if (length(OM2@cpars)>0) SampCpars2 <- SampleCpars(OM2@cpars, OM2@nsim, msg=FALSE) 
     
      ResampStockPars <- SampleStockPars(OM2, cpars=SampCpars2, Msg=FALSE)  
      ResampStockPars$CAL_bins <- StockPars$CAL_bins
      ResampStockPars$CAL_binsmid <- StockPars$CAL_binsmid 
    
      # Re-sample depletion 
      D[probQ] <- ResampStockPars$D 
      
      # Re-sample recruitment deviations
      procsd[probQ] <- ResampStockPars$procsd 
      AC[probQ] <- ResampStockPars$AC
      Perr[probQ,] <- ResampStockPars$Perr
      hs[probQ] <- ResampStockPars$hs
      
      # Re-sample historical fishing effort
      ResampFleetPars <- SampleFleetPars(SubOM(OM2, "Fleet"), Stock=ResampStockPars, 
                                         OM2@nsim, nyears, proyears, cpars=SampCpars2)
      Esd[probQ] <- ResampFleetPars$Esd
      Find[probQ, ] <- ResampFleetPars$Find
      dFfinal[probQ] <- ResampFleetPars$dFfinal
      
      # Optimize for q 
      # if (snowfall::sfIsRunning()) {
      #   
      #   # snowfall::sfExport(list = c("D", "SSB0", "nareas", "maxage", "N", "nyears", 
      #   #                             "M_ageArray", "Mat_age", "Wt_age", "V", "retA", 'Perr', "mov", "SRrel", "Find", 
      #   #                             "Spat_targ", "hs", "R0a", "SSBpR", "aR", 'bR', "bounds", "maxF"))
      #   qs[probQ] <- snowfall::sfSapply(probQ, getq3, D, SSB0, nareas, maxage, N, pyears=nyears, 
      #                                   M_ageArray, Mat_age, Asize, Wt_age, V, retA, Perr, mov, SRrel, Find, 
      #                                   Spat_targ, hs, R0a, SSBpR, aR, bR, bounds=bounds, MPA=MPA, maxF=maxF) # find the q that gives current stock depletion
      # } else {
      #   qs[probQ] <- sapply(probQ, getq3, D, SSB0, nareas, maxage, N, pyears=nyears, 
      #                       M_ageArray, Mat_age, Asize, Wt_age, V, retA, Perr, mov, SRrel, Find, 
      #                       Spat_targ, hs, R0a, SSBpR, aR, bR, bounds=bounds, MPA=MPA, maxF=maxF) # find the q that gives current stock depletion
      # }
      qs[probQ] <- sapply(probQ, getq3, D, SSB0, nareas, maxage, N, pyears=nyears, 
                          M_ageArray, Mat_age, Asize, Wt_age, V, retA, Perr, mov, SRrel, Find, 
                          Spat_targ, hs, R0a, SSBpR, aR, bR, bounds=bounds, MPA=MPA, maxF=maxF)
      
      probQ <- which(qs > max(LimBound) | qs < min(LimBound))
      count <- count + 1 
      if (length(probQ) == 0) Err <- FALSE
    }
    if (Err) { # still a problem
      tooLow <- length(which(qs > max(LimBound)))
      tooHigh <- length(which(qs < min(LimBound)))
      prErr <- length(probQ)/nsim
      if (prErr > fracD & length(probQ) >= 1) {
        if (length(tooLow) > 0) message(tooLow, " sims can't get down to the lower bound on depletion")
        if (length(tooHigh) > 0) message(tooHigh, " sims can't get to the upper bound on depletion")
        if(!silent) message("More than ", fracD*100, "% of simulations can't get to the specified level of depletion with these Operating Model parameters")
        stop("Try again for a complete new sample, modify the input parameters, or increase ")
      } else {
        if (length(tooLow) > 0) message(tooLow, " sims can't get down to the lower bound on depletion")
        if (length(tooHigh) > 0) message(tooHigh, " sims can't get to the upper bound on depletion")
        if(!silent) message("More than ", 100-fracD*100, "% simulations can get to the sampled depletion.\nContinuing")
      }
    }
  }
  
  if(!silent) message("Calculating historical stock and fishing dynamics")  # Print a progress update
  
  # Distribute fishing effort according to vulnerable biomass
  # if (nsim > 1) fishdist <- (apply(VBiomass[, , 1, ], c(1, 3), sum)^Spat_targ)/
  #   apply(apply(VBiomass[, , 1, ], c(1, 3), sum)^Spat_targ, 1, mean)  # spatial preference according to spatial biomass
  # if (nsim == 1)  fishdist <- (matrix(apply(VBiomass[,,1,], 2, sum), nrow=nsim)^Spat_targ)/
  #   mean((matrix(apply(VBiomass[,,1,], 2, sum), nrow=nsim)^Spat_targ))
  # 
  # 

  # --- Simulate historical years ----
  # if (snowfall::sfIsRunning()) {
  #   histYrs <- snowfall::sfSapply(1:nsim, simYears, nareas, maxage, N, pyears=nyears, M_ageArray, Asize,
  #                                Mat_age,  Wt_age, V, retA, Perr, mov, SRrel, Find, Spat_targ, hs, R0a, 
  #                                SSBpR, aR, bR, qs, MPA, maxF)
  # } else {
  #   histYrs <- sapply(1:nsim, simYears, nareas, maxage, N, pyears=nyears, M_ageArray, Asize,
  #                     Mat_age, Wt_age, V, retA, Perr, mov, SRrel, Find, Spat_targ, hs, R0a, 
  #                     SSBpR, aR, bR, qs, MPA, maxF)
  # }
  
  histYrs <- sapply(1:nsim, simYears, nareas, maxage, N, pyears=nyears, M_ageArray, Asize,
                    Mat_age, Wt_age, V, retA, Perr, mov, SRrel, Find, Spat_targ, hs, R0a, 
                    SSBpR, aR, bR, qs, MPA, maxF, SSB0=SSB0)
  
  N <- aperm(array(as.numeric(unlist(histYrs[1,], use.names=FALSE)), dim=c(maxage, nyears, nareas, nsim)), c(4,1,2,3))
  Biomass <- aperm(array(as.numeric(unlist(histYrs[2,], use.names=FALSE)), dim=c(maxage, nyears, nareas, nsim)), c(4,1,2,3))
  SSN <- aperm(array(as.numeric(unlist(histYrs[3,], use.names=FALSE)), dim=c(maxage, nyears, nareas, nsim)), c(4,1,2,3))
  SSB <- aperm(array(as.numeric(unlist(histYrs[4,], use.names=FALSE)), dim=c(maxage, nyears, nareas, nsim)), c(4,1,2,3))
  VBiomass <- aperm(array(as.numeric(unlist(histYrs[5,], use.names=FALSE)), dim=c(maxage, nyears, nareas, nsim)), c(4,1,2,3))
  FM <- aperm(array(as.numeric(unlist(histYrs[6,], use.names=FALSE)), dim=c(maxage, nyears, nareas, nsim)), c(4,1,2,3))
  FMret <- aperm(array(as.numeric(unlist(histYrs[7,], use.names=FALSE)), dim=c(maxage, nyears, nareas, nsim)), c(4,1,2,3))
  Z <-aperm(array(as.numeric(unlist(histYrs[8,], use.names=FALSE)), dim=c(maxage, nyears, nareas, nsim)), c(4,1,2,3))

  
  # Depletion <- apply(Biomass[, , nyears, ], 1, sum)/apply(Biomass[, , 1, ], 1, sum)  #^betas   # apply hyperstability / hyperdepletion
  if (nsim > 1) Depletion <- apply(SSB[,,nyears,],1,sum)/SSB0#^betas
  if (nsim == 1) Depletion <- sum(SSB[,,nyears,])/SSB0 #^betas
  # # apply hyperstability / hyperdepletion
  
  # Check that depletion is correct
  # print(cbind(round(D,4), round(Depletion,4)))
  if (checks) if (prod(round(D, 2)/ round(Depletion,2)) != 1) warning("Possible problem in depletion calculations")
  
  # --- Calculate MSY references ----  
  if(!silent) message("Calculating MSY reference points")  # Print a progress update
  
  # if (snowfall::sfIsRunning()) {
  #   snowfall::sfExport(list = c("M_ageArray", "hs", "Mat_age", "Wt_age", "R0", "V", "nyears", "maxage"))  # export some newly made arrays to the cluster
  #   MSYrefs <- snowfall::sfSapply(1:nsim, getFMSY2, M_ageArray, hs, Mat_age, Wt_age,
  #                                 R0, V = V, retA=retA, maxage, nyears, proyears = 200, Spat_targ,
  #                                 mov, SRrel, aR, bR)  # optimize for MSY reference points\t
  # } else {
  # MSYrefs <- sapply(1:nsim, getFMSY2, M_ageArray, hs, Mat_age, Wt_age,
  #                   R0, V = V, retA=retA, maxage, nyears, proyears = 200, Spat_targ,
  #                   mov, SRrel, aR, bR)  # optimize for MSY reference points
  # }
  
  # MSY projection years
  # MSYyr <- 200
  # # Note: MSY and refY are calculated from total removals not total catch (different when Fdisc>0 and there is discarding)
  # # Make arrays for future conditions assuming current conditions
  # 
  # M_ageArrayp <- array(M_ageArray[,,nyears], dim=c(dim(M_ageArray)[1:2], MSYyr))
  # Wt_agep <- array(Wt_age[,,nyears], dim=c(dim(Wt_age)[1:2], MSYyr))
  #   retAp <- array(retA[,,nyears], dim=c(dim(retA)[1:2], MSYyr))
  # Vp <- array(V[,,nyears], dim=c(dim(V)[1:2], MSYyr))
  # Perrp <- array(1, dim=c(dim(Perr)[1], MSYyr+maxage))
  # noMPA <- matrix(1, nrow=MSYyr, ncol=nareas)
  # Mat_agep <-abind::abind(rep(list(Mat_age[,,nyears]), MSYyr), along=3)
  #   if (snowfall::sfIsRunning()) {
  #  # snowfall::sfExport(list = c("M_ageArrayp", "Wt_agep", "Vp", "retAp", "Perrp"))  # export some newly made arrays to the cluster
  #  MSYrefs <- snowfall::sfSapply(1:nsim, getFMSY3, Asize, nareas=nareas, maxage=maxage, N=N, pyears=MSYyr,
  #                                M_ageArray=M_ageArrayp, Mat_age=Mat_agep, Wt_age=Wt_agep, V=Vp, retA=retAp,
  #                                Perr=Perrp, mov=mov, SRrel=SRrel, Find=Find, Spat_targ=Spat_targ, hs=hs,
  #                                R0a=R0a, SSBpR=SSBpR, aR=aR, bR=bR, SSB0=SSB0, B0=B0, MPA=noMPA, maxF=maxF)  # optimize for MSY reference points
  # } else {
  #  MSYrefs <- sapply(1:nsim, getFMSY3, Asize, nareas=nareas, maxage=maxage, N=N, pyears=MSYyr,
  #                    M_ageArray=M_ageArrayp, Mat_age=Mat_agep, Wt_age=Wt_agep, V=Vp, retA=retAp,
  #                    Perr=Perrp, mov=mov, SRrel=SRrel, Find=Find, Spat_targ=Spat_targ, hs=hs,
  #                    R0a=R0a, SSBpR=SSBpR, aR=aR, bR=bR, SSB0=SSB0, B0=B0, MPA=noMPA, maxF=maxF) # optimize for MSY reference points
  # }
  # 
  # 
  # MSY <- MSYrefs[1, ]  # record the MSY results (Vulnerable)
  # FMSY <- MSYrefs[2, ]  # instantaneous FMSY (Vulnerable)
  # SSBMSY <- MSYrefs[3, ]  # Spawning Stock Biomass at MSY
  # SSBMSY_SSB0 <- MSYrefs[4, ] # SSBMSY relative to unfished (SSB)
  # BMSY_B0 <- MSYrefs[5, ] # Biomass relative to unfished (B0)
  # BMSY <- MSYrefs[6,] # total biomass at MSY
  # VBMSY <- (MSY/(1 - exp(-FMSY)))  # Biomass at MSY (Vulnerable)
  # # FMSYb <- MSYrefs[8,]  # instantaneous FMSY (Spawning Biomass)
  # UMSY <- MSY/VBMSY  # exploitation rate [equivalent to 1-exp(-FMSY)]
  # FMSY_M <- FMSY/M  # ratio of true FMSY to natural mortality rate M
  

  MSYrefs <- sapply(1:nsim, optMSY_eq, M_ageArray, Wt_age, Mat_age, V, maxage, 
                    R0, SRrel, hs, yr=nyears)

  MSY <- MSYrefs[1, ]  # record the MSY results (Vulnerable)
  FMSY <- MSYrefs[2, ]  # instantaneous FMSY (Vulnerable)
  SSBMSY <- MSYrefs[3, ]  # Spawning Stock Biomass at MSY
  SSBMSY_SSB0 <- MSYrefs[4, ] # SSBMSY relative to unfished (SSB)
  BMSY_B0 <- MSYrefs[5, ] # Biomass relative to unfished (B0)
  BMSY <- MSYrefs[6,] # total biomass at MSY
  VBMSY <- (MSY/(1 - exp(-FMSY)))  # Biomass at MSY (Vulnerable)
  UMSY <- MSY/VBMSY  # exploitation rate [equivalent to 1-exp(-FMSY)]
  FMSY_M <- FMSY/M  # ratio of true FMSY to natural mortality rate M
 
  

  # --- Code for deriving low biomass ---- 
  # (SSB where it takes MGThorizon x MGT to reach Bfrac of BMSY)
  
  Znow<-apply(Z[,,nyears,]*N[,,nyears,],1:2,sum)/apply(N[,,nyears,],1:2,sum)
  MGTsurv<-t(exp(-apply(Znow,1,cumsum)))
  MGT<-apply(Agearray*(Mat_age[,,nyears]*MGTsurv),1,sum)/apply(Mat_age[,,nyears]*MGTsurv,1,sum)
  
  if(CalcBlow){
    if(!silent) message("Calculating Blow reference points")              # Print a progress update  
    
    MGThorizon<-floor(HZN*MGT)
    
    if(snowfall::sfIsRunning()){
      # snowfall::sfExport(list=c("SSBMSY","MGT","Find","Perr","M_ageArray","hs","Mat_age","Wt_age","R0","V","nyears","maxage","SRrel","aR","bR"))
      Blow<-sfSapply(1:nsim,getBlow,MSYrefs[3,],MGThorizon,Find,Perr,M_ageArray,hs,Mat_age,
                     Wt_age,R0,V,nyears,maxage,mov,Spat_targ,SRrel,aR,bR,Bfrac) 
    }else{
      Blow <- sapply(1:nsim,getBlow,MSYrefs[3,],MGThorizon,Find,Perr,M_ageArray,hs,Mat_age,
                     Wt_age,R0,V,nyears,maxage,mov,Spat_targ,SRrel,aR,bR,Bfrac) 
    }
  }else{
    Blow<-rep(NA,nsim)
  }
  
  # --- Calculate Reference Yield ----
  if(!silent) message("Calculating reference yield - best fixed F strategy")  # Print a progress update
  # if (snowfall::sfIsRunning()) {
  #   RefY <- snowfall::sfSapply(1:nsim, getFref2, M_ageArray = M_ageArray, Wt_age = Wt_age, 
  #                              Mat_age = Mat_age, Perr = Perr, N_s = N[, , nyears, , drop=FALSE], SSN_s = SSN[, , nyears, , drop=FALSE], 
  #                              Biomass_s = Biomass[, , nyears, , drop=FALSE], VBiomass_s = VBiomass[, , nyears, , drop=FALSE], 
  #                              SSB_s = SSB[, , nyears, , drop=FALSE], Vn = V[, , (nyears + 1):(nyears + proyears), drop=FALSE], 
  #                              retAn = retA[, , (nyears + 1):(nyears + proyears), drop=FALSE],
  #                              hs = hs, R0a = R0a, nyears = nyears, proyears = proyears, nareas = nareas,
  #                              maxage = maxage, mov = mov, SSBpR = SSBpR, aR = aR, bR = bR, SRrel = SRrel, Spat_targ = Spat_targ)
  #   
  # } else {
  # RefY <- sapply(1:nsim, getFref2, M_ageArray = M_ageArray, Wt_age = Wt_age,
  #                Mat_age = Mat_age, Perr = Perr, N_s = N[, , nyears, , drop=FALSE], SSN_s = SSN[, , nyears, , drop=FALSE],
  #                Biomass_s = Biomass[, , nyears, , drop=FALSE], VBiomass_s = VBiomass[, , nyears, , drop=FALSE],
  #                SSB_s = SSB[, , nyears, , drop=FALSE], Vn = V[, , (nyears + 1):(nyears + proyears), drop=FALSE],
  #                retAn = retA[, , (nyears + 1):(nyears + proyears), drop=FALSE],
  #                hs = hs, R0a = R0a, nyears = nyears, proyears = proyears, nareas = nareas,
  #                maxage = maxage, mov = mov, SSBpR = SSBpR, aR = aR, bR = bR, SRrel = SRrel, Spat_targ = Spat_targ)
  #}
  
  # if (snowfall::sfIsRunning()) { # using pop dyn functions - popdyn.R and popdynCPP.cpp
  #   # assuming no dead discarding when calculating reference yield
  #   RefY <- snowfall::sfSapply(1:nsim, getFref3, Asize, nareas, maxage, N=N[,,nyears,, drop=FALSE], pyears=proyears, 
  #                              M_ageArray=M_ageArray[,,(nyears):(nyears+proyears)], Mat_age[,,(nyears):(nyears+proyears)], 
  #                              Wt_age=Wt_age[,,nyears:(nyears+proyears)], 
  #                              V=retA[, , (nyears + 1):(nyears + proyears), drop=FALSE], 
  #                              retA=retA[, , (nyears + 1):(nyears + proyears), drop=FALSE], 
  #                              Perr=Perr[,(nyears-1):(nyears+maxage+proyears-1)], mov, SRrel, Find, 
  #                              Spat_targ, hs, R0a, SSBpR, aR, bR, MPA=MPA, maxF=maxF)
  #   
  # } else {
  #   # assuming no dead discarding when calculating reference yield
  #   RefY <- sapply(1:nsim, getFref3, Asize, nareas, maxage, N=N[,,nyears,, drop=FALSE], pyears=proyears, 
  #                  M_ageArray=M_ageArray[,,(nyears):(nyears+proyears)], Mat_age[,,(nyears):(nyears+proyears)], 
  #                  Wt_age=Wt_age[,,nyears:(nyears+proyears)], 
  #                  V=retA[, , (nyears + 1):(nyears + proyears), drop=FALSE], 
  #                  retA=retA[, , (nyears + 1):(nyears + proyears), drop=FALSE],  
  #                  Perr=Perr[,(nyears):(nyears+maxage+proyears-1)], mov, SRrel, Find, 
  #                  Spat_targ, hs, R0a, SSBpR, aR, bR, MPA=MPA, maxF=maxF)
  # }
  RefY <- sapply(1:nsim, getFref3, Asize, nareas, maxage, N=N[,,nyears,, drop=FALSE], pyears=proyears, 
                 M_ageArray=M_ageArray[,,(nyears):(nyears+proyears)], Mat_age[,,(nyears):(nyears+proyears)], 
                 Wt_age=Wt_age[,,nyears:(nyears+proyears)], 
                 V=retA[, , (nyears + 1):(nyears + proyears), drop=FALSE], 
                 retA=retA[, , (nyears + 1):(nyears + proyears), drop=FALSE],  
                 Perr=Perr[,(nyears):(nyears+maxage+proyears-1)], mov, SRrel, Find, 
                 Spat_targ, hs, R0a, SSBpR, aR, bR, MPA=MPA, maxF=maxF, SSB0=SSB0)

  # --- Calculate catch-at-age ----
  CN <- apply(N * (1 - exp(-Z)) * (FM/Z), c(1, 3, 2), sum)  # Catch in numbers (removed from population)
  CN[is.na(CN)] <- 0
  CB <- Biomass * (1 - exp(-Z)) * (FM/Z)  # Catch in biomass (removed from population)
  
  # --- Calculate retained-at-age ----
  Cret <- apply(N * (1 - exp(-Z)) * (FMret/Z), c(1, 3, 2), sum)  # Retained catch in numbers
  Cret[is.na(Cret)] <- 0
  CBret <- Biomass * (1 - exp(-Z)) * (FMret/Z)  # Retained catch in biomass 
  
  # --- Calculate dead discarded-at-age ----
  Cdisc <- CN - Cret # discarded numbers 
  CBdisc <- CB - CBret # discarded biomass 
  
  # --- Simulate observed catch ---- 
  Cbiasa <- array(Cbias, c(nsim, nyears + proyears))  # Bias array
  Cerr <- array(rlnorm((nyears + proyears) * nsim, mconv(1, rep(Csd, (nyears + proyears))), 
                       sdconv(1, rep(Csd, nyears + proyears))), c(nsim, nyears + proyears))  # composite of bias and observation error
  # Cobs <- Cbiasa[, 1:nyears] * Cerr[, 1:nyears] * apply(CB, c(1, 3), sum)  # Simulated observed catch (biomass)
  Cobs <- Cbiasa[, 1:nyears] * Cerr[, 1:nyears] * apply(CBret, c(1, 3), sum)  # Simulated observed retained catch (biomass)
  
  # --- Simulate observed catch-at-age ----
  # CAA <- array(NA, dim = c(nsim, nyears, maxage))  # Catch  at age array
  # cond <- apply(CN, 1:2, sum, na.rm = T) < 1  # this is a fix for low sample sizes. If CN is zero across the board a single fish is caught in age class of model selectivity (dumb I know)
  # fixind <- as.matrix(cbind(expand.grid(1:nsim, 1:nyears), rep(floor(maxage/3), nyears)))  # more fix
  # CN[fixind[cond, ]] <- 1  # puts a catch in the most vulnerable age class
  # 
  # # a multinomial observation model for catch-at-age data
  # for (i in 1:nsim) 
  #   for (j in 1:nyears) 
  #     CAA[i, j, ] <- ceiling(-0.5 + rmultinom(1, CAA_ESS[i], CN[i, j, ]) * CAA_nsamp[i]/CAA_ESS[i])  # a multinomial observation model for catch-at-age data
  # 
  
  # generate CAA from retained catch-at-age 
  CAA <- array(NA, dim = c(nsim, nyears, maxage))  # Catch  at age array
  cond <- apply(Cret, 1:2, sum, na.rm = T) < 1  # this is a fix for low sample sizes. If Cret is zero across the board a single fish is caught in age class of model selectivity (dumb I know)
  fixind <- as.matrix(cbind(expand.grid(1:nsim, 1:nyears), rep(floor(maxage/3), nyears)))  # more fix
  Cret[fixind[cond, ]] <- 1  # puts a catch in the most vulnerable age class
  
  # a multinomial observation model for catch-at-age data
  for (i in 1:nsim) 
    for (j in 1:nyears) 
      CAA[i, j, ] <- ceiling(-0.5 + rmultinom(1, CAA_ESS[i], Cret[i, j,]) * CAA_nsamp[i]/CAA_ESS[i]) 
  
  
  # --- Simulate observed catch-at-length ----
  # a multinomial observation model for catch-at-length data
  # assumed normally-distributed length-at-age truncated at 2 standard deviations from the mean
  CAL <- array(NA, dim=c(nsim,  nyears, nCALbins))
  LFC <- rep(NA, nsim)
  vn <- (apply(N[,,,], c(1,2,3), sum) * retA[,,1:nyears]) # numbers at age that would be retained
  vn <- aperm(vn, c(1,3, 2))

  # for (i in 1:nsim) { # Rcpp code
  #   CAL[i, , ] <-  genLenComp(CAL_bins, CAL_binsmid, retL[i,,], CAL_ESS[i], CAL_nsamp[i],
  #                             vn[i,,], Len_age[i,,], LatASD[i,,], truncSD=2)
  #   LFC[i] <- CAL_binsmid[min(which(round(CAL[i,nyears, ],0) >= 1))] # get the smallest CAL observation
  # }

  
  
  # Generate size comp data with variability in age
  if (!is.null(control) && control!=1) {
    # use r version if cpp gives problems
    tempSize <- lapply(1:nsim, makeSizeCompW2, nyears, maxage, Linfarray, Karray, t0array, LenCV,
                       CAL_bins, CAL_binsmid, retL, CAL_ESS, CAL_nsamp,
                       vn, truncSD=2)
  } else {
    # use cpp 
    tempSize <- lapply(1:nsim, makeSizeCompW, maxage, Linfarray, Karray, t0array, LenCV,
                       CAL_bins, CAL_binsmid, retL, CAL_ESS, CAL_nsamp,
                       vn, truncSD=2)
  }
 
  CAL <- aperm(array(as.numeric(unlist(tempSize, use.names=FALSE)), dim=c(nyears, length(CAL_binsmid), nsim)), c(3,1,2))
 
  for (i in 1:nsim) {
    ind <- round(CAL[i,nyears, ],0) >= 1
    if (sum(ind)>0) {
      LFC[i] <- CAL_binsmid[min(which(ind))] # get the smallest CAL observation
    } else {
      LFC[i] <- 0
    }
  }

  # --- Simulate index of abundance from total biomass ----
  Ierr <- array(rlnorm((nyears + proyears) * nsim, mconv(1, rep(Isd, nyears + proyears)), 
                       sdconv(1, rep(Isd, nyears + proyears))), c(nsim, nyears + proyears))
  II <- (apply(Biomass, c(1, 3), sum) * Ierr[, 1:nyears])^betas  # apply hyperstability / hyperdepletion
  II <- II/apply(II, 1, mean)  # normalize
  
  # --- Calculate vulnerable and spawning biomass abundance ----
  if (nsim > 1) A <- apply(VBiomass[, , nyears, ], 1, sum)  + apply(CB[, , nyears, ], 1, sum) # Abundance before fishing
  if (nsim == 1) A <- sum(VBiomass[, , nyears, ]) +  sum(CB[,,nyears,]) # Abundance before fishing
  if (nsim > 1) Asp <- apply(SSB[, , nyears, ], 1, sum)  # SSB Abundance
  if (nsim == 1) Asp <- sum(SSB[, , nyears, ])  # SSB Abundance  
  
  OFLreal <- A * FMSY  # the true simulated Over Fishing Limit
  
  # --- Simulate observed values in reference SBMSY/SB0 ----
  I3 <- apply(Biomass, c(1, 3), sum)^betas  # apply hyperstability / hyperdepletion
  I3 <- I3/apply(I3, 1, mean)  # normalize index to mean 1
  # Iref <- apply(I3[, 1:5], 1, mean) * BMSY_B0  # return the real target abundance index corresponding to BMSY
  if (nsim > 1) Iref <- apply(I3[, 1:5], 1, mean) * SSBMSY_SSB0  # return the real target abundance index corresponding to BMSY
  if (nsim == 1) Iref <- mean(I3[1:5]) * SSBMSY_SSB0
  
  # --- Simulate observed values in steepness ----
  hsim <- rep(NA, nsim)  
  cond <- hs > 0.6
  hsim[cond] <- 0.2 + rbeta(sum(hs > 0.6), alphaconv((hs[cond] - 0.2)/0.8, (1 - (hs[cond] - 0.2)/0.8) * OM@hbiascv), 
                            betaconv((hs[cond] - 0.2)/0.8,  (1 - (hs[cond] - 0.2)/0.8) * OM@hbiascv)) * 0.8
  hsim[!cond] <- 0.2 + rbeta(sum(hs <= 0.6), alphaconv((hs[!cond] - 0.2)/0.8,  (hs[!cond] - 0.2)/0.8 * OM@hbiascv), 
                             betaconv((hs[!cond] - 0.2)/0.8, (hs[!cond] - 0.2)/0.8 * OM@hbiascv)) * 0.8
  hbias <- hsim/hs  # back calculate the simulated bias
  if (OM@hbiascv == 0) hbias <- rep(1, nsim) 
  ObsPars$hbias <- hbias
  
  # --- Simulate error in observed recruitment index ----
  Recerr <- array(rlnorm((nyears + proyears) * nsim, mconv(1, rep(Recsd, (nyears + proyears))), 
                         sdconv(1, rep(Recsd, nyears + proyears))), c(nsim, nyears + proyears))
  
  
  # --- Simulate observation error in BMSY/B0 ---- 
  ntest <- 20  # number of trials  
  BMSY_B0bias <- array(rlnorm(nsim * ntest, mconv(1, OM@BMSY_B0biascv), sdconv(1, OM@BMSY_B0biascv)), dim = c(nsim, ntest))  # trial samples of BMSY relative to unfished  
  # test <- array(BMSY_B0 * BMSY_B0bias, dim = c(nsim, ntest))  # the simulated observed BMSY_B0 
  test <- array(SSBMSY_SSB0 * BMSY_B0bias, dim = c(nsim, ntest))  # the simulated observed BMSY_B0 
  indy <- array(rep(1:ntest, each = nsim), c(nsim, ntest))  # index
  
  # indy[test > 0.9] <- NA  # interval censor
  indy[test > max(0.9, max(SSBMSY_SSB0))] <- NA  # interval censor
  
  BMSY_B0bias <- BMSY_B0bias[cbind(1:nsim, apply(indy, 1, min, na.rm = T))]  # sample such that BMSY_B0<90%
  ObsPars$BMSY_B0bias <- BMSY_B0bias
  
  # --- Implementation error time series ----
  
  TAC_f <- array(rlnorm(proyears * nsim, mconv(TACFrac, TACSD),
                        sdconv(TACFrac, TACSD)), c(nsim, proyears))  # composite of TAC fraction and error
  
  E_f <- array(rlnorm(proyears * nsim, mconv(TAEFrac, TAESD),
                      sdconv(TAEFrac, TAESD)), c(nsim, proyears))  # composite of TAC fraction and error
  
  SizeLim_f<-array(rlnorm(proyears * nsim, mconv(SizeLimFrac, SizeLimSD),
                          sdconv(SizeLimFrac, SizeLimSD)), c(nsim, proyears))  # composite of TAC fraction and error
  
  
  # --- Populate Data object with Historical Data ---- 
  Data <- new("Data", stock = "MSE")  # create a blank DLM data object
  if (reps == 1) Data <- OneRep(Data)  # make stochastic variables certain for only one rep
  Data <- replic8(Data, nsim)  # make nsim sized slots in the DLM data object
  Data@Name <- OM@Name
  Data@Year <- 1:nyears
  Data@Cat <- Cobs
  Data@Ind <- II
  Data@Rec <- apply(N[, 1, , ], c(1, 2), sum) * Recerr[, 1:nyears]
  Data@t <- rep(nyears, nsim)
  Data@AvC <- apply(Cobs, 1, mean)
  Data@Dt <- Dbias * Depletion * rlnorm(nsim, mconv(1, Derr), sdconv(1, Derr))
  Data@Mort <- M * Mbias
  Data@FMSY_M <- FMSY_M * FMSY_Mbias
  # Data@BMSY_B0 <- BMSY_B0 * BMSY_B0bias
  Data@BMSY_B0 <- SSBMSY_SSB0 * BMSY_B0bias
  Data@Cref <- MSY * Crefbias
  Data@Bref <- VBMSY * Brefbias
  Data@Iref <- Iref * Irefbias
  Data@LFC <- LFC * LFCbias
  Data@LFS <- LFS[nyears,] * LFSbias
  Data@CAA <- CAA
  Data@Dep <- Dbias * Depletion * rlnorm(nsim, mconv(1, Derr), sdconv(1, Derr))
  Data@Abun <- A * Abias * rlnorm(nsim, mconv(1, Aerr), sdconv(1, Aerr))
  Data@SpAbun <- Asp * Abias * rlnorm(nsim, mconv(1, Aerr), sdconv(1, Aerr))
  Data@vbK <- K * Kbias
  Data@vbt0 <- t0 * t0bias
  Data@LenCV <- LenCV # * LenCVbias
  Data@vbLinf <- Linf * Linfbias
  Data@L50 <- L50 * lenMbias
  Data@L95 <- L95 * lenMbias
  Data@L95[Data@L95 > 0.9 * Data@vbLinf] <- 0.9 * Data@vbLinf[Data@L95 > 0.9 * Data@vbLinf]  # Set a hard limit on ratio of L95 to Linf
  Data@L50[Data@L50 > 0.9 * Data@L95] <- 0.9 * Data@L95[Data@L50 > 0.9 * Data@L95]  # Set a hard limit on ratio of L95 to Linf
  Data@steep <- hs * hbias
  Data@CAL_bins <- CAL_bins
  Data@CAL <- CAL
  MLbin <- (CAL_bins[1:(length(CAL_bins) - 1)] + CAL_bins[2:length(CAL_bins)])/2
  temp <- CAL * rep(MLbin, each = nsim * nyears)
  Data@ML <- apply(temp, 1:2, sum)/apply(CAL, 1:2, sum)
  Data@Lc <- array(MLbin[apply(CAL, 1:2, which.max)], dim = c(nsim, nyears))
  nuCAL <- CAL
  for (i in 1:nsim) for (j in 1:nyears) nuCAL[i, j, 1:match(max(1, Data@Lc[i, j]), MLbin, nomatch=1)] <- NA
  temp <- nuCAL * rep(MLbin, each = nsim * nyears)
  Data@Lbar <- apply(temp, 1:2, sum, na.rm=TRUE)/apply(nuCAL, 1:2, sum, na.rm=TRUE)
  Data@MaxAge <- maxage
  Data@Units <- "unitless"
  Data@Ref <- OFLreal
  Data@Ref_type <- "Simulated OFL"
  Data@wla <- rep(a, nsim)
  Data@wlb <- rep(b, nsim)
  Data@nareas <- nareas
  
  # put all the operating model parameters in one table
  Data@OM <- data.frame(RefY, M, Depletion, A, SSBMSY_SSB0, FMSY_M, Mgrad, Msd, procsd, Esd, dFfinal, 
                        MSY=MSY, qinc, qcv, FMSY=FMSY, Linf, K, t0, hs, Linfgrad, Kgrad, Linfsd, Ksd, 
                        ageM=ageM[,nyears], L5=L5[nyears, ], LFS=LFS[nyears, ], Vmaxlen=Vmaxlen[nyears, ], LFC, OFLreal, 
                        Spat_targ, Size_area_1, Frac_area_1, Prob_staying, AC, L50, L95, B0, N0, SSB0, BMSY_B0,
                        TACSD,TACFrac,TAESD,TAEFrac,SizeLimSD,SizeLimFrac,Blow,
                        BMSY, SSBMSY=SSBMSY, Mexp, Fdisc, 
                        LR5=LR5[nyears,], LFR=LFR[nyears,], Rmaxlen=Rmaxlen[nyears,], DR=DR[nyears,]) 


  Data@Obs <- as.data.frame(ObsPars) # put all the observation error model parameters in one table
  
  Data@LHYear <- OM@nyears  # Last historical year is nyears (for fixed MPs)
  Data@MPrec <- Cobs[, nyears]
  Data@MPeff <- rep(1, nsim)
  Data@Misc <- vector("list", nsim)
  
  # --- Return Historical Simulations and Data from last historical year ----
  if (Hist) { # Stop the model after historical simulations are complete
    if(!silent) message("Returning historical simulations")
    nout <- t(apply(N, c(1, 3), sum))
    vb <- t(apply(VBiomass, c(1, 3), sum))
    b <- t(apply(Biomass, c(1, 3), sum))
    ssb <- t(apply(SSB, c(1, 3), sum))
    Cc <- t(apply(CB, c(1,3), sum))
    rec <- t(apply(N[, 1, , ], c(1,2), sum))
    
    TSdata <- list(VB=vb, SSB=ssb, Bio=b, Catch=Cc, Rec=rec, N=nout, E_f=E_f,TAC_f=TAC_f,SizeLim_f=SizeLim_f)
    AtAge <- list(Len_age=Len_age, Wt_age=Wt_age, Sl_age=V, Mat_age=Mat_age, 
                  Nage=apply(N, c(1:3), sum), SSBage=apply(SSB, c(1:3), sum), M_ageArray=M_ageArray,
                  Z=Z, FM=FM, FMret=FMret)
    MSYs <- list(MSY=MSY, FMSY=FMSY, VBMSY=VBMSY, UMSY=UMSY, 
                 SSBMSY=SSBMSY, BMSY_B0=BMSY_B0, SSBMSY_SSB0=SSBMSY_SSB0, SSB0=SSB0, B0=B0)
 
    StockPars$Depletion <- Depletion 
    FleetPars$qs <- qs
    SampPars <- c(StockPars, FleetPars, ObsPars, ImpPars)
    Data@Misc <- list()
    HistData <- list(SampPars=SampPars, TSdata=TSdata, AtAge=AtAge, MSYs=MSYs, Data=Data)
    return(HistData)	
  }
  

  
  
  # assign('Data',Data,envir=.GlobalEnv) # for debugging fun
  
  # --- Check MPs ---- 
  if (is.na(MPs[1])) CheckMPs <- TRUE
  if (CheckMPs) {
    if(!silent) message("Determining available methods")  # print an progress report
    PosMPs <- Can(Data, timelimit = timelimit)  # list all the methods that could be applied to a DLM data object 
    if (is.na(MPs[1])) {
      MPs <- PosMPs  # if the user does not supply an argument MPs run the MSE for all available methods
      if(!silent) message("No MPs specified: running all available")
    }
    if (!is.na(MPs[1])) {
      cant <- MPs[!MPs %in% PosMPs]
      if (length(cant) > 0) {
        if(!silent) message("Cannot run some MPs: ")
        if(!silent) print(DLMdiag(Data, "not available", funcs1=cant, timelimit = timelimit))
      }
      MPs <- MPs[MPs %in% PosMPs]  # otherwise run the MSE for all methods that are deemed possible
    }
    if (length(MPs) == 0) {
      if(!silent) message(Cant(Data, timelimit = timelimit))
      stop("MSE stopped: no viable methods \n\n")  # if none of the user specied methods are possible stop the run
    }
  }
  
  ok <- rep(TRUE, length(MPs))
  for (mm in seq_along(MPs)) {
    test <- try(get(MPs[mm]), silent=TRUE)
    if (!class(test) == 'MP') {
      ok[mm] <- FALSE
      if (class(test) == 'try-error') {
        message('Object ', paste(MPs[mm], ""), " does not exist - Ignoring")
      } else message('Dropping MP: ', paste(MPs[mm], ""), " - Not class 'MP'")
    }
    
  }
 
  MPs <- MPs[ok]
  
  nMP <- length(MPs)  # the total number of methods used
  
  if (nMP < 1) stop("No valid MPs found")
  MSElist <- list(Data)[rep(1, nMP)]  # create a data object for each method (they have identical historical data and branch in projected years)
  
  B_BMSYa <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected B_BMSY
  F_FMSYa <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected F_FMSY
  Ba <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected Biomass
  SSBa <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected SSB
  VBa <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected vulnerable biomass
  FMa <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected fishing mortality rate
  Ca <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected removed catch
  CaRet <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected retained catch
  TACa <- array(NA, dim = c(nsim, nMP, proyears))  # store the projected TAC recommendation
  Effort <- array(NA, dim = c(nsim, nMP, proyears))  # store the Effort
  PAAout <- array(NA, dim = c(nsim, nMP, maxage))  # store the population-at-age in last projection year
  CAAout <- array(NA, dim = c(nsim, nMP, maxage))  # store the catch-at-age in last projection year
  CALout <- array(NA, dim = c(nsim, nMP, nCALbins))  # store the population-at-length in last projection year
  
  # SPRa <- array(NA,dim=c(nsim,nMP,proyears)) # store the Spawning Potential Ratio
  
  # --- Calculate MSY statistics for each projection year ----
  MSY_P <- array(MSY, dim=c(nsim, nMP, proyears))
  FMSY_P <- array(FMSY, dim=c(nsim, nMP, proyears))
  SSBMSY_P <- array(SSBMSY, dim=c(nsim, nMP, proyears)) 
  
  if (AnnualMSY) {

    if(!silent) message("Calculating MSY reference points for each projection year")
    for (y in 1:proyears) {
      if(!silent) cat('.')
      if (!silent) flush.console()
      
      MSYrefsYr <- sapply(1:nsim, optMSY_eq, M_ageArray, Wt_age, Mat_age, V, maxage, R0, SRrel, hs, yr=nyears+y)
      
      MSY_P[,,y] <- MSYrefsYr[1, ]
      FMSY_P[,,y] <- MSYrefsYr[2,]
      SSBMSY_P[,,y] <- MSYrefsYr[3,]

    }
    if(!silent) cat("\n")
  }

  
  # --- Begin loop over MPs ----
  mm <- 1 # for debugging
  for (mm in 1:nMP) {  # MSE Loop over methods
    
    if(!silent) message(mm, "/", nMP, " Running MSE for ", MPs[mm])  # print a progress report
    
    # reset selectivity parameters for projections
    L5_P <- L5  
    LFS_P <- LFS
    Vmaxlen_P <- Vmaxlen
    SLarray_P <- SLarray # selectivity at length array - projections
    V_P <- V  #  selectivity at age array - projections
  
    # reset retention parametersfor projections
    LR5_P <- LR5
    LFR_P <- LFR
    Rmaxlen_P <- Rmaxlen
    retA_P <- retA # retention at age array - projections
    retL_P <- retL # retention at length array - projections
    
    Fdisc_P <- Fdisc # Discard mortality for projectons 
    DR_P <- DR # Discard ratio for projections
 
    # projection arrays
    N_P <- array(NA, dim = c(nsim, maxage, proyears, nareas))
    Biomass_P <- array(NA, dim = c(nsim, maxage, proyears, nareas))
    VBiomass_P <- array(NA, dim = c(nsim, maxage, proyears, nareas))
    SSN_P <-array(NA, dim = c(nsim, maxage, proyears, nareas))
    SSB_P <- array(NA, dim = c(nsim, maxage, proyears, nareas))
    FM_P <- array(NA, dim = c(nsim, maxage, proyears, nareas))
    FM_Pret <- array(NA, dim = c(nsim, maxage, proyears, nareas)) # retained F 
    FM_nospace <- array(NA, dim = c(nsim, maxage, proyears, nareas))  # stores prospective F before reallocation to new areas
    FML <- array(NA, dim = c(nsim, nareas))  # last apical F
    Z_P <- array(NA, dim = c(nsim, maxage, proyears, nareas))
    CB_P <- array(NA, dim = c(nsim, maxage, proyears, nareas))
    CB_Pret <- array(NA, dim = c(nsim, maxage, proyears, nareas)) # retained catch 
    
    # indexes
    SAYRL <- as.matrix(expand.grid(1:nsim, 1:maxage, nyears, 1:nareas))  # Final historical year
    SAYRt <- as.matrix(expand.grid(1:nsim, 1:maxage, 1 + nyears, 1:nareas))  # Trajectory year
    SAYR <- as.matrix(expand.grid(1:nsim, 1:maxage, 1, 1:nareas))
    SYt <- SAYRt[, c(1, 3)]
    SAYt <- SAYRt[, 1:3]
    SR <- SAYR[, c(1, 4)]
    SA1 <- SAYR[, 1:2]
    S1 <- SAYR[, 1]
    SY1 <- SAYR[, c(1, 3)]
    SAY1 <- SAYR[, 1:3]
    SYA <- as.matrix(expand.grid(1:nsim, 1, 1:maxage))  # Projection year
    SY <- SYA[, 1:2]
    SA <- SYA[, c(1, 3)]
    SAY <- SYA[, c(1, 3, 2)]
    S <- SYA[, 1]
    
    # -- First projection year ----
    y <- 1
    # 
    NextYrN <- lapply(1:nsim, function(x)
      popdynOneTS(nareas, maxage, SSBcurr=colSums(SSB[x,,nyears, ]), Ncurr=N[x,,nyears,],
                  Zcurr=Z[x,,nyears,], PerrYr=Perr[x, nyears+maxage-1], hc=hs[x],
                  R0c=R0a[x,], SSBpRc=SSBpR[x,], aRc=aR[x], bRc=bR[x],
                  movc=mov[x,,,], SRrelc=SRrel[x]))
   
    N_P[,,1,] <- aperm(array(unlist(NextYrN), dim=c(maxage, nareas, nsim, 1)), c(3,1,4,2))
    Biomass_P[SAYR] <- N_P[SAYR] * Wt_age[SAY1]  # Calculate biomass
    VBiomass_P[SAYR] <- Biomass_P[SAYR] * V_P[SAYt]  # Calculate vulnerable biomass
    SSN_P[SAYR] <- N_P[SAYR] * Mat_age[SAY1]  # Calculate spawning stock numbers
    SSB_P[SAYR] <- SSN_P[SAYR] * Wt_age[SAY1]
    FML <- apply(FM[, , nyears, ], c(1, 3), max)
    
    # -- apply MP in initial projection year ----
    # Combined MP ----
    runMP <- applyMP(MSElist[[mm]], MPs = MPs[mm], reps = reps)  # Apply MP
    MPRecs <- runMP[[1]][[1]] # MP recommendations
    Data <- runMP[[2]] # Data object object with saved info from MP 
    Data@TAC <- MPRecs$TAC
    
    # calculate pstar quantile of TAC recommendation dist 
    TACused <- apply(Data@TAC, 2, quantile, p = pstar, na.rm = T) 
    
    LastEffort <- rep(1,nsim)
    LastSpatial <- array(MPA[nyears,], dim=c(nareas, nsim)) # 
    LastAllocat <- rep(1, nsim) # default assumption of reallocation of effort to open areas
    LastCatch <- apply(CB[,,nyears,], 1, sum)

    MPCalcs <- CalcMPDynamics(MPRecs, y, nyears, proyears, nsim,
                              LastEffort, LastSpatial, LastAllocat, LastCatch,
                              TACused, maxF,
                              LR5_P, LFR_P, Rmaxlen_P, retL_P, retA_P,
                              L5_P, LFS_P, Vmaxlen_P, SLarray_P, V_P,
                              Fdisc_P, DR_P,
                              M_ageArray, FM_P, FM_Pret, Z_P, CB_P, CB_Pret,
                              TAC_f, E_f, SizeLim_f,
                              VBiomass_P, Biomass_P, FinF, Spat_targ,
                              CAL_binsmid, Linf, Len_age, maxage, nareas, Asize, nCALbins,
                              qs, qvar, qinc)
  
    TACa[, mm, y] <- MPCalcs$TACrec # recommended TAC 
    LastSpatial <- MPCalcs$Si
    LastAllocat <- MPCalcs$Ai
    LastEffort <- MPCalcs$Effort
    LastCatch <- MPCalcs$TACrec
    
    Effort[, mm, y] <- MPCalcs$Effort #  
    CB_P <- MPCalcs$CB_P # removals
    CB_Pret <- MPCalcs$CB_Pret # retained catch 
    FM_P <- MPCalcs$FM_P # fishing mortality
    FM_Pret <- MPCalcs$FM_Pret # retained fishing mortality 
    Z_P <- MPCalcs$Z_P # total mortality
    
    retA_P <- MPCalcs$retA_P # retained-at-age
    
    retL_P <- MPCalcs$retL_P # retained-at-length
    V_P <- MPCalcs$V_P  # vulnerable-at-age
    SLarray_P <- MPCalcs$SLarray_P # vulnerable-at-length 
    
    # if (class(match.fun(MPs[mm])) == "Output") {
    #   
    #   # -- output control ----
    #   Data <- Sam(MSElist[[mm]], MPs = MPs[mm], perc = pstar, reps = reps) # apply Output control MP 
    #   TACused <- apply(Data@TAC, 3, quantile, p = pstar, na.rm = T) # calculate pstar quantile of TAC recommendation dist 
    #   
    #   outputcalcs <- CalcOutput(y, Asize, TACused, TAC_f, lastCatch=apply(CB[,,nyears,], 1, sum), 
    #                             availB=MSElist[[mm]]@OM$A, maxF, Biomass_P, VBiomass_P, CB_P, 
    #                             CB_Pret, FM_P, Z_P, Spat_targ, V_P, 
    #                             retA_P, M_ageArray, qs, nyears, nsim, maxage, nareas)
    #   
    #   
    #   TACa[, mm, y] <- outputcalcs$TACrec # recommended TAC 
    #   Effort[, mm, y] <- outputcalcs$Effort #  
    #   CB_P <- outputcalcs$CB_P # removals
    #   CB_Pret <- outputcalcs$CB_Pret # retained catch 
    #   FM_P <- outputcalcs$FM_P # fishing mortality 
    #   Z_P <- outputcalcs$Z_P # total mortality 
    #   
    # 
    # } else if (class(match.fun(MPs[mm])) == "Input") {
    #   # -- input control ----
    #   
    #   runIn <- runInMP(MSElist[[mm]], MPs = MPs[mm], reps = reps)  # Apply input control MP
    #   
    #   Data <- runIn[[2]] # Data object object with saved info from MP 
    #   InputRecs <- runIn[[1]][[1]] # input control recommendations 
    #   
    #   inputcalcs <- CalcInput(y, Linf, Asize, nyears, proyears, InputRecs, nsim, nareas, LR5_P, LFR_P, 
    #                           Rmaxlen_P, maxage, retA_P, retL_P, V_P, V2, SLarray_P, 
    #                           SLarray2, DR, maxlen, Len_age, CAL_binsmid, Fdisc, nCALbins, 
    #                           E_f, SizeLim_f, VBiomass_P, Biomass_P, Spat_targ, FinF, qvar, 
    #                           qs, qinc, CB_P, CB_Pret, FM_P, FM_Pret, Z_P, M_ageArray, 
    #                           LastEffort=rep(1,nsim), LastSpatial=matrix(1, nsim, nareas), 
    #                           LastAllocat=rep(0, nsim))
    #   
    #   LastSpatial <- inputcalcs$Si
    #   LastAllocat <- inputcalcs$Ai
    #   Effort[, mm, y] <- inputcalcs$Effort #  
    #   CB_P <- inputcalcs$CB_P # removals
    #   CB_Pret <- inputcalcs$CB_Pret # retained catch 
    #   FM_P <- inputcalcs$FM_P # fishing mortality
    #   FM_Pret <- inputcalcs$FM_Pret # retained fishing mortality 
    #   Z_P <- inputcalcs$Z_P # total mortality
    # 
    #   retA_P <- inputcalcs$retA_P # retained-at-age
    #   
    #   retL_P <- inputcalcs$retL_P # retained-at-length
    #   V_P <- inputcalcs$V_P  # vulnerable-at-age
    #   SLarray_P <- inputcalcs$pSLarray # vulnerable-at-length 
    # 
    # }  
    # 
    # TACa[, mm, 1] <- apply(CB_P[, , 1, ], 1, sum)  # Adjust TAC to actual catch in the year 
    # To account for years where TAC is higher than catch
    
    upyrs <- 1 + (0:(floor(proyears/interval) - 1)) * interval  # the years in which there are updates (every three years)
    if(!silent) cat(".")
    if(!silent) flush.console()
    
    # --- Begin projection years ----
    for (y in 2:proyears) {
      if(!silent) cat(".")
      if(!silent) flush.console()
      
      SelectChanged <- FALSE
      if (AnnualMSY) {
        if (any(range(retA_P[,,nyears+y] - retA[,,nyears+y]) !=0)) SelectChanged <- TRUE
        if (any(range(V_P[,,nyears+y] - V[,,nyears+y]) !=0))  SelectChanged <- TRUE
      }
      
      # -- Calculate MSY stats for this year ----
      if (AnnualMSY & SelectChanged) { #
        
        MSYrefsYr <- sapply(1:nsim, optMSY_eq, M_ageArray, Wt_age, Mat_age, V_P, maxage, R0, SRrel, hs, yr=nyears+y)
    
        MSY_P[,mm,y] <- MSYrefsYr[1, ]
        FMSY_P[,mm,y] <- MSYrefsYr[2,]
        SSBMSY_P[,mm,y] <- MSYrefsYr[3,]
        
        # M_ageArrayp <- array(M_ageArray[,,nyears+y], dim=c(dim(M_ageArray)[1:2], MSYyr))
        # Wt_agep <- array(Wt_age[,,nyears+y], dim=c(dim(Wt_age)[1:2], MSYyr))
        # retAp <- array(retA_P[,,nyears+y], dim=c(dim(retA)[1:2], MSYyr))
        # Vp <- array(V_P[,,nyears+y], dim=c(dim(V)[1:2], MSYyr))
        # Perrp <- array(1, dim=c(dim(Perr)[1], MSYyr+maxage))
        # Mat_agep <-abind::abind(rep(list(Mat_age[,,nyears+y]), MSYyr), along=3)
        # if (snowfall::sfIsRunning()) {
        #   MSYrefsYr <- snowfall::sfSapply(1:nsim, getFMSY3, Asize, nareas=nareas, maxage=maxage, N=N, pyears=MSYyr,
        #                                   M_ageArray=M_ageArrayp, Mat_age=Mat_agep, Wt_age=Wt_agep, V=Vp, retA=retAp,
        #                                   Perr=Perrp, mov=mov, SRrel=SRrel, Find=Find, Spat_targ=Spat_targ, hs=hs,
        #                                   R0a=R0a, SSBpR=SSBpR, aR=aR, bR=bR, SSB0=SSB0, B0=B0, MPA=noMPA, maxF=maxF)  # optimize for MSY reference points
        # } else {
        #   MSYrefsYr <- sapply(1:nsim, getFMSY3, Asize, nareas=nareas, maxage=maxage, N=N, pyears=MSYyr,
        #                       M_ageArray=M_ageArrayp, Mat_age=Mat_agep, Wt_age=Wt_agep, V=Vp, retA=retAp,
        #                       Perr=Perrp, mov=mov, SRrel=SRrel, Find=Find, Spat_targ=Spat_targ, hs=hs,
        #                       R0a=R0a, SSBpR=SSBpR, aR=aR, bR=bR, SSB0=SSB0, B0=B0, MPA=noMPA, maxF=maxF) # optimize for MSY reference points
        # }
        # MSY_P[, mm, y] <- MSYrefsYr[1, ]
        # FMSY_P[, mm, y] <- MSYrefsYr[2,]
        # SSBMSY_P[, mm, y] <- MSYrefsYr[3,]
      }
      
      TACa[, mm, y] <- TACa[, mm, y-1] # TAC same as last year unless changed 
   
      SAYRt <- as.matrix(expand.grid(1:nsim, 1:maxage, y + nyears, 1:nareas))  # Trajectory year
      SAYt <- SAYRt[, 1:3]
      SAYtMP <- cbind(SAYt, mm)
      SYt <- SAYRt[, c(1, 3)]
      SAY1R <- as.matrix(expand.grid(1:nsim, 1:maxage, y - 1, 1:nareas))
      SAYR <- as.matrix(expand.grid(1:nsim, 1:maxage, y, 1:nareas))
      SY <- SAYR[, c(1, 3)]
      SA <- SAYR[, 1:2]
      S1 <- SAYR[, 1]
      
      SAY <- SAYR[, 1:3]
      S <- SAYR[, 1]
      SR <- SAYR[, c(1, 4)]
      SA2YR <- as.matrix(expand.grid(1:nsim, 2:maxage, y, 1:nareas))
      SA1YR <- as.matrix(expand.grid(1:nsim, 1:(maxage - 1), y -1, 1:nareas))
      
      NextYrN <- lapply(1:nsim, function(x)
        popdynOneTS(nareas, maxage, SSBcurr=colSums(SSB_P[x,,y-1, ]), Ncurr=N_P[x,,y-1,],
                    Zcurr=Z_P[x,,y-1,], PerrYr=Perr[x, y+nyears+maxage-1], hc=hs[x],
                    R0c=R0a[x,], SSBpRc=SSBpR[x,], aRc=aR[x,], bRc=bR[x,],
                    movc=mov[x,,,], SRrelc=SRrel[x]))
      
  
      N_P[,,y,] <- aperm(array(unlist(NextYrN), dim=c(maxage, nareas, nsim, 1)), c(3,1,4,2)) 
      Biomass_P[SAYR] <- N_P[SAYR] * Wt_age[SAYt]  # Calculate biomass
      VBiomass_P[SAYR] <- Biomass_P[SAYR] * V_P[SAYt]  # Calculate vulnerable biomass
      SSN_P[SAYR] <- N_P[SAYR] * Mat_age[SAYt]  # Calculate spawning stock numbers
      SSB_P[SAYR] <- SSN_P[SAYR] * Wt_age[SAYt]  # Calculate spawning stock biomass
    
      # --- An update year ----
      if (y %in% upyrs) {
        # rewrite the DLM object and run the TAC function
        yind <- upyrs[match(y, upyrs) - 1]:(upyrs[match(y, upyrs)] - 1)
        
        # use the retained catch
        CBtemp <-  CB_Pret[, , yind, , drop=FALSE] # retained catch-at-age
        CNtemp <- retA_P[,,yind+nyears, drop=FALSE] * apply(N_P[,,yind,, drop=FALSE], c(1,2,3), sum) # retained age structure
      
        CBtemp[is.na(CBtemp)] <- tiny
        CBtemp[!is.finite(CBtemp)] <- tiny
        CNtemp[is.na(CNtemp)] <- tiny
        CNtemp[!is.finite(CNtemp)] <- tiny
        
        Cobs <- Cbiasa[, nyears + yind] * Cerr[, nyears + yind] * apply(CBtemp, c(1, 3), sum, na.rm = T)
        Cobs[is.na(Cobs)] <- tiny
        Recobs <- Recerr[, nyears + yind] * apply(array(N_P[, 1, yind, ], c(nsim, interval, nareas)), c(1, 2), sum)
       
        CAA <- array(0, dim = c(nsim, interval, maxage))  # Catch  at age array
        # # a multinomial observation model for catch-at-age data
        for (i in 1:nsim) {
          for (j in 1:interval) {
            CAA[i, j, ] <- ceiling(-0.5 + rmultinom(1, CAA_ESS[i], CNtemp[i, , j]) * CAA_nsamp[i]/CAA_ESS[i])   # a multinomial observation model for catch-at-age data
          }
        }	  
        
        ## Calculate CAL ####
        CAL <- array(NA, dim = c(nsim, interval, nCALbins))  # the catch at length array
        # # a multinomial observation model for catch-at-length data
        
        vn <- (apply(N_P[,,,], c(1,2,3), sum) * retA_P[,,(nyears+1):(nyears+proyears)]) # numbers at age that would be retained
        vn <- aperm(vn, c(1,3,2))
        
        # for (i in 1:nsim) { # Rcpp code 
        #   vn2 <- as.matrix(vn[i,yind,])
        #   if (interval == 1) vn2 <- t(vn2) # dodgy hack to ensure matrix is correct
        #   CAL[i, 1:interval, ] <- genLenComp(CAL_bins, CAL_binsmid,
        #                                      as.matrix(retL_P[i,,nyears + yind]),
        #                                      CAL_ESS[i], CAL_nsamp[i], 
        #                                      vn2, as.matrix(Len_age[i,,nyears + yind]), 
        #                                      as.matrix(LatASD[i,, nyears + yind]), truncSD=2) 
        #   LFC[i] <- CAL_binsmid[min(which(round(CAL[i, interval, ],0) >= 1))] # get the smallest CAL observation	
        # }	
        # 
        nyrs <- length(yind)
        if (!is.null(control) && control!=1) {
          # use r version if cpp gives problems
          tempSize <- lapply(1:nsim, makeSizeCompW2, maxage, Linfarray[,nyears + yind, drop=FALSE],
                             Karray[,nyears + yind, drop=FALSE],
                             t0array[,nyears + yind,drop=FALSE],
                             LenCV,
                             CAL_bins, CAL_binsmid,
                             array(retL_P[,,nyears + yind, drop=FALSE], dim=c(nsim,length(CAL_binsmid),nyrs)),
                             CAL_ESS, CAL_nsamp,
                             vn[,yind,, drop=FALSE], truncSD=2)
        } else {
          # use cpp 
          tempSize <- lapply(1:nsim, makeSizeCompW, maxage, Linfarray[,nyears + yind, drop=FALSE],
                             Karray[,nyears + yind, drop=FALSE],
                             t0array[,nyears + yind,drop=FALSE],
                             LenCV,
                             CAL_bins, CAL_binsmid,
                             array(retL_P[,,nyears + yind, drop=FALSE], dim=c(nsim,length(CAL_binsmid),nyrs)),
                             CAL_ESS, CAL_nsamp,
                             vn[,yind,, drop=FALSE], truncSD=2)
        }
        

        CAL <- aperm(array(as.numeric(unlist(tempSize, use.names=FALSE)), dim=c(nyrs, length(CAL_binsmid), nsim)), c(3,1,2))

        # for (sim in 1:OM@nsim) {
        #   CAL[sim,,] <- makeSizeCompW(sim, maxage, Linfarray[,nyears + yind, drop=FALSE],
        #                               Karray[,nyears + yind, drop=FALSE],
        #                               t0array[,nyears + yind,drop=FALSE],
        #                               LenCV,
        #                               CAL_bins, CAL_binsmid,
        #                               array(retL_P[,,nyears + yind, drop=FALSE], dim=c(nsim,length(CAL_binsmid),nyrs)),
        #                               CAL_ESS, CAL_nsamp,
        #                               vn[,yind,, drop=FALSE], truncSD=2)
        #   
        #   
        #   
        # }
        for (i in 1:nsim) {
          ind <- round(CAL[i,nyrs, ],0) >= 1
          if (sum(ind)>0) {
            LFC[i] <- CAL_binsmid[min(which(ind))] # get the smallest CAL observation
          } else {
            LFC[i] <- 0
          }
        }
        
        I2 <- cbind(apply(Biomass, c(1, 3), sum), apply(Biomass_P, c(1, 3), sum)[, 1:(y - 1)]) * 
          Ierr[, 1:(nyears + (y - 1))]^betas
        I2[is.na(I2)] <- tiny
        I2 <- I2/apply(I2, 1, mean)
        
        Depletion <- apply(SSB_P[, , y, ], 1, sum)/SSB0 # apply(SSB[, , 1, ], 1, sum)
        Depletion[Depletion < tiny] <- tiny

        # A <- apply(VBiomass_P[, , y, ], 1, sum)
      
        # Calculate abundance after recruitment and movement - project forward with no F
        NextYrNtemp <- lapply(1:nsim, function(x)
          popdynOneTS(nareas, maxage, SSBcurr=colSums(SSB_P[x,,y, ]), Ncurr=N_P[x,,y,],
                      Zcurr=matrix(M_ageArray[x,,y+nyears], nrow=maxage, ncol=nareas, byrow=TRUE),
                      PerrYr=Perr[x, y+nyears+maxage-1], hc=hs[x],
                      R0c=R0a[x,], SSBpRc=SSBpR[x,], aRc=aR[x,], bRc=bR[x,],
                      movc=mov[x,,,], SRrelc=SRrel[x]))

        N_PNext <- aperm(array(unlist(NextYrNtemp), dim=c(maxage, nareas, nsim, 1)), c(3,1,4,2))
        VBiomassNext <- VBiomass_P
        VBiomassNext[SAYR] <- N_PNext * Wt_age[SAYt] * V_P[SAYt]  # Calculate vulnerable for abundance

        A <- apply(VBiomassNext[, , y, ], 1, sum)
        # A <- apply(VBiomass_P[, , y, ], 1, sum)
        
        A[is.na(A)] <- tiny
        Asp <- apply(SSB_P[, , y, ], 1, sum)  # SSB Abundance
        Asp[is.na(Asp)] <- tiny
        OFLreal <- A * FMSY_P[,mm,y]
        
        # - update data object ---- 
        # assign all the new data
        MSElist[[mm]]@OM$A <- A
        MSElist[[mm]]@Year <- 1:(nyears + y - 1)
        MSElist[[mm]]@Cat <- cbind(MSElist[[mm]]@Cat, Cobs)
        MSElist[[mm]]@Ind <- I2
        MSElist[[mm]]@Rec <- cbind(MSElist[[mm]]@Rec, Recobs)
        MSElist[[mm]]@t <- rep(nyears + y, nsim)
        MSElist[[mm]]@AvC <- apply(MSElist[[mm]]@Cat, 1, mean)
        MSElist[[mm]]@Dt <- Dbias * Depletion * rlnorm(nsim, mconv(1, Derr), sdconv(1, Derr))
        oldCAA <- MSElist[[mm]]@CAA
        MSElist[[mm]]@CAA <- array(0, dim = c(nsim, nyears + y - 1, maxage))
        MSElist[[mm]]@CAA[, 1:(nyears + y - interval - 1), ] <- oldCAA[, 1:(nyears + y - interval - 1), ] # there is some bug here sometimes oldCAA (MSElist[[mm]]@CAA previously) has too many years of observations
        MSElist[[mm]]@CAA[, nyears + yind, ] <- CAA
        MSElist[[mm]]@Dep <- Dbias * Depletion * rlnorm(nsim, mconv(1, Derr), sdconv(1, Derr))
        MSElist[[mm]]@Abun <- A * Abias * rlnorm(nsim, mconv(1, Aerr), sdconv(1, Aerr))
        MSElist[[mm]]@SpAbun <- Asp * Abias * rlnorm(nsim, mconv(1, Aerr), sdconv(1, Aerr))
        MSElist[[mm]]@CAL_bins <- CAL_bins
        oldCAL <- MSElist[[mm]]@CAL
        MSElist[[mm]]@CAL <- array(0, dim = c(nsim, nyears + y - 1, nCALbins))
        MSElist[[mm]]@CAL[, 1:(nyears + y - interval - 1), ] <- oldCAL[, 1:(nyears + y - interval - 1), ]# there is some bug here: sometimes oldCAL (MSElist[[mm]]@CAL previously) has too many years of observations
        MSElist[[mm]]@CAL[, nyears + yind, ] <- CAL[, 1:interval, ]
        
        temp <- CAL * rep(MLbin, each = nsim * interval)
        MSElist[[mm]]@ML <- cbind(MSElist[[mm]]@ML, apply(temp, 1:2, sum)/apply(CAL, 1:2, sum))
        MSElist[[mm]]@Lc <- cbind(MSElist[[mm]]@Lc, array(MLbin[apply(CAL, 1:2, which.max)], dim = c(nsim, interval)))
        nuCAL <- CAL
        for (i in 1:nsim) for (j in 1:interval) nuCAL[i, j, 1:match(max(1, MSElist[[mm]]@Lc[i, j]), MLbin,nomatch=1)] <- NA 
        temp <- nuCAL * rep(MLbin, each = nsim * interval)
        MSElist[[mm]]@Lbar <- cbind(MSElist[[mm]]@Lbar, apply(temp,1:2, sum, na.rm=TRUE)/apply(nuCAL, 1:2, sum, na.rm=TRUE))
        
        MSElist[[mm]]@LFC <- LFC * LFCbias
        MSElist[[mm]]@LFS <- LFS[nyears + y,] * LFSbias 
        
        # update growth, maturity estimates for current year
        MSElist[[mm]]@vbK <-  Karray[, nyears+y] * Kbias
        MSElist[[mm]]@vbt0 <- t0 * t0bias

        MSElist[[mm]]@vbLinf <- Linfarray[, nyears+y] * Linfbias
        MSElist[[mm]]@L50 <- L50array[, nyears+y] * lenMbias
        MSElist[[mm]]@L95 <- L95array[, nyears+y] * lenMbias
        MSElist[[mm]]@L95[is.na(MSElist[[mm]]@L95)]<-MSElist[[mm]]@vbLinf # this is just to robustify 'numbers models' like Grey Seal that do not generate (and will never use) real length observations
        MSElist[[mm]]@L95[MSElist[[mm]]@L95 > 0.9 * MSElist[[mm]]@vbLinf] <- 0.9 * MSElist[[mm]]@vbLinf[MSElist[[mm]]@L95 > 0.9 * MSElist[[mm]]@vbLinf]  # Set a hard limit on ratio of L95 to Linf
        MSElist[[mm]]@L50[MSElist[[mm]]@L50 > 0.9 * MSElist[[mm]]@L95] <- 0.9 * MSElist[[mm]]@L95[MSElist[[mm]]@L50 > 0.9 * MSElist[[mm]]@L95]  # Set a hard limit on ratio of L95 to Linf
        
        MSElist[[mm]]@Ref <- OFLreal
        MSElist[[mm]]@Ref_type <- "Simulated OFL"
        MSElist[[mm]]@Misc <- Data@Misc
        
        # assign('Data',MSElist[[mm]],envir=.GlobalEnv) # for debugging fun
        
        # apply combined MP ----
        runMP <- applyMP(MSElist[[mm]], MPs = MPs[mm], reps = reps)  # Apply MP
        
        MPRecs <- runMP[[1]][[1]] # MP recommendations
        Data <- runMP[[2]] # Data object object with saved info from MP 
        Data@TAC <- MPRecs$TAC
        
        # calculate pstar quantile of TAC recommendation dist 
        TACused <- apply(Data@TAC, 2, quantile, p = pstar, na.rm = T) 
        
        MPCalcs <- CalcMPDynamics(MPRecs, y, nyears, proyears, nsim,
                                  LastEffort, LastSpatial, LastAllocat, LastCatch,
                                  TACused, maxF,
                                  LR5_P, LFR_P, Rmaxlen_P, retL_P, retA_P,
                                  L5_P, LFS_P, Vmaxlen_P, SLarray_P, V_P,
                                  Fdisc_P, DR_P,
                                  M_ageArray, FM_P, FM_Pret, Z_P, CB_P, CB_Pret,
                                  TAC_f, E_f, SizeLim_f,
                                  VBiomass_P, Biomass_P, FinF, Spat_targ,
                                  CAL_binsmid, Linf, Len_age, maxage, nareas, Asize,  nCALbins,
                                  qs, qvar, qinc)

        TACa[, mm, y] <- MPCalcs$TACrec # recommended TAC 
        LastSpatial <- MPCalcs$Si
        LastAllocat <- MPCalcs$Ai
        LastEffort <- MPCalcs$Effort
 
        
        Effort[, mm, y] <- MPCalcs$Effort #  
        CB_P <- MPCalcs$CB_P # removals
        CB_Pret <- MPCalcs$CB_Pret # retained catch 
        
        LastCatch <- apply(CB_Pret[,,y,], 1, sum, na.rm=TRUE) 
      
        FM_P <- MPCalcs$FM_P # fishing mortality
        FM_Pret <- MPCalcs$FM_Pret # retained fishing mortality 
        Z_P <- MPCalcs$Z_P # total mortality
        
        retA_P <- MPCalcs$retA_P # retained-at-age
        retL_P <- MPCalcs$retL_P # retained-at-length
        V_P <- MPCalcs$V_P  # vulnerable-at-age
        SLarray_P <- MPCalcs$SLarray_P # vulnerable-at-length
        
        MSElist[[mm]]@MPrec <- apply(CB_Pret[, , y, ], 1, sum)
        
        # if (class(match.fun(MPs[mm])) == "Output") {
        #   # output control ---- 
        #   Data <- Sam(MSElist[[mm]], MPs = MPs[mm], perc = pstar, reps = reps)
        #   TACused <- apply(Data@TAC, 3, quantile, p = pstar, na.rm = TRUE)  #
        #   
        #   TACa[, mm, y] <- TACused # recommended TAC 
        #   
        #   outputcalcs <- CalcOutput(y, Asize, TACused, TAC_f, lastCatch=apply(CB_P[,,y-1,], 1, sum), 
        #                             availB=MSElist[[mm]]@OM$A, maxF, Biomass_P, VBiomass_P, 
        #                             CB_P, CB_Pret, FM_P, Z_P, Spat_targ, V_P, 
        #                             retA_P, M_ageArray, qs, nyears, nsim, maxage, nareas)
        #   
        #   Effort[, mm, y] <- outputcalcs$Effort #  
        #   CB_P <- outputcalcs$CB_P # removals
        #   CB_Pret <- outputcalcs$CB_Pret # retained catch 
        #   FM_P <- outputcalcs$FM_P # fishing mortality 
        #   Z_P <- outputcalcs$Z_P # total mortality 
        #   
        # } else {
        #   # input control ----
        #   runIn <- runInMP(MSElist[[mm]], MPs = MPs[mm], reps = reps)  # Apply input control MP
        #   
        #   Data <- runIn[[2]] # Data object object with saved info from MP 
        #   InputRecs <- runIn[[1]][[1]] # input control recommendations 
        #   
        #   inputcalcs <- CalcInput(y, Linf, Asize, nyears, proyears, InputRecs, nsim, nareas, 
        #                           LR5_P, LFR_P, Rmaxlen_P, maxage,
        #                           retA_P, retL_P, V_P, V2, SLarray_P, SLarray2, 
        #                           DR, maxlen, Len_age, CAL_binsmid, Fdisc, 
        #                           nCALbins, E_f, SizeLim_f,
        #                           VBiomass_P, Biomass_P, Spat_targ, FinF, qvar, 
        #                           qs, qinc, CB_P, CB_Pret, FM_P, FM_Pret, 
        #                           Z_P, M_ageArray, Effort[, mm, y-1],
        #                           LastSpatial=LastSpatial, LastAllocat=LastAllocat)
        #   
        #   LastSpatial <- inputcalcs$Si
        #   LastAllocat <- inputcalcs$Ai
        #   
        #   Effort[, mm, y] <- inputcalcs$Effort #  
        #   CB_P <- inputcalcs$CB_P # removals
        #   CB_Pret <- inputcalcs$CB_Pret # retained catch 
        #   FM_P <- inputcalcs$FM_P # fishing mortality
        #   FM_Pret <- inputcalcs$FM_Pret # retained fishing mortality 
        #   Z_P <- inputcalcs$Z_P # total mortality
        #   retA_P <- inputcalcs$retA_P # retained-at-age
        #   retL_P <- inputcalcs$retL_P # retained-at-length
        #   V_P <- inputcalcs$V_P  # vulnerable-at-age
        #   
        #   SLarray_P <- inputcalcs$pSLarray # vulnerable-at-length 
        # }  # input control 
        # MSElist[[mm]]@MPrec <- apply(CB_Pret[, , y, ], 1, sum) 
      } else {
        # --- Not an update yr ----
       
        NoMPRecs <- MPRecs 
        NoMPRecs[lapply(NoMPRecs, length) > 0 ] <- NULL
        NoMPRecs$Spatial <- NA
        
        MPCalcs <- CalcMPDynamics(NoMPRecs, y, nyears, proyears, nsim,
                                  LastEffort, LastSpatial, LastAllocat, LastCatch,
                                  TACused, maxF,
                                  LR5_P, LFR_P, Rmaxlen_P, retL_P, retA_P,
                                  L5_P, LFS_P, Vmaxlen_P, SLarray_P, V_P,
                                  Fdisc_P, DR_P,
                                  M_ageArray, FM_P, FM_Pret, Z_P, CB_P, CB_Pret,
                                  TAC_f, E_f, SizeLim_f,
                                  VBiomass_P, Biomass_P, FinF, Spat_targ,
                                  CAL_binsmid, Linf, Len_age, maxage, nareas, Asize,  nCALbins,
                                  qs, qvar, qinc)
        
        TACa[, mm, y] <- MPCalcs$TACrec # recommended TAC 
        LastSpatial <- MPCalcs$Si
        LastAllocat <- MPCalcs$Ai
        LastEffort <- MPCalcs$Effort
        # LastCatch <- MPCalcs$TACrec
        Effort[, mm, y] <- MPCalcs$Effort #  
        CB_P <- MPCalcs$CB_P # removals
        CB_Pret <- MPCalcs$CB_Pret # retained catch 
        
        LastCatch <- apply(CB_Pret[,,y,], 1, sum, na.rm=TRUE) 
        
        FM_P <- MPCalcs$FM_P # fishing mortality
        FM_Pret <- MPCalcs$FM_Pret # retained fishing mortality 
        Z_P <- MPCalcs$Z_P # total mortality
        
        retA_P <- MPCalcs$retA_P # retained-at-age
        retL_P <- MPCalcs$retL_P # retained-at-length
        V_P <- MPCalcs$V_P  # vulnerable-at-age
        SLarray_P <- MPCalcs$SLarray_P # vulnerable-at-length
        
        
        # if (class(match.fun(MPs[mm])) == "Output") {
        #   # TAC remains same as last year
        #   outputcalcs <- CalcOutput(y, Asize, TACa[, mm, y], TAC_f, lastCatch=apply(CB_P[,,y-1,], 1, sum), 
        #                             availB=MSElist[[mm]]@OM$A, maxF, Biomass_P, VBiomass_P, CB_P, CB_Pret, FM_P, Z_P, Spat_targ, V_P, 
        #                             retA_P, M_ageArray, qs, nyears, nsim, maxage, nareas)
        #   
        #   Effort[, mm, y] <- outputcalcs$Effort #  
        #   CB_P <- outputcalcs$CB_P # removals
        #   CB_Pret <- outputcalcs$CB_Pret # retained catch 
        #   FM_P <- outputcalcs$FM_P # fishing mortality 
        #   Z_P <- outputcalcs$Z_P # total mortality 
        #   
        # } else {
        #   # input control FM_P[SAYR] <- FM_P[SAY1R]*qvar[SY] *(1+qinc[S1]/100)^y
        #   # # add fishing efficiency changes and variability
        #   FM_P[SAYR] <- (FM_P[SAY1R] * qvar[SY] * (1 + qinc[S1]/100))  # add fishing efficiency changes and variability
        #   FM_Pret[SAYR] <- (FM_Pret[SAY1R] * qvar[SY] * (1 + qinc[S1]/100))  # add fishing efficiency changes and variability
        #   Effort[, mm, y] <-  Effort[, mm, y-1] / E_f[,y-1]  * E_f[,y]   # Effort doesn't change in non-update year
        #   
        #   Z_P[SAYR] <- FM_P[SAYR] + M_ageArray[SAYt]
        #   
        #   CB_P[SAYR] <- FM_P[SAYR]/Z_P[SAYR] * Biomass_P[SAYR] * (1 - exp(-Z_P[SAYR]))
        #   CB_Pret[SAYR] <- FM_Pret[SAYR]/Z_P[SAYR] * Biomass_P[SAYR] * (1 - exp(-Z_P[SAYR]))
        # }
        
      }  # not an update year
    }  # end of year
    
    B_BMSYa[, mm, ] <- apply(SSB_P, c(1, 3), sum, na.rm=TRUE)/SSBMSY_P[,mm,]  # SSB relative to SSBMSY
 
    FMa[, mm, ] <- -log(1 - apply(CB_P, c(1, 3), sum, na.rm=TRUE)/apply(VBiomass_P+CB_P, c(1, 3), sum, na.rm=TRUE))		
    F_FMSYa[, mm, ] <- FMa[, mm, ]/FMSY_P[,mm,]
    
    Ba[, mm, ] <- apply(Biomass_P, c(1, 3), sum, na.rm=TRUE) # biomass 
    SSBa[, mm, ] <- apply(SSB_P, c(1, 3), sum, na.rm=TRUE) # spawning stock biomass
    VBa[, mm, ] <- apply(VBiomass_P, c(1, 3), sum, na.rm=TRUE) # vulnerable biomass
    
    Ca[, mm, ] <- apply(CB_P, c(1, 3), sum, na.rm=TRUE) # removed
    CaRet[, mm, ] <- apply(CB_Pret, c(1, 3), sum, na.rm=TRUE) # retained catch 
    
    # Store Pop and Catch-at-age and at-length for last projection year 
    PAAout[ , mm, ] <- apply(N_P[ , , proyears, ], c(1,2), sum) # population-at-age
    
    CNtemp <- apply(CB_Pret, c(1,2,3), sum)/Wt_age[(nyears+1):nyears+proyears]
    CAAout[ , mm, ] <- CNtemp[,,proyears] # nsim, maxage # catch-at-age
    CALout[ , mm, ] <- CAL[,max(dim(CAL)[2]),] # catch-at-length in last year
    
    if (!silent) cat("\n")
  }  # end of mm methods 
  
  # Miscellaneous reporting
  if(PPD)Misc<-MSElist
  
  ## Create MSE Object #### 
  MSEout <- new("MSE", Name = OM@Name, nyears, proyears, nMPs=nMP, MPs, nsim, 
                Data@OM, Obs=Data@Obs, B_BMSY=B_BMSYa, F_FMSY=F_FMSYa, B=Ba, 
                SSB=SSBa, VB=VBa, FM=FMa, CaRet, TAC=TACa, SSB_hist = SSB, CB_hist = CB, 
                FM_hist = FM, Effort = Effort, PAA=PAAout, CAA=CAAout, CAL=CALout, CALbins=CAL_binsmid,
                Misc = Misc)
  # Store MSE info
  attr(MSEout, "version") <- packageVersion("DLMtool")
  attr(MSEout, "date") <- date()
  attr(MSEout, "R.version") <- R.version	
  
  MSEout 
}




#' Internal function of runMSE for checking that the OM slot cpars slot is formatted correctly
#'
#' @param cpars a list of model parameters to be sampled (single parameters are a vector nsim long, time series are matrices nsim x nyears)
#' @return either an error and the length of the first dimension of the various cpars list items or passes and returns the number of simulations
#' @export cparscheck
#' @author T. Carruthers
cparscheck<-function(cpars){

  dim1check<-function(x){
    if(class(x)=="numeric")length(x)
    else dim(x)[1]
  }

  dims<-sapply(cpars,dim1check)
  if(length(unique(dims))!=1){
    print(dims)
    stop("The custom parameters in your operating model @cpars have varying number of simulations. For each simulation each parameter / variable should correspond with one another")
  }else{
    as.integer(dims[1])
  }

}


cparnamecheck<-function(cpars){

  Sampnames <- c("D","Esd","Find","procsd","AC","M","Msd",
                 "Mgrad","hs","Linf","Linfsd","Linfgrad",
                 "K","Ksd","Kgrad","t0","L50","L50_95","Spat_targ",
                 "Frac_area_1","Prob_staying",
                 "Csd","Cbias","CAA_nsamp","CAA_ESS","CAL_nsamp",
                 "CAL_ESS","betas","Isd","Derr","Dbias",
                 "Mbias","FMSY_Mbias","lenMbias","LFCbias",
                 "LFSbias","Aerr","Abias","Kbias","t0bias",
                 "Linfbias","Irefbias","Crefbias","Brefbias",
                 "Recsd","qinc","qcv","L5","LFS","Vmaxlen","L5s",
                 "LFSs","Vmaxlens","Perr","R0","Mat_age",
                 "Mrand","Linfrand","Krand","maxage","V","Depletion", # end of OM variables
                 "ageM", "age95", "V", "EffYears", "EffLower", "EffUpper","Mat_age", # start of runMSE derived variables
                 "Wt_age")

}


#' Run a Management Strategy Evaluation
#' 
#' Run a Management Strategy Evaluation and save out the results to a Rdata
#' file.  To increase speed and efficiency, particulary for runs with a large
#' number simulations (\code{nsim}), the simulations are split into a number of
#' packets.  The functions loops over the packets and combines the output into
#' a single MSE object. If the MSE model crashes during a run, the MSE is run
#' again until it is successfully completed. The MSE is stopped if the number
#' of consecutive crashes exceeds \code{maxCrash}.  There is an ption to save
#' the packets as Rdata files to the current working directory (default is
#' FALSE). By default, the functions saves the completed MSE object as a Rdata
#' file (to the current working directory).
#' 
#' @param OM An operating model object (class OM)
#' @param MPs A vector of methods (character string) of class Output or
#' Input.
#' @param timelimit Maximum time taken for a method to carry out 10 reps
#' (methods are ignored that take longer)
#' @param CheckMPs Logical to indicate if Can function should be used to check
#' if MPs can be run.
#' @param Hist Should model stop after historical simulations? Returns a list 
#' containing all historical data
#' @param ntrials Maximum of times depletion and recruitment deviations are 
#' resampled to optimize for depletion. After this the model stops if more than 
#' percent of simulations are not close to the required depletion
#' @param fracD maximum allowed proportion of simulations where depletion is not 
#' close to sampled depletion from OM before model stops with error
#' @param CalcBlow Should low biomass be calculated where this is the spawning
#' biomass at which it takes HZN mean generation times of zero fishing to reach 
#' @param HZN The number of mean generation times required to reach Bfrac SSBMSY
#' in the Blow calculation
#' @param Bfrac fraction of SSBMSY
#' @param AnnualMSY Logical. Should MSY statistics be calculated for each projection year? 
#' @param maxsims Maximum number of simulations per packet
#' @param name Character string for name of saved MSE packets (if \code{savePack=TRUE}) 
#' and final MSE object. If none provided, it uses the first five letters from the \code{OM} name
#' @param unique Logical. Should the name be unique? Current date and time appended to name. 
#' @param maxCrash Maximum number of consecutive crashes before the MSE stops
#' @param saveMSE Logical to indicate if final MSE object should be saved to current 
#' working directory (this is probably a good idea)
#' @param savePack Logical to indicate if packets should be save to current working directory
#' @return An object of class MSE
#' @author A. Hordyk and T. Carruthers
#' @export runMSErobust
runMSErobust <- function(OM = DLMtool::testOM, MPs = c("AvC", "DCAC", "FMSYref", "curE", "matlenlim", "MRreal"), 
                         timelimit = 1, CheckMPs = FALSE, Hist = FALSE, 
                         ntrials = 50, fracD = 0.05, CalcBlow = FALSE, HZN = 2, Bfrac = 0.5, AnnualMSY=TRUE,
                         maxsims = 64, name = NULL, unique=FALSE, maxCrash = 10, saveMSE = TRUE, 
                         savePack = FALSE) {
  
  if (!snowfall::sfIsRunning()) {
    message("Setting up parallel processing")
    setup()
  }
  
  if (class(OM) != "OM") stop("You must specify an operating model")
  cpars <- NULL
  ncparsim <- nsim
  if(length(OM@cpars)>0){
    ncparsim<-cparscheck(OM@cpars)   # check each list object has the same length and if not stop and error report
    cpars <- OM@cpars
  }
  
  # Backwards compatible with DLMtool v < 4
  if("nsim"%in%slotNames(OM))nsim<-OM@nsim
  if("proyears"%in%slotNames(OM))proyears<-OM@proyears
  
  OM@proyears<-proyears
  
  packets <- new("list")  # a list of completed MSE objects
  simsplit <- split(1:nsim, ceiling(seq_along(1:nsim)/maxsims))  # split the runs
  message(nsim, " simulations \n")
  message("Splitting into ", length(simsplit), " packets")
  flush.console()  
  
  # set name for saved MSE object 
  if (is.null(name)) {
    st <- as.numeric(regexpr(":", OM@Name)) + 1
    nd <- st + 4  # as.numeric(regexpr(' ', OM@Name))-1
    name <- substr(OM@Name, st, nd)
    name <- gsub("\\s+", "", name)
  }
  if (nchar(name) < 1)  name <- "MSE"
  if (unique) name <- paste0(name, "_", format(Sys.time(), "%H%M_%m%d%y"))
  
  stElap <- rep(NA, length(simsplit)) # store elapsed time 
  
  index <- 1:nsim
  
  
  for (i in 1:length(simsplit)) {
    message("Packet ", i, " of ", length(simsplit), " started")
    error <- 1
    crash <- 0
    st <- Sys.time()
    while (error == 1 & crash <= maxCrash) {
      assign("last.warning", NULL, envir = baseenv())
      tryOM <- OM
      tryOM@seed <- OM@seed + i + crash  # change seed 
      tryOM@nsim <- length(simsplit[[i]]) # sub number of sims 
      if (length(cpars) > 0) tryOM@cpars  <- SampleCpars(cpars, nsim=tryOM@nsim, msg=FALSE)
      
      trialMSE <- try(runMSE(OM = tryOM, MPs = MPs, timelimit = timelimit, CheckMPs = CheckMPs, 
                             Hist=Hist, ntrials=ntrials, fracD=fracD, CalcBlow = CalcBlow, HZN = HZN, 
                             Bfrac = Bfrac, AnnualMSY=AnnualMSY, parallel=TRUE))	
      
      if (!Hist & class(trialMSE) != "MSE") {
        crash <- crash + 1
        print(warnings())
        message("Packet ", i, " crashed. Trying again\n")
      }
      if (Hist & class(trialMSE) != "list") {
        crash <- crash + 1
        print(warnings())
        message("Packet ", i, " crashed. Trying again\n")
      }     
      if (crash >= maxCrash) stop("\nNumber of crashes exceeded 'maxCrash'\n", call.=FALSE)
      
      if (class(trialMSE) == "MSE" | class(trialMSE) == "list") {
        packets[[i]] <- trialMSE
        fname <- paste0(name, "_P", i, ".rdata")
        if (savePack) {
          saveRDS(trialMSE, file = fname)
          message("Saving" , fname, " to ", getwd())
          flush.console()
        }	
        error <- 0
        crash <- 0
      }
    }
    elapse <- Sys.time() - st 
    stElap[i] <- elapse
    message("Packet ", i, " of ", length(simsplit), " complete\n")
    flush.console()
    eta <- round(mean(stElap, na.rm=TRUE) * length(simsplit) - sum(stElap, na.rm=TRUE), 2)
    units <- attributes(elapse)$units
    if (eta > 120 && units == "secs") {
      eta <- round(eta/60,2)
      units <- "mins"
    }
    if (i != length(simsplit)) message("\nEstimated time to completion is: ", eta, " ", units)
    flush.console()
    
  }
  if (i == 1) MSEobj <- packets[[1]]
  
  if (i > 1 & ! Hist) MSEobj <- joinMSE(MSEobjs = packets)
  if (i > 1 & Hist) MSEobj <- unlist(packets,F)
  if (saveMSE) {
    fname <- paste0(name, ".rdata")
    saveRDS(MSEobj, file = fname)
    message("Saving ", fname, " to ", getwd())
    flush.console()
  }
  MSEobj
}

