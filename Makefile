
all: CxxMerge CxxSortFunctions CxxImplement CxxAutoAuto CxxFormat

CxxMerge: CxxMerge.d Tokenizer.d Statement.d
	dmd CxxMerge.d Tokenizer.d Statement.d

CxxSortFunctions: CxxSortFunctions.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d SortRange.d
	dmd CxxSortFunctions.d TokenRange.d Scanner.d Tokenizer.d TreeRange.d SortRange.d

CxxImplement: CxxImplement.d Tokenizer.d Statement.d
	dmd CxxImplement.d Tokenizer.d Statement.d

CxxAutoAuto: CxxAutoAuto.d Tokenizer.d
	dmd CxxAutoAuto.d Tokenizer.d

CxxFormat: CxxFormat.d Tokenizer.d
	dmd CxxFormat.d Tokenizer.d
