#!/bin/tcsh -f
#####************************************************************************************#####
#Description: This program is used to do real-time auto processing during data collection
#Copyright: MRC Laboratory of Molecular Biology
#Author: Kai Zhang
#####************************************************************************************#####

#Requirement: EMAN2, e2proc3d.py; Motioncorr; Gctf; Gautomatch; Cuda libriary; High-end GPUs;  MRC file format;

set all_mrcfiles = "Micrographs/*frames.mrc"           #####: 
set convert_mrcs = "YES"                     #####: Yes or NO         

##### ----- Motioncorr Parameters -----#####
##### ----- Change motioncorr program to MotionCor2 -----#####
set Motioncorr            = /data/share/apps/MotionCor2
set bin                   = 1                #####: 
set ali_first             = 0                #####: 
set ali_last              = 0                #####: 
set sum_first             = 0                #####: 
set sum_last              = 0                #####: 
set write_ali_stack       = "YES"            #####: Yes or NO
set Motioncorr_gid        = 1                #####: GPU id for Motioncorr, normally 0, and {0,1,2,3} for four GPUs


##### -----  Gautomatch Parameters   -----#####
set GAUTOMATCH            = /data/share/apps/Gautomatch
set apixM                 = 1.04             #####: Micrograph pixel size in Angstrom (after Motioncorr)
set Templates             = dynactin_templates_all.mrcs            #####: MRC stack; NULL or NONE to automatically generate templates
set apixT                 = 1.34             #####: Templates pixel size in Angstrom;
set Diameter              = 400              #####: Diameter for estimation of local sigma, in Angstrom;
set min_dist              = 300              #####: Minimum distance between particles in angstrom; 0.9~1.1X diameter; can be 0.3~0.5 for filament-like particle;
set cc_cutoff             = 0.2              #####: Cross-correlation cutoff, 0.2~0.4 normally; Try to select several typical micrographs to optimize this value.
                                             #:     Alternatively, it will be even faster if you use a small value, e.g. 0.1, first and then use 'box_filter.com' or 'box_filter2rl.com' to filter the box files afterwards.
set lsigma_cutoff         = 1.3             #####:  Local sigma cutoff (relative value), 1.2~1.5 should be a good range; normally a value >1.2 will be ice, protein aggregation or contamination
set lsigma_Diamter        = 300             #####:  Diameter for estimation of local sigma, in angstrom

set lave_min              = -0.8            #####:  Local average cutoff (relative value), any pixel value below that will be considered as ice/aggregation/carbon etc.
set lave_max              = 1.2             #####:  Local average cutoff (relative value), any pixel value above that will be considered as ice/aggregation/carbon etc.
set lave_Diamter          = 480             #####:  Diameter for estimation of local average, in angstrom, 0.5~2.0X particle diameter suggested;
                                            #:      However, if you have 'sharp'/'small' ice or any 'dark'/'bright' dots, use a smaller value will be much better to get rid of these areas.

set lp                    = 30              #####:  Low-pass filter to increase the contrast of raw micrographs, suggested range 20~50Å. This low-pass is after ice/aggregation detection.
set hp                    = 1000            #####:  High-pass filter to get rid of the global background of raw micrographs, suggested range 200~2000Å. This high-pass is after ice/aggregation detection.
set GAUTOMATCH_gid        = 1               #####:  GPU id for Gautomatch, normally 0, and {0,1,2,3} for four GPUs 
set GAUTOMATCH_FOW        = "No"            #####:  Yes or NO, whether to force to overwrite the Gautomatch results?
                                            #####:  Normally, it will skip the files which have already been processed. If this is set Yes, it will overwrite the previous results(Not suggested)
set GAUTOMATCH_ExtraPar   = " --do_unfinished  --do_pre_filter --pre_hp 1000"    #####: the rest parameters if not set 
#set GAUTOMATCH_ExtraPar        = " --do_unfinished --exclusive_picking --excluded_suffix _rubbish.star"    #####: the rest parameters if not set 



##### -----      GCTF Parameters     -----#####
set GCTF                  = /data/share/apps//Gctf
set kV                    = 300              #####: High tension in Kilovolt, typically 300, 200 or 120
set Cs                    = 2.7              #####: Spherical aberration, in millimeter
set ac                    = 0.1              #####: Amplitude contrast
set GCTF_gid              = 1                #####: GPU id, normally 0, and {0,1,2,3} for four GPUs, can be different from Gautomatch
set GCTF_FOW              = "No"            #####:  Yes or NO, whether to force to overwrite the GCTF results? 
                                            #####:  Normally, it will skip the files which have already been processed. If this is set Yes, it will overwrite the previous results(Not suggested)
set GCTF_ExtraPar         = " --do_local_refine   --boxsuffix  _automatch.star"    #####: the rest parameters if not set 

#Tips: 
#To stop it use this command  'touch ALL_STOP' to stop automatic batch processing;
#it will still finish the current micrograph and then stop before the next micrograph


##################################################################################################################
##############################   End of user input   #############################################################
##################################################################################################################
#global setup for output format
set KBold="\x1b\x5b1m"
set KDefault="\x1b\x5b0m"
set KUnderline="\x1b\x5b4m"
set KFlash="\x1b\x5b5m"



#checking the settings:

if ( ! -f $Motioncorr ) then

echo "The program  $Motioncor2 does NOT exisit! Exit now! "
exit 

else if ( ! -f $GAUTOMATCH ) then
echo "The program  $GAUTOMATCH does NOT exisit! Exit now! "
exit 

else if ( ! -f $Templates ) then
echo "The template $Templates does NOT exisit! Check your input! Exit now! "
exit 

else if ( ! -f $GCTF ) then
echo "The program  $GCTF does NOT exisit! Exit now! "
exit 

endif


#end of global setup and chekcing ..................


while ( 1 )

set allmrcf=`ls $all_mrcfiles`

