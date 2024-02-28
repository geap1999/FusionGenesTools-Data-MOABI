# FusionGenesTools-Data-MOABI
Project that consists in studying various tools for gene fusion analysis : fusionfusion, SplitFusion, Factera (Intergene and Interexon), Breakdancer and Lumpy-sv.
First, a script that executes the tools consecutively was made (Batch5tools.sh).
Then, a script that parses data coming from the output files of each tool was developed (ParsingScript.py). 
An output example of the parsing script is also availabe. 

The parsing script command line :
ParsingScript.py     -n sample_name     -f fusionfusion_output_file     -s splitfusion_output_file     -g facteraIntergene_output_file     -e facteraInterExon_output_file     -b breakdancer_output_file
-l lumpy_output_file     -d max_acceptable_diff     -o output_directory

See report for more information.


