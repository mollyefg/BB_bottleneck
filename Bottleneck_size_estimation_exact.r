# This code requires use of the R package rmutil 
library(rmutil)
library(argparse)
args <- commandArgs(trailingOnly = TRUE)
if (length(args)!=6) {
  print(length(args))
  stop("Six input arguments are required - list of donor frequencies, list of recipient total reads, list of recipient variant reads, variant calling threshold, minimum bottleneck size, maximum bottleneck size", call.=FALSE)
}

#var_calling_threshold_table  <-  read.table(args[4]) #var_calling_threshold_dummy[1, 1] 

donor_freqs_observed <- read.table(args[1])
n_variants <- nrow(donor_freqs_observed)
recipient_total_reads <- read.table(args[2])
recipient_var_reads_observed <- read.table(args[3])
var_calling_threshold  <- as.double(args[4])
Nb_min <-  as.integer(args[5])
Nb_max <- as.integer(args[6])
num_NB_values <- Nb_max -Nb_min + 1
likelihood_matrix <- matrix( 0, n_variants, num_NB_values)
log_likelihood_matrix <- matrix( 0, n_variants, num_NB_values)
log_likelihood_function <- matrix( 0, Nb_max)
# create array of likelihoods for every variant and every Nb value
##########################################################################
########################################################################
for (i in 1:n_variants) {for (j in 1:num_NB_values) {
  Nb_val <- (j - 1 + Nb_min)
  nu_donor <- donor_freqs_observed[i, 1]
  variant_reads <- recipient_var_reads_observed[i, 1]
  total_reads <- recipient_total_reads[i, 1] 
   if (variant_reads >= var_calling_threshold*total_reads)
   	    { # implement variant calling threshold
    for (k in 0:Nb_val){  
	alpha <- k
	beta <- (Nb_val - k)
	if (alpha == 0)
   	    { alpha <- 0.00001 }
   	if (beta == 0)
   	    { beta <- 0.00001 }
    m <- alpha/(alpha + beta)
	s <- (alpha + beta)
    likelihood_matrix[i, j] <- likelihood_matrix[i, j] + 
	(dbetabinom( variant_reads, total_reads, m, s, log = FALSE)*dbinom(k, size=Nb_val, prob= nu_donor)) 
	     }
	log_likelihood_matrix[i,j] = log(likelihood_matrix[i, j])  
	 }
   if (variant_reads < var_calling_threshold*total_reads)
   	    { # implement variant calling threshold
   likelihood_matrix[i, j] = 0
   log_likelihood_matrix[i,j] = 0
   for (k in 0:Nb_val){  
	alpha <- k
	beta <- (Nb_val - k)	
	if (alpha == 0)
   	    { alpha <- 0.00001 }
    if (beta == 0)
   	    { beta <- 0.00001 }
    m <- alpha/(alpha + beta)
	s <- (alpha + beta)
    likelihood_matrix[i, j] <- likelihood_matrix[i, j] + 
	(pbetabinom( floor(var_calling_threshold*total_reads), total_reads, m, s)*dbinom(k, size=Nb_val, prob= nu_donor)) 
	}
    log_likelihood_matrix[i,j] = log(likelihood_matrix[i, j])
         }
# Now we sum over log likelihoods of the variants at different loci to get the total log likelihood for each value of Nb
log_likelihood_function[Nb_val] <- log_likelihood_function[Nb_val] + log_likelihood_matrix[i,j]
}}
############################################################
############################################################
for (h in 1:(Nb_min )){  
		if(h< Nb_min)
		{log_likelihood_function[h] = - 999999999}	      # kludge for ensuring that these values less than Nb_min don't interfere with our search for the max of log likelihood in the interval of Nb_min to Nb_max
	  }
max_log_likelihood = which(log_likelihood_function == max(log_likelihood_function))  ## This is the point on the x-axis (bottleneck size) at which log likelihood is maximized
max_val =  max(log_likelihood_function)
CI_height = max_val - 1.92  # This value (  height on y axis) determines the confidence intervals using the likelihood ratio test
CI_index_lower = Nb_min
CI_index_upper = max_log_likelihood
for (h in 1:Nb_min){  
		if(h< Nb_min)
		{log_likelihood_function[h] = NA}	  #  Removing parameter values less than Nb_min from plot
	      }
## above loop just enforces our minimum bottleneck cutoff
for (h in Nb_min:max_log_likelihood){  
		test1 = (log_likelihood_function[CI_index_lower] - CI_height) * (log_likelihood_function[CI_index_lower] - CI_height)
		test2 = (log_likelihood_function[h] - CI_height) * (log_likelihood_function[h] - CI_height)
        if( test2 < test1){  CI_index_lower = h  }  			
}
if(  (log_likelihood_function[CI_index_lower] - CI_height) > 0  ){CI_index_lower = CI_index_lower - 1   }  
# above loops use likelihood ratio test to find lower confidence interval
for (h in max_log_likelihood:Nb_max)
{       test1 = (log_likelihood_function[CI_index_upper] - CI_height) * (log_likelihood_function[CI_index_upper] - CI_height)
	    test2 = (log_likelihood_function[h] - CI_height) * (log_likelihood_function[h] - CI_height)
        if( test2 < test1  ){CI_index_upper = h   }  
}
if(  (log_likelihood_function[CI_index_upper] - CI_height) > 0  ){CI_index_upper = CI_index_upper + 1   }  
		  	# above loops use likelihood ratio test to find upper confidence interval
		  	##########################
##############################################################################################  ABOVE THIS LINE DETERMINES PEAK LOG LIKELIHOOD AND CONFIDENCE INTERVALS
 # Npw we plot the result
pdf(file="exact_plot.pdf")
plot(log_likelihood_function)
abline(v = max_log_likelihood, col="black" )  # Draws a verticle line at Nb value for which log likelihood is maximized
abline(v = CI_index_lower, col="green" ) # confidence intervals
abline(v = CI_index_upper, col="green" )
print("Bottleneck size")
print(max_log_likelihood)
print("confidence interval left bound")
print(CI_index_lower)
print("confidence interval right bound")
print(CI_index_upper)
dev.off()