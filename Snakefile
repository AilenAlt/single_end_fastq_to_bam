configfile: 'config.yaml'

SRRs = [
    "SRR5319080",
    "SRR869741",
    "SRR869742",
    "SRR22424062",
    "SRR1505738",
    "SRR1505739",
    "SRR1505740",
    "SRR5259259",
    "SRR5259258",
    "SRR6967848",
    "SRR6278167",
    "SRR6278173"
]

rule all:
    input:
        expand('align/{srr}_filtered.bam', srr=SRRs)

rule trim:
    input: 
        '{srr}.fastq.gz'
    output: 
        '{srr}_trimm.fastq.gz'
    params:
        adapters = config['Adapters'],
    log:
        '{srr}_trimm.log'
    shell:
        """
        bbduk.sh in={input} ref={params.adapters} ktrim=r k=23 hdist=1 mink=11 mlf=.5 rcomp=t out={output} 2> {log}
        """

rule qc:
    input:
        '{srr}_trimm.fastq.gz'
    output:
        'qc/{srr}_trimm_fastqc.html' 
    threads:
        8
    shell:
        """
        fastqc -o ./qc --threads {threads} {input}
        """

rule align:
    input:
        fastq = '{srr}_trimm.fastq.gz',
        qc = 'qc/{srr}_trimm_fastqc.html'
    output:
        'align/{srr}.sam'
    threads:
        8
    conda:
        'bowtie'
    log:
        '{srr}_bowtie.log'
    shell:
        """
        bowtie2 -x dm6_index -U {input.fastq} --threads {threads} -S {output} 2> {log} && rm {input}
        """

rule sam_to_bam:
    input:
        'align/{srr}.sam'
    output:
        'align/{srr}_sorted.bam'
    threads:
        8
    conda:
        'samtools'
    shell:
        """
        samtools view -b --threads {threads} {input} | samtools sort --threads {threads} -o {output} - && rm {input}
        """

rule mark_duplicates:
    input:
        'align/{srr}_sorted.bam'
    output:
        'align/{srr}_flagged.bam'
    conda:
        'picard'
    log:
        '{srr}_duplicates.log'
    shell:
        """
        picard MarkDuplicates -I {input} -M {log} -O {output} && rm {input}
        """

rule filter_alignment:
    input:
        'align/{srr}_flagged.bam'
    output:
        'align/{srr}_filtered.bam'
    conda:
        'samtools'
    threads:
        8
    shell:
        """
        samtools view -hb {input} --threads {threads} -q 30 -F 3332 -o {output}
        """
