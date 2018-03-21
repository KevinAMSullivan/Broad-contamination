#!/bin/bash
#$ -V
#$ -cwd
#$ -S /bin/bash
#$ -N Broad_mitobim
#$ -o $JOB_NAME.o$JOB_ID
#$ -e $JOB_NAME.e$JOB_ID
#$ -q omni
#$ -pe sm 1
#$ -P quanah

#This file will process raw Illumina data using Trimmomatic.  This will be followed by mapping to a reference mitochondrial genome using MIRA4 to create a new mitochondrial genome assembly.
module purge #previously got errors concerning incompatible module loads so this is to get a fresh restart 

BASEDIR=/lustre/scratch/kevsulli/Mitobim/Broad_troubleshooting
WORKDIR=$BASEDIR/output

mkdir $WORKDIR
cd $WORKDIR

REFGENOME=Pipistrellus_kuhlii.fasta  	# your reference genome for the assembly
REF_HOME=/lustre/scratch/kevsulli/Mitobim/Broad_troubleshooting/reference_genomes	#the location of your reference genome


RAW_READS_HOME=/lustre/scratch/kevsulli/Mitobim/Broad_troubleshooting/data   #the location of your raw data
#mkdir $BASEDIR/data_raw
#UNZIPPED_RAW_HOME=$BASEDIR/data_raw
mkdir $BASEDIR/support_files
SUPPORT_FILES=$BASEDIR/support_files	#where the .conf files will be located.

######
#set up alias' for major programs
######

RAY_SOFTWARE=/lustre/work/daray/software
VCFTOOLS_HOME=/lustre/work/daray/software/vcftools_0.1.12b/bin
MIRA_HOME=/lustre/scratch/kevsulli/Apps/Mitobim/mira-4.0.2
MITOBIM=/lustre/scratch/kevsulli/Apps/Mitobim/MITObim-master



for RAW_READ_FILE in $RAW_READS_HOME/*_10pct.bam
do
	SAMPLE_ID=$(basename $RAW_READ_FILE _10pct.bam)
#Unzip the raw reads into the processed_reads directory
#	gunzip -c $RAW_READS_HOME/$SAMPLE_ID"_L001_R1_001.fastq.gz" >$UNZIPPED_RAW_HOME/$SAMPLE_ID"_R1.fastq"
#	gunzip -c $RAW_READS_HOME/$SAMPLE_ID"_L001_R2_001.fastq.gz" >$UNZIPPED_RAW_HOME/$SAMPLE_ID"_R2.fastq"

mkdir $WORKDIR/$SAMPLE_ID
cd $WORKDIR/$SAMPLE_ID

load intel/17.3.191
load htslib/1.3.2-intel
module load samtools/1.3.1-intel
samtools sort -n $SAMPLE_ID"_10pct.bam >"$SAMPLE_ID"_10pct.bam.qsort"

module load bedtools
bedtools bamtofastq -i $SAMPLE_ID"_10pct.bam.qsort -fq "$SAMPLE_ID"_10pct_R1.fastq -fq2 "$SAMPLE_ID"_10pct_R2.fastq"

module load gnu/5.4.0  openmpi/1.10.6  singularity/2.4.0-gnu
module load pear
pear -f $SAMPLE_ID"_10pct_R1.fastq -r "$SAMPLE_ID"_10pct_R2.fastq -o "$SAMPLE_ID"_10pct_Peared.fastq"

module load intel impi boost/1.61.0-intel mira
module load mira

#======================
#MIRA4 assembly 
#Create manifest.config for MIRA
echo -e "\n#manifest file for basic mapping assembly with illumina data using MIRA 4\n\nproject = initial-mapping-of-"$SAMPLE_ID"-to-Ves-mt\n\njob=genome,mapping,accurate\n\nparameters = -NW:mrnl=0 -AS:nop=1 SOLEXA_SETTINGS -CO:msr=no -CL:pec=yes\n\nreadgroup\nis_reference\ndata = $REF_HOME/$REFGENOME\nstrain = Ves-mt-genome\n\nreadgroup = reads\ndata = "$RAW_READS_HOME/$SAMPLE_ID"_10pct_Peared.assembled.fastq" $RAW_READS_HOME/$SAMPLE_ID"_10pct_Peared.unassembled.forward.fastq "$SAMPLE_ID"_10pct_Peared.unassembled.reverse.fastq\ntechnology = solexa\nstrain = "$SAMPLE_ID"\n" > $SUPPORT_FILES/$SAMPLE_ID"_manifest.conf"

#Run MIRA
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
	-readpool $RAW_READS_HOME/$SAMPLE_ID"_10pct_Peared.assembled.fastq" $RAW_READS_HOME/$SAMPLE_ID"_10pct_Peared.unassembled.forward.fastq "$SAMPLE_ID"_10pct_Peared.unassembled.reverse.fastq" \
	-maf $WORKDIR/$SAMPLE_ID/"initial-mapping-of-"$SAMPLE_ID"-to-Ves-mt_assembly"/"initial-mapping-of-"$SAMPLE_ID"-to-Ves-mt_d_results"/"initial-mapping-of-"$SAMPLE_ID"-to-Ves-mt_out.maf" \
	&> $SAMPLE_ID".log"

cd ..
done









