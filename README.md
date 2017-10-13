MRC PROCESS PROXY
============

Summary
-------
This tcsh script is based on Kai Zhang's original script, you can get more details from readme.txt.<br>
The script process mrc files by programs MotionCor2, Gctf, Gautomatch. With these pre-processing, relion2 program can compute based on the new mrc files.<br>
The script run in head node of cluster, the cluster based on BCM-7.3 with slurm scheduler.<br>
