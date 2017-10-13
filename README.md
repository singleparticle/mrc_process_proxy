MRC PROCESS PROXY
============

Summary
-------
This tcsh script is based on Kai Zhang's original script, you can get more details from readme.txt.<br>
The script process mrc files by programs MotionCor2, Gctf, Gautomatch. With these pre-processing, relion2 program can compute based on the new mrc files.<br>
The script run in head node of cluster, the cluster based on BCM-7.3 with slurm scheduler.<br>

# Background
## MotionCor2
Correction of electron beam-induced sample motion is one of the major factors contributing to the recent resolution breakthroughs in cryo-electron microscopy. Based on observations that the electron beam induces doming of the thin vitreous ice layer, we developed an algorithm to correct anisotropic image motion at the single pixel level across the whole frame, suitable for both single particle and tomographic images. Iterative, patch-based motion detection is combined with spatial and temporal constraints and dose weighting. The multi-GPU accelerated program, MotionCor2, is sufficiently fast to keep up with automated data collection. The result is an exceptionally robust strategy that can work on a wide range of data sets, including those very close to focus or with very short integration times, obviating the need for particle polishing. Application significantly improves Thon ring quality and 3D reconstruction resolution.<br>

[Visit MotionCor2 Website](http://msg.ucsf.edu/em/software/motioncor2.html)

## Gctf
Gctf is real-time CTF determination and correction.
Accurate estimation of the contrast transfer function (CTF) is critical for a near-atomic resolution cryo electron microscopy (cryoEM) reconstruction. Here, I(Kai Zhang) present a GPU-accelerated computer program, Gctf, for accurate and robust, real-time CTF determination. Similar to alternative programs, the main target of Gctf is to maximize the cross-correlation of a simulated CTF with the power spectra of observed micrographs after background reduction. However, novel approaches in Gctf improve both speed and accuracy. In addition to GPU acceleration, a fast ‘1-dimensional search plus 2-dimensional refinement (1S2R)’ procedure significantly speeds up Gctf. Based on the global CTF determination, the local defocus for each particle and for single frames of movies is accurately refined, which improves CTF parameters of all particles for subsequent image processing. Novel diagnosis method using equiphase averaging(EFA) and self-consistency verification procedures have also been implemented in the program for practical use, especially for aims of near-atomic reconstruction. Gctf is an independent program and the outputs can be easily imported into other cryoEM software such as Relion and Frealign. The results from several representative datasets are shown and discussed in this paper.

[Visit Gctf Website](http://www.mrc-lmb.cam.ac.uk/kzhang/Gctf/)

## Gautomatch
Gautomatch is a GPU accelerated program for accurate, fast, flexible and fully automatic particle picking from cryo‐EM micrographs with or without templates.

[Visit Gautomatch Website](http://www.mrc-lmb.cam.ac.uk/kzhang/Gautomatch/)

## About This Package
This git repository update Kai Zhang's motioncorr_Gctf_Gautomatch script tools to make it work on XJTU's GPU cluster.

# Configuration instructions
TBD

# Installation instructions
No need install

# Operating instructions
TBD

# File manifest
To be add

# Copyright and licensing information
Follow Kai Zhang's original licensing information.

# Contact information
xiaodong.han@bluejayimaging.com

# Known bugs
None

# Troubleshooting
TBD

# Credits and acknowledgements
Author: xiaodong han

Company: single particle

# Changelog
10.13.2017  initial commit

