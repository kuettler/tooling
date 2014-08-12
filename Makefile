
all: CxxMerge CxxSortFunctions SortFunctions

CxxMerge: CxxMerge.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d
	dmd CxxMerge.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d

CxxSortFunctions: CxxSortFunctions.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d
	dmd CxxSortFunctions.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d

SortFunctions: SortFunctions.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d
	dmd SortFunctions.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d
