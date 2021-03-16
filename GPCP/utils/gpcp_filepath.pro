FUNCTION GPCP_FILEPATH, timePeriod, $
  COUNT    = count,   $
  VERSION  = version, $
  DATES    = dates,   $
  ROOT_DIR = root_dir
COMPILE_OPT IDL2

IF N_ELEMENTS(root_dir) EQ 0 THEN ROOT_DIR = !GPCP_Data
IF N_ELEMENTS(version)  EQ 0 THEN version  = 2.3

IF version EQ 2.2 THEN BEGIN
  dir = 'Yearly'
  ext = '.gz'
ENDIF ELSE IF version EQ 2.3 THEN BEGIN
  dir = 'Monthly'
  ext = '.nc'
ENDIF ELSE MESSAGE, 'Unsupported data version!'
dir = FILEPATH(dir, ROOT_DIR=root_dir, $
        SUBDIRECTORY=STRING(version, FORMAT="('V',F3.1)"))

files = FILE_SEARCH(dir, '*' + ext, COUNT = count)

IF N_ELEMENTS(timePeriod) EQ 2 AND version EQ 2.3 THEN BEGIN
  times = GPCP_FILETIME( files )
  t0    = WHERE( SAMETIME( timePeriod[0], times ), nt0)
  t1    = WHERE( SAMETIME( timePeriod[1], times ), nt1)
  IF nt0 NE 1 OR nt1 NE 1 THEN MESSAGE, 'Time matching issue'
  good  = WHERE(times GE times[t0[0]] AND times LE times[t1[0]], nGood)
  IF nGood GT 0 THEN BEGIN
    files = files[good]
    count = nGood
  ENDIF ELSE MESSAGE, 'No files in requested time span'
ENDIF ELSE IF N_ELEMENTS(dates) GT 0 THEN BEGIN
  times = GPCP_FILETIME( files )
  good  = MATCHINGTIMES(times, dates, COUNT=count)
  files = files[good]
ENDIF

RETURN, files

END
