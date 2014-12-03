
all: CxxMerge CxxSortFunctions CxxImplement

CxxMerge: CxxMerge.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d MergedRange.d
	dmd CxxMerge.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d MergedRange.d

CxxSortFunctions: CxxSortFunctions.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d SortRange.d
	dmd CxxSortFunctions.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d SortRange.d

CxxImplement: CxxImplement.d Scanner.d TreeRange.d Tokenizer.d TokenRange.d MergedRange.d UnifyRange.d
	dmd CxxImplement.d Scanner.d TreeRange.d Tokenizer.d TokenRange.d MergedRange.d UnifyRange.d
