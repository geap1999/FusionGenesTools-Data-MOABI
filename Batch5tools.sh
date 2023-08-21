#!/bin/bash

data_directory=$1
output_directory=$2

mkdir -p $output_directory

# fusionfusion

for fastq1 in $data_directory/R1Fastq/*fastq.gz; do
  path="$fastq1"
  getR2="${path##*/}"
  fastq2="$data_directory/R2Fastq/${getR2/R1/R2}"
  path2="$fastq2"
  Name2="${path2##*/}"
  godjob.py create -n CleanFastqPS -c 3 -r 8 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/bbmap:38.23-1 -v scratch -v annotations -v home --cmd "bbduk.sh -Xmx7g -Xms7g in1=$fastq1 in2=$fastq2 out1=$data_directory/R1Fastq/cleaned_$getR2 out2=$data_directory/R2Fastq/cleaned_$Name2 ref=/data/annotations/Human/hg19/index/bbduk/adapters.fa minlen=50 threads=4 hdist=1 qtrim=rl trimq=20 tpe tbo"
done

sleep 120 &

wait 

for cfastq1 in $data_directory/R1Fastq/cleaned*fastq.gz; do
  path="$cfastq1"
  folderName=${path##*/}
  folderName="${folderName:8:15}_SAM"
  mkdir $data_directory/$folderName
  getR2="${path##*/}"
  cfastq2="$data_directory/R2Fastq/${getR2/R1/R2}"
  godjob.py create -n StarPS -c 13 -r 30 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/star:2.7.5a-1 -v scratch -v annotations --cmd "STAR --runThreadN 8 --genomeDir /data/annotations/Human/hg19/index/star/2.7.5a/readLength149 --readFilesCommand zcat --readFilesIn $cfastq1 $cfastq2 --chimSegmentMin 15 --chimOutType SeparateSAMold --outFileNamePrefix $data_directory/$folderName/"
done

sleep 1200 &

wait 

for sam in $data_directory/*SAM 
do
  path="$sam"
  folderName=${path##*/}
  folderName="${folderName:0:8}_fusionfusion"
  mkdir $output_directory/$folderName
  godjob.py create -n fusionfusionPS -c 5 -r 12 -i gitlab-bioinfo.aphp.fr:5000/moabi-docker-tools-test/fusions_tools:1.0.0-1 -v scratch -v annotations --cmd "fusionfusion --star $sam/Chimeric.out.sam --out $output_directory/$folderName --reference_genome /data/annotations/Human/hg19/hg19.fasta"
done

sleep 180 

wait

#SplitFusion

for fastq1gz in $data_directory/R1Fastq/cleaned*fastq.gz; do
  godjob.py create -n gz2fastq -c 2 -r 2 -i sequoia-docker-infra/debian:stretch -v scratch --cmd "gzip -d -k $fastq1gz"
done
  
for fastq2gz in $data_directory/R2Fastq/cleaned*fastq.gz; do
  godjob.py create -n gz2fastq -c 2 -r 2 -i sequoia-docker-infra/debian:stretch -v scratch --cmd "gzip -d -k $fastq2gz"
done

sleep 180 &

wait
  
for fastq1 in $data_directory/R1Fastq/*fastq; do
  path="$fastq1"
  getR2="${path##*/}"
  fastq2="$data_directory/R2Fastq/${getR2/R1/R2}"
  fileName=${path##*/}
  fileName="${fileName:8:8}_SplitFusion"
  mkdir $output_directory/$fileName
  godjob.py create -n SplitFusionPS -c 10 -r 16 -i gitlab-bioinfo.aphp.fr:5000/moabi-docker-tools-test/fusions_tools:1.0.0-1 -v scratch -v annotations -v home --cmd "python3 /usr/share/SplitFusion/exec/SplitFusion.py --refGenome /data/annotations/Human/hg19/hg19.fasta --annovar /scratch/tmp/Snpeff --output $output_directory/$fileName --sample_id reads --fastq_file1 $fastq1 --fastq_file2 $fastq2 --thread 8"
done

sleep 180 &

wait

#Factera

for bam in $data_directory/facteraBam/*bam 
do
  path="$bam"
  folderName=${path##*/}
  folderName="${folderName:0:8}_Factera_InterExons"
  mkdir $output_directory/$folderName
  godjob.py create -n facteraPSExons -c 3 -r 8 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/factera:1.4.4-1 -v scratch -v annotations -v home --cmd "factera.pl -C -o $output_directory/$folderName -F $bam /usr/share/lib/factera/exons.exonlevel_hg19.bed /data/annotations/Human/hg19/index/factera/hg19.2bit"

