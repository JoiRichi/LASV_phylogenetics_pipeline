configfile: "config/config.yaml"

align_file = config["files"]["alignment"]
metadata_file = config["files"]["metadata"]
reference_file = config["files"]["reference"]

rule all:
    input:
        auspice_json = "auspice/lasv.json",

rule tree:
    """Building tree"""
    input:
        alignment = align_file
    output:
        tree = "results/lasv_tree_raw.nwk"
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --output {output.tree}
        """

rule refine:
    """
    Refining tree
      - estimate timetree
      - use {params.coalescent} coalescent timescale
      - estimate {params.date_inference} node dates
      - filter tips more than {params.clock_filter_iqd} IQDs from clock expectation
    """
    input:
        tree = "results/lasv_tree_raw.nwk",
        alignment = align_file,
        metadata = metadata_file
    output:
        tree = "results/lasv_tree.nwk",
        node_data = "results/lasv_branch_lengths.json"
    params:
        coalescent = config["refine"]["coalescent"],
        date_inference = config["refine"]["date_inference"],
        clock_filter_iqd = config["refine"]["clock_filter_iqd"]
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data} \
            --timetree \
            --coalescent {params.coalescent} \
            --date-confidence \
            --date-inference {params.date_inference} \
            --stochastic-resolve
            
            
        """
#--keep-root\ --stochastic-resolve  --clock-filter-iqd {params.clock_filter_iqd} \

rule ancestral:
    """Reconstructing ancestral sequences and mutations"""
    input:
        tree = "results/lasv_tree.nwk",
        alignment = align_file
    output:
        node_data = "results/lasv_nt_muts.json"
    params:
        inference = config["ancestral"]["inference"]
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output-node-data {output.node_data} \
            --inference {params.inference}
        """

rule translate:
    """Translating amino acid sequences"""
    input:
        tree = "results/lasv_tree.nwk",
        node_data = "results/lasv_nt_muts.json",
        reference = reference_file
    output:
        node_data = "results/lasv_aa_muts.json"
    shell:
        """
        augur translate \
            --tree {input.tree} \
            --ancestral-sequences {input.node_data} \
            --reference-sequence {input.reference} \
            --output {output.node_data} \
        """

rule export:
    """Exporting data files for for auspice"""
    input:
        tree = "results/lasv_tree.nwk",
        metadata = metadata_file,
        branch_lengths = "results/lasv_branch_lengths.json",
        nt_muts = "results/lasv_nt_muts.json",
        aa_muts = "results/lasv_aa_muts.json",
        auspice_config = config["files"]["auspice_config"]
    output:
        auspice_json = rules.all.input.auspice_json
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.nt_muts} {input.aa_muts} \
            --auspice-config {input.auspice_config} \
            --include-root-sequence \
            --output {output.auspice_json}
        """

rule clean:
    """Removing directories: {params}"""
    params:
        "results ",
        "auspice"
    shell:
        "rm -rfv {params}"
