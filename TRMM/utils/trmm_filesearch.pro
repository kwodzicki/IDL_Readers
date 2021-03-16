FUNCTION TRMM_FILESEARCH, product, date, swath, $
  FILE_DATES = file_dates, $
	COUNT      = count, $
	VERSION    = version, $
  ROOT_DIR   = root_dir, $
  EXT        = extIn, $
  _EXTRA     = _extra
;+
; Name:
;   TRMM_FILESEARCH
; Purpose:
;   An IDL function to generate file path to TRMM data.
; Inputs:
;   product (string) : String specifying the product; e.g., 2A25
;   date (JULDAY) : Date to search within (optional)
;   swath (int) : Swath to read (optional)
; Keywords:
;   VERSION  : Sets TRMM data version; Default is 7
;   DATES    : Set to named variable to return array of JULDAY values for
;     the date of each file. As swath numbers are used in the file names and
;     NOT times, the hour of each file is fugded so that they are equaly spaced
;     throughout the day, with the first swath of the day at 00, and so on.
;     The spacing of times depends on the number of swaths in the day.
;     This variability in time spacing is NOT an issue because all files will
;     products will have same spacing as swath numbers will be consistent
;     across data products.
;
;     Example:
;       Say there are 16 files (nSwath = 16, typical) in a day, starting on swath 01000
;       Hours are constructed as (INDGEN(nSwath) * 24 / FLOAT(nSwath)
;       So, swath 01000 is 00:00Z, 01001 is 01:30Z, 01002 is 03:00Z, etc.
;   _EXTRA : Catch-all for extra, unused keywords
; Outputs:
;   Returns file path string if file exists; else returns
;   empty string
; Author and History:
;   Kyle R. Wodzicki
;-
COMPILE_OPT IDL2

IF (N_PARAMS()          EQ 0) THEN MESSAGE, 'Incorrect number of inputs'
IF (N_ELEMENTS(version) EQ 0) THEN version = 7																; Default to version 7
IF (N_ELEMENTS(extIn)   EQ 1) THEN $                                          ; If extension keyword used
  ext = (STRMID(extIn,0,1) EQ '.') ? extIn : '.' + extIn $                    ; Prepend a period (.) to the extension if it does not start with one
ELSE $                                                                        ; Else
  ext = '.HDF'                                                                ; Set default extension

ext     = STRING(version, ext, FORMAT="('.', I1, A)")                         ; Prepend the version number to extension

dataDir = TRMM_DATADIR(product, date, ROOT_DIR=root_dir)                      ; Get path to product

pattern = STRUPCASE(product)                                                  ; Set start of pattern for file search
IF N_ELEMENTS(date) EQ 1 THEN BEGIN                                           ; If date argument used
  JUL2GREG, date, mm, dd, yy                                                  ; Get year month day from date
  pattern = STRING(pattern, yy, mm, dd, FORMAT="(A, '.', I4, I02, I02)")      ; Update patter
ENDIF

files = FILE_SEARCH(dataDir, pattern + '*' + ext, COUNT=count)                ; Search for files using pattern*ext
IF count EQ 0 THEN BEGIN                                                      ; If no files found
  MESSAGE, 'No files found: ' + dataDir + ', ' + pattern, /CONTINUE           ; Warning message
  count      = 0                                                              ; Set count to zero (0)
  file_dates = []                                                             ; Set dates to empty array
  RETURN, []                                                                  ; Return emtpy array
ENDIF

udates = ( STRSPLIT(FILE_BASENAME(files), '.', /EXTRACT) ).ToArray(/No_Copy)  ; Split file base names on period (.)
udates = udates[*,1]                                                          ; Get dates out of string array
years  = LONG(STRMID(udates, 0, 4))                                           ; Extract years from dates
months = LONG(STRMID(udates, 4, 2))                                           ; Extract months from dates
days   = LONG(STRMID(udates, 6, 2))                                           ; Extract days from dates
udates = ULONG(udates)                                                        ; Get dates out of string array

uniqD      = udates[ UNIQ(udates) ]                                           ; Get indices of unique dates
file_dates = DBLARR( N_ELEMENTS(udates), /NoZero )                            ; Initialize array for storing JULDAYs
FOR i = 0, N_ELEMENTS(uniqD)-1 DO BEGIN                                       ; Iterate over all unique dates
  id             = WHERE(udates EQ uniqD[i], cnt)                             ; Indices of unique dates
  hours          = INDGEN(cnt) * 24 / FLOAT(cnt)                              ; Generate hours
  file_dates[id] = GREG2JUL(months[id], days[id], years[id], hours)           ; Create JULDAY datetimes and store in dates array
ENDFOR

IF N_ELEMENTS(swath) EQ 1 THEN BEGIN                                          ; If the swath argument was used
  file = STRING(pattern, swath, ext, FORMAT="(A, '.', I05, A)")               ; Set file name
  id   = WHERE(STRMATCH(files, '*' + file), cnt)                              ; Search for file in file list
  IF cnt EQ 1 THEN BEGIN                                                      ; If file in list
    count      = cnt                                                          ; Set count to cnt
    file_dates = file_dates[id]                                               ; Subset dates
    RETURN, files[id]                                                         ; Subset files and return
  ENDIF ELSE BEGIN                                                            ; Else, no file found
    MESSAGE, 'File NOT found: ' + FILEPATH(file, ROOT_DIR=dataDir), /CONTINUE ; Message
    count      = 0                                                            ; Set count to zero (0) 
    file_dates = []                                                           ; Set dates to empty array
    RETURN, []                                                                ; Return empty array
  ENDELSE
ENDIF
 
RETURN, files 																																; Return files 

END
