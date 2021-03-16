FUNCTION GPCP_FILETIME, files
; Compatible with GPCP v2.3 files
COMPILE_OPT IDL2

tmp = STRSPLIT( FILE_BASENAME(files), '_', /EXTRACT )
IF N_ELEMENTS(files) GT 1 THEN BEGIN
  tmp   = tmp.ToArray(/No_Copy)
  year  = tmp[*, -2]
  month = tmp[*, -1]
ENDIF ELSE BEGIN
  year  = tmp[-2]
  month = tmp[-1]
ENDELSE

year  = LONG(STRMID(year,  1, 4))
month = LONG(STRMID(month, 1, 2))
bad   = WHERE(year EQ 0, nBad, COMPLEMENT=good, NCOMPLEMENT=ngood)

dates = DBLARR( N_ELEMENTS(files) )
IF nBad  GT 0 THEN dates[bad ] = !VALUES.D_NaN
IF nGood GT 0 THEN dates[good] = GREG2JUL(month[good], 1, year[good], 0)

RETURN, dates

END
