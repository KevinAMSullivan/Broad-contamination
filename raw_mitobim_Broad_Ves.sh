#!/bin/bash
#$ -V
#$ -cwd
#$ -S /bin/bash
#$ -N Ves_Broad_mitobim
#$ -o $JOB_NAME.o$JOB_ID
#$ -e $JOB_NAME.e$JOB_ID
#$ -q omni
#$ -pe sm 1
#$ -P quanah

#This file will process raw Illumina data using Trimmomatic.  This will be followed by mapping to a reference mitochondrial genome using MIRA4 to create a new mitochondrial genome assembly.

BASEDIR=/lustre/scratch/kevsulli/Mitobim/Broad_troubleshooting
WORKDIR=$BASEDIR/output

mkdir $WORKDIR
cd $WORKDIR

REFGENOME=Pipistrellus_kuhlii.fas  	# your reference genome for the assembly
REF_HOME=/lustre/scratch/kevsulli/Mitobim/Broad_troubleshooting/reference_genomes	#the location of your reference genome


RAW_READS_HOME=/lustre/scratch/kevsulli/Mitobim/Broad_troubleshooting/data   #the location of your raw data
#mkdir $BASEDIR/data_raw
#UNZIPPED_RAW_HOME=$BASEDIR/data_raw
mkdir $BASEDIR/support_files
SUPPORT_FILES=$BASEDIR/support_files	#where the support files like the adapter sequences will be located.

######
#set up alias' for major programs
######

RAY_SOFTWARE=/lustre/work/daray/software
VCFTOOLS_HOME=/lustre/work/daray/software/vcftools_0.1.12b/bin
MIRA_HOME=/lustre/scratch/kevsulli/Apps/Mitobim/mira-4.0.2
MITOBIM=/lustre/work/daray/software
MIRA=/opt/apps/nfs/intel/impi/mira/4.0.2/bin


for RAW_READ_FILE in $RAW_READS_HOME/*_U0023_10pct.fastq
do
	SAMPLE_ID=$(basename $RAW_READ_FILE _U0023_10pct.fastq)
#Unzip the raw reads into the processed_reads directory
#	gunzip -c $RAW_READS_HOME/$SAMPLE_ID"_L001_R1_001.fastq.gz" >$UNZIPPED_RAW_HOME/$SAMPLE_ID"_R1.fastq"
#	gunzip -c $RAW_READS_HOME/$SAMPLE_ID"_L001_R2_001.fastq.gz" >$UNZIPPED_RAW_HOME/$SAMPLE_ID"_R2.fastq"

mkdir $WORKDIR/$SAMPLE_ID
cd $WORKDIR/$SAMPLE_ID


#======================
#MIRA4 assembly 
#Create manifest.config for MIRA
echo -e "\n#manifest file for basic mapping assembly with illumina data using MIRA 4\n\nproject = initial-mapping-of-"$SAMPLE_ID"-to-Ves-mt\njob=genome,mapping,accurate\nparameters = -NW:mrnl=0 -AS:nop=1 SOLEXA_SETTINGS -CO:msr=no -CL:pec=yes\nreadgroup\nis_reference\ndata = $REF_HOME/$REFGENOME\nstrain = Ves-mt-genome\n\nreadgroup = reads\n-CL:pec=yes\ndata = "$RAW_READS_HOME/$SAMPLE_ID"_U0023_10pct.fastq" $RAW_READS_HOME/$SAMPLE_ID"_U0023_10pct.fastq\ntechnology = solexa\nstrain = "$SAMPLE_ID"\n" > $SUPPORT_FILES/$SAMPLE_ID"_manifest.conf"

#Run MIRA  
module load intel/17.3.191
module load impi/2017.20160721
module load intel impi boost/1.61.0-intel mira
module load mira
mira $SUPPORT_FILES/$SAMPLE_ID"_manifest.conf"

#======================
#MITObim assembly
#Bait and iteratively map to the reference genome using MITObim
perl $MITOBIM/MITObim_1.8.pl \
	-start 1 \
	-end 10 \
	-sample $SAMPLE_ID \
	-ref Ves-mt-genome \
	-readpool $RAW_READS_HOME/$SAMPLE_ID"_U0023_10pct.fastq" $RAW_READS_HOME/$SAMPLE_ID"_U0023_10pct.fastq" \
	-maf $WORKDIR/$SAMPLE_ID/"initial-mapping-of-"$SAMPLE_ID"-to-Ves-mt_assembly"/"initial-mapping-of-"$SAMPLE_ID"-to-Ves-mt_d_results"/"initial-mapping-of-"$SAMPLE_ID"-to-Ves-mt_out.maf" \
	&> $SAMPLE_ID".log"

cd ..
done









