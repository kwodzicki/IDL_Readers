FUNCTION GPCP_1DD_FILEPATH, timePeriod, $
  COUNT    = count,   $
  VERSION  = version, $
  DATES    = dates,   $
  ROOT_DIR = root_dir
COMPILE_OPT IDL2

IF N_ELEMENTS(root_dir) EQ 0 THEN ROOT_DIR = !GPCP_Data
IF N_ELEMENTS(version)  EQ 0 THEN version  = 1.2

dir = FILEPATH('Monthly', ROOT_DIR=root_dir, $
        SUBDIRECTORY=STRING(version, FORMAT="('1dd_v',F3.1)"))

files = FILE_SEARCH(dir, '*' + ext, COUNT = count)
;
;times = GPCP_FILETIME( files )
;good  = MATCHINGTIMES(times, dates, COUNT=count)
;files = files[good]

RETURN, files

END
