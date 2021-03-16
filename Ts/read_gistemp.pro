FUNCTION READ_GISTEMP, file, FILL = fill, ANNUAL = annual

COMPILE_OPT IDL2

IF N_ELEMENTS(file) EQ 0 THEN $
  file = FILEPATH('GLB.Ts+dSST.csv', ROOT_DIR=!Ts_Data)
IF N_ELEMENTS(fill) EQ 0 THEN fill = '***'

line = ''
OPENR, iid, file, /GET_LUN
READF, iid, line
READF, iid, line

dates = LIST()
vals  = LIST()
WHILE ~EOF(iid) DO BEGIN
  READF, iid, line
  tmp  = STRSPLIT(line, ',', /EXTRACT)
  id   = WHERE(tmp EQ fill, cnt)
  IF cnt GT 0 THEN tmp[id] = 'NaN'
  dates.ADD, GREG2JUL(INDGEN(12)+1, 1, LONG(tmp[0]), 0)
  vals.ADD,  FLOAT(tmp[1:12])
ENDWHILE

FREE_LUN, iid

dates = dates.ToArray(DIMENSION=1, /No_Copy)
vals  = vals.ToArray( DIMENSION=1, /No_Copy)
IF KEYWORD_SET(annual) THEN $
  ANNUALIZE, dates, vals, OUTDATES = dates, /GREGORIAN

RETURN, {TIME   : dates, VALUES : vals}

END
