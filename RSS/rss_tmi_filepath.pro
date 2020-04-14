FUNCTION RSS_TMI_FILEPATH, year, month, day, $
  VERSION = version, $
  D3D     = d3d, $
  ROOTDIR = rootdir

COMPILE_OPT IDL2

IF N_PARAMS() LT 2 THEN MESSAGE, 'Must input at least year and month'
IF N_ELEMENTS(rootdir) EQ 0 THEN rootdir = !RSS_Data
IF N_ELEMENTS(version) EQ 0 THEN version = '7.1'

versDir  = 'v' + ( STRSPLIT(version, '.', /EXTRACT) )[0]
yearDir  = STRING(year,    FORMAT="('y', I4)")
monthDir = STRING(month,   FORMAT="('m', I02)")
subDirs  = ['TMI', versDir, yearDir, monthDir]

IF N_PARAMS() EQ 3 THEN BEGIN
  IF KEYWORD_SET(d3d) THEN $
    format = "('f12_',I04,I02,I02,'v',F3.1,'_d3d.gz')" $
  ELSE $
    format = "('f12_',I04,I02,I02,'v',F3.1,'.gz')"
  fileName = STRING(year, month, day, version, FORMAT=format)
ENDIF ELSE $
  fileName = STRING(year, month, version, FORMAT="('f12_',I04,I02,'v',F3.1,'.gz')")

file = FILEPATH(fileName, ROOT_DIR = rootdir, SUBDIRECTORY = subDirs )

IF FILE_TEST(file) THEN $
  RETURN, file $
ELSE $
  RETURN, ''
  
END