done

for bam in $data_directory/facteraBam/*bam 
do
  path="$bam"
  folderName=${path##*/}
  folderName="${folderName:0:8}_Factera_InterGene"
  mkdir $output_directory/$folderName
  godjob.py create -n facteraPSGene -c 3 -r 8 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/factera:1.4.4-1 -v scratch -v annotations -v home --cmd "factera.pl -C -o $output_directory/$folderName -F $bam /usr/share/lib/factera/exons_hg19.bed /data/annotations/Human/hg19/index/factera/hg19.2bit"

done

sleep 180 &

wait

# breakdancer 

mkdir $data_directory/BamByPos

for bam in $data_directory/BAM/*bam
do
  path="$bam"
  fileName=${path##*/}
  fileName="${fileName:0:8}_Pos.bam"
  godjob.py create -n BamPosTest -c 2 -r 4 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/samtools:1.9-1 -v scratch --cmd "samtools sort $bam > $data_directory/BamByPos/$fileName"
done

sleep 360 &

wait

mkdir $data_directory/FileConfBam

for bamPos in $data_directory/BamByPos/*bam 
do
  path="$bamPos"
  fileName=${path##*/}
  fileName="${fileName:0:8}_conf.cfg"
  godjob.py create -n FileConfPS -c 2 -r 4 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/breakdancer:1.4.5-2 -v scratch --cmd "/usr/lib/breakdancer-max1.4.5-unstable-66-4e44b43-dirty/bam2cfg.pl $bamPos > $data_directory/FileConfBam/$fileName"
done 

sleep 120 &

wait  

for cfg in $data_directory/FileConfBam/*cfg; 
do
  path="$cfg"
  fileName=${path##*/}
  fileName="${fileName:0:8}_conf.txt"
  godjob.py create -n FileConfPS -c 2 -r 4 -i sequoia-docker-infra/debian:stretch -v scratch --cmd "mv $cfg $data_directory/FileConfBam/$fileName"
done

sleep 360 &

wait  

for confTxt in $data_directory/FileConfBam/*txt 
do
  path="$confTxt"
  fileName=${path##*/}
  fileName="${fileName:0:8}_breakdancer"
  mkdir $output_directory/$fileName
  godjob.py create -n breakdancerPS -c 4 -r 10 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/breakdancer:1.4.5-2 -v scratch --cmd "breakdancer-max $confTxt > $output_directory/$fileName/results_breakdancer_fusions.txt 2>&1 | tee -a $output_directory/$fileName/test_breakdancer_calling.log_"
done

sleep 360 &

wait

# Lumpy

for bam in $data_directory/BAM/*bam; do
  path="$bam"
  fileName=${path##*/}
  fileName="${fileName:0:8}_SplitReads"
  mkdir $data_directory/$fileName
  godjob.py create -n SplitReadsPS -c 3 -r 6 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/samtools:1.9-1 -v scratch -v annotations -v home --cmd "samtools split $bam -f $data_directory/$fileName/SplitReads.bam"
done

for bamPos in $data_directory/BamByPos/*bam 
do
  path="$bamPos"
  folderName=${path##*/}
  folderName="${folderName:0:8}_DiscordReads"
  mkdir $data_directory/$folderName
  godjob.py create -n DiscordReadsPS -c 3 -r 6 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/samtools:1.9-1 -v scratch -v annotations -v home --cmd "samtools view -b -F 1294 $bamPos > $data_directory/$folderName/sample.discordants.unsorted.bam"
done

sleep 900 &

wait

for bamPos in $data_directory/BamByPos/*bam; 
do
  path="$bamPos"
  NameSample=${path##*/}
  NameSample="${NameSample:0:8}"
  getSplitReads="$data_directory/${NameSample}_SplitReads/SplitReads.bam"
  getDiscordReads="$data_directory/${NameSample}_DiscordReads/sample.discordants.unsorted.bam"
  mkdir $output_directory/${NameSample}_Lumpy
  godjob.py create -n LumpyPS -c 5 -r 12 -i gitlab-bioinfo.aphp.fr:5000/sequoia-docker-tools/lumpy-sv:0.2.13-2 -v scratch -v home --cmd "lumpyexpress -B $bamPos -S $getSplitReads -D $getDiscordReads -o $output_directory/${NameSample}_Lumpy/ResultatLumpy.bam.vcf"
done
  









