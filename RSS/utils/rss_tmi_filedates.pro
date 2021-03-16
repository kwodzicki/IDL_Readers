FUNCTION RSS_TMI_FILEDATES, files, WEEKLY = weekly

COMPILE_OPT IDL2
  
base = FILE_BASENAME(files)

year  = LONG(STRMID(base, 4, 4))
month = LONG(STRMID(base, 8, 2))
IF STREGEX(base[0], 'f12_[0-9]{8}', /BOOLEAN) THEN $
  day = LONG(STRMID(base, 10, 2)) $
ELSE $
  day = 1


RETURN, GREG2JUL(month, day, year, 0)

END
