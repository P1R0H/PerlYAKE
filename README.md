# PerlYAKE

YAKE - Yet Another Keyword Extractor in Perl

Language agnostic keyword extractor written as a little fun project
to learn basics of Perl language.

Basic stopword files for English, Slovak and Czech languages are included.

*NO RIGHTS RESERVED*

Original **official** implementation can be found [here](https://github.com/LIAAD/yake).
## Usage 

```
PerlYAKE - Yet Another Keyword Extractor, now in Perl
usage: perlyake [-h|--help] [-w|--window WIN_SIZE] [-n|--number NUM]
                [-p|--phrase P_LEN] [-s|--stopwords FILE] DOCUMENT
args:
    -h, --help         print this help
    -w, --window       set window size to 2 * WIN_SIZE + 1
    -n, --number       number of results to return
    -p, --phrase       maximum keyphrase length
    -s, --stopwords    stopwords in the desired language, one per line
    -t, --threshold    similarity threshold for duplicate phrases (0.0 - 1.0)
    DOCUMENT           input document path

```

## Credits

```
Campos, R., Mangaravite, V., Pasquali, A., Jatowt, A., Jorge, A., Nunes, C. and Jatowt, A. (2020). 
YAKE! Keyword Extraction from Single Documents using Multiple Local Features. 
In Information Sciences Journal. Elsevier, Vol 509, pp 257-289

Campos, R., & Mangaravite, V., & Pasquali, A., & Jorge, A., & Nunes, C., & Jatowt, A. (2018).
A Text Feature Based Automatic Keyword Extraction Method for Single Documents.
In Gabriella Pasi et al. (Eds.), Lecture Notes in Computer Science - Advances in Information Retrieval - 40th European Conference on Information Retrieval (ECIR'18).
Grenoble, France. March 26 – 29. (Vol. 10772(2018), pp. 684 - 691). *

Campos, R., & Mangaravite, V., & Pasquali, A., & Jorge, A., & Nunes, C., & Jatowt, A. (2018).
YAKE! Collection-independent Automatic Keyword Extractor.
In Gabriella Pasi et al. (Eds.), Lecture Notes in Computer Science - Advances in Information Retrieval - 40th European Conference on Information Retrieval (ECIR'18).
Grenoble, France. March 26 – 29. (Vol. 10772(2018), pp. 806 - 810).
```

### DISCLAIMER 
I am not affiliated with this awesome team in any way. Full credit for research and developement of this method goes to them.