rm -f *_processing.log   */*_processing.log 

foreach mrcfus ($allmrcf)
#  foreach 999

#checking if movie exists
if ( ! -f $mrcfus ) then
echo "Warning: movie file $mrcfus does NOT exisit! skipped"
exit
endif

#whether to convert file format
set mrcf=`echo $mrcfus | sed  's/frames.mrc/framesf.mrc/g'`

if ( $convert_mrcs ~ "Y*" ) then
e2proc3d.py $mrcfus $mrcf 
else
set mrcf=${mrcfus}
endif


### ===>>> get the root name of the micrograph(movies)
printf "${KBold} processing $mrcf .... $KDefault \n"

set root=`echo $mrcf | sed  's/.mrcs//g'`
set root=`echo $root | sed  's/.mrc//g'`
### ===>>> output controlling log, very useful to avoid the conflict of multiple jobs
if ( -f ${root}_processing.log ) then
continue
else
echo "" > ${root}_processing.log
endif

echo 
#######################################################################
############################ MOTIONCORR ###############################
#######################################################################
set ssc=0
if ( $write_ali_stack == 1 || $write_ali_stack =~ 'Y*' ) then
set ssc=1
endif

echo ${root}_SumCorr.mrc ${root}_movie.mrc 
echo

if (  -f ${root}_SumCorr.mrc && -Z ${root}_SumCorr.mrc && $ssc == 1  &&  -f ${root}_movie.mrc  &&  -Z ${root}_movie.mrc ) then
echo "MOTIONCORR on $mrcf already processed, automatically skipped. "
else if ( -f ${root}_SumCorr.mrc && -Z ${root}_SumCorr.mrc && $ssc == 0 ) then
echo "MOTIONCORR on $mrcf already processed, automatically skipped. "
else

echo "$Motioncorr $mrcf -ssc $ssc -bin $bin -nst $ali_first -ned $ali_last -nss $sum_first -nes $sum_last -gpu $Motioncorr_gid -fcs ${root}_SumCorr.mrc -fct ${root}_movie.mrc -flg ${root}_Log.txt"

$Motioncorr $mrcf -ssc $ssc -bin $bin -nst $ali_first -ned $ali_last -nss $sum_first -nes $sum_last -gpu $Motioncorr_gid -fcs ${root}_SumCorr.mrc -fct ${root}_movie.mrc -flg ${root}_Log.txt | tee -a MOTIONCORR_auto_full.log

endif
#endif Motioncorr

#######################################################################
########################### GAUTOMATCH ################################
#######################################################################

echo "running GAUTOMATCH on ${root}_SumCorr.mrc .... " 
echo

if (  -f  ${root}_SumCorr_automatch.star && $GAUTOMATCH_FOW =~ 'N*' && -Z ${root}_SumCorr_automatch.star) then
#if the log file already exists and non-empty, it will not do anything
echo "GAUTOMATCH on ${root}_SumCorr.mrc already processed, automatically skipped."

else

echo "$GAUTOMATCH  ${root}_SumCorr.mrc --apixM $apixM     $GAUTOMATCH_ExtraPar  --T $Templates --apixT $apixT  --diameter $Diameter  --cc_cutoff  $cc_cutoff --min_dist $min_dist --lsigma_D $lsigma_Diamter --lsigma_cutoff $lsigma_cutoff   --lave_D $lave_Diamter   --lave_max  $lave_max  --lave_min $lave_min --lp $lp  --hp $hp --gid $GAUTOMATCH_gid $GAUTOMATCH_ExtraPar"
$GAUTOMATCH  ${root}_SumCorr.mrc --apixM $apixM   $GAUTOMATCH_ExtraPar  --T $Templates --apixT $apixT  --diameter $Diameter  --cc_cutoff  $cc_cutoff --min_dist $min_dist --lsigma_D $lsigma_Diamter --lsigma_cutoff $lsigma_cutoff   --lave_D $lave_Diamter   --lave_max  $lave_max  --lave_min $lave_min --lp $lp  --hp $hp --gid $GAUTOMATCH_gid  $GAUTOMATCH_ExtraPar |tee -a GAUTOMATCH_auto_full.log

endif
#endif Gautomatch


#######################################################################
############################## GCTF ###################################
#######################################################################


echo "running GCTF on ${root}_SumCorr.mrc  .... " 
echo "${root}_SumCorr.ctf "
echo
if (  -f  ${root}_SumCorr.ctf &&  -Z ${root}_SumCorr.ctf  && $GCTF_FOW =~ 'N*' ) then
#if the log file already exists and non-empty, it will not do anything
echo "GCTF on ${root}_SumCorr.mrc already processed, automatically skipped."

else
##### Gctf ###
echo "$GCTF ${root}_SumCorr.mrc  --apix $apixM  --cs $Cs --kV $kV --ac $ac --gid $GCTF_gid   $GCTF_ExtraPar"
$GCTF  ${root}_SumCorr.mrc  --apix $apixM  --cs $Cs --kV $kV --ac $ac --gid $GCTF_gid   $GCTF_ExtraPar  |tee -a Gctf_auto_full.log 
endif

#endif GCTF


#######################################################################

rm -f ${root}_processing.log

if ( -f ALL_STOP ) then
exit
endif



echo "......................................................................\n"


#######################################################################
end 
# end foreach 999

printf "$KBold $KFlash ${KUnderline}======>>> ONE BIG CYCLE FINISHED, ANOTHER CYCLE ALL OVER AGAIN <<<====== ${KDefault}\n"
echo
echo   "#############################################################################################################"
printf "$KBold  REAL-TIME PROCESSING OF MOTION CORRECTION, PARTICLE PICKING, CTF DETERMINATION(CORRECTION) ${KDefault}\n"
echo   "#############################################################################################################"
echo 

sleep 3s

end
#end while



