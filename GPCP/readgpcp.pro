FUNCTION GET_GPCP_HEADER, fileName, COMPRESS = compress
;+
; Name:
;   GET_GPCP_HEADER
; Purpose:
;   A function to get the header information from a GPCP data file.
; Calling Sequence:
;   result = GET_HEADER('file')
; Inputs:
;   fileName : Full path to GPCP file.
; Outputs:
;   Returns a structure containing the GPCP file header.
; Keywords:
;   COMPRESS : Is set if the file is gunzip compressed, i.e., .gz
; Author and History:
;   Kyle R. Wodzicki     Created 18 Nov. 2014
;
;     Modified 28 Jun. 2017 - Kyle R. Wodzicki
;       Added the compress keyword
;-
  COMPILE_OPT IDL2, HIDDEN                                            ;Set compile options

  header = BYTARR(144 * 4)                                            ;Array for reading in header
  OPENR, ilun, fileName, /GET_LUN, COMPRESS = compress                ;Open file for reading
    READU, ilun, header                                               ;Read in the header
  FREE_LUN, ilun                                                      ;Free lun and close file
  header = STRSPLIT(STRING(header), '=', /EXTRACT)                    ;Split on equals sign
  nHead  = N_ELEMENTS(header)                                         ;Number of elements after split
  
  out_data = {}                                                       ;Create out_data structure
  FOR i = 0, nHead - 2 DO BEGIN                                       ;Iterate over all elements
    name = STRSPLIT(header[i],   ' ', /EXTRACT) & name = name[-1]     ;Get name of header info
    IF (name EQ '1st_box_center') THEN name = 'first_box_center'      ;Remove numbers from beginning of tag name
    IF (name EQ '2nd_box_center') THEN name = 'second_box_center'
    
    info = STRSPLIT(header[i+1], ' ', /EXTRACT)                       ;Actual info is in next element
    info = (i NE nHead-2) ? STRJOIN(info[0:-2],' ') : STRJOIN(info,' ')
    
    out_data = CREATE_STRUCT(out_data, name, info)
  ENDFOR
  RETURN, out_data
END

FUNCTION GPCP_BYTE_SWAP, data, header, VERBOSE=verbose
;+
; Name:
;   GPCP_BYTE_SWAP
; Purpose:
;   A function to check for byte swapping and return a
;   corrected array
;-
COMPILE_OPT IDL2, HIDDEN
  ;=== Check for byte swapping.
  arch = strlowcase( !version.arch )
  arch_check = (arch eq 'x86')  OR (arch eq 'alpha') OR (arch eq 'i386') OR (arch eq 'x86_64') 
  file_check = STRMATCH(header.CREATION_MACHINE, '*Silicon*', /FOLD_CASE)
  system_byte_order = arch_check ? 'little_endian' : 'big_endian'
  file_byte_order   = file_check ? 'big_endian'    : 'little_endian'
;
; ----- If necessary, swap the bytes of the float variables.
;
	IF system_byte_order NE file_byte_order THEN BEGIN
 	  IF KEYWORD_SET(verbose) THEN PRINT, 'GPCP_BYTE_SWAP: warning: swapping bytes...'
	  RETURN, SWAP_ENDIAN( data )
	ENDIF ELSE $
    RETURN, data
END

FUNCTION READGPCP, in_year, in_month, $
  VERSION = version, $
  LIMIT   = limit, $
  DIR     = dir, $
  VERBOSE = verbose, $
  HEADER  = info, $
  NO_LAND = no_land
;+
; Name:
;   READGPCP
; Purpose:
;   A function to read in all monthly mean GPCP data files.
; Calling Sequence:
;   result = READGPCP()
; Inputs:
;   in_year  : Optional input for year of data to read in. If not set
;             all data in directory is read in. Setting year equal
;             to zero and senting month from 1-12 will read in a
;             given month from each year.
;   in_month : Optional input for month of data to read in. If not set
;             all data in directory is read in.
; Outputs:
;   Returns a data structure with all GPCP rain rates, longitudes,
;   latitudes, and dates. Rain rate data is arranged as:
;     [longitude, latitude, time].
; Keywords:
;   LIMIT   : Limits for the data, [south, west, north, east], with
;              longitudes from 0-360.
;   DIR     : Directory where data is located.
; Author and History:
;   Created by Anita D. Rapp
;
;     MODIFIED 18 Nov. 2014 by Kyle R. Wodzicki.
;       Added the GET_GPCP_HEADER function at beginning of code.
;       Changed from procedure to a function.
;       Added LIMIT and DIR keywords.
;       Changed to return a structure and determine dates based on
;       header information.
;     MODIFIED 19 Nov. 2014 by Kyle R. Wodzicki.
;       Added year and month inputs.
;     MODIFIED 17 Mar. 2015 by Kyle R. Wodzicki
;       Added byte swapping check
;     MODIFIED 17 Mar. 2015 by Kyle R. Wodzicki
;       Added support for .gz (gunzip compressed) files. File must end in .gz
;       for this to work correctly.
;       Updated default directory path as the files were moved
;       Changed from appending to array to adding to list
;-

COMPILE_OPT IDL2                                                      ;Set compile options

IF (N_ELEMENTS(version) EQ 0) THEN version = 'V2.3'	
IF (N_ELEMENTS(dir)     EQ 0) THEN dir = FILEPATH(version, ROOT_DIR=!GPCP_Data);Set default directory for data
  
nLat      =  72                                                          ;Number of latitude points
nLon      = 144                                                          ;Number of longitude points
dLat      =   2.5
dLon      =   2.5
latOffset = -88.75
lonOffset =   1.25

latbins   = REVERSE( FINDGEN(nLat) * dLat + latOffset )                       ; Latitude points for data
lonbins   =          FINDGEN(nLon) * dLon + lonOffset                         ; Longitude points for data

IF (N_ELEMENTS(limit) NE 0) THEN BEGIN                                ;If limits set, filter data based on domain
  lon_id = WHERE(lonbins GE limit[1] AND lonbins LE limit[3], lon_CNT)
  lat_id = WHERE(latbins GE limit[0] AND latbins LE limit[2], lat_CNT)
ENDIF ELSE BEGIN
  lon_CNT = 0 & lat_CNT = 0
ENDELSE

IF (lon_CNT NE 0 AND lat_cnt NE 0) THEN BEGIN                         ;If counts are not zero, filter longitude and latitude
  lonbins = lonbins[lon_id] & latbins = latbins[lat_id]
ENDIF

CASE version OF
  'V2.2' : pattern = 'gpcp_v2.2_psg.*'
  'V2.3' : pattern = 'gpcp_cdr_v23rB1*.nc'
  ELSE   : MESSAGE, 'Unsupported version'
ENDCASE

files = FILE_SEARCH(dir, pattern)                           ;Find all data files in directory
IF (N_ELEMENTS(in_year) NE 0 AND in_year NE 0) THEN BEGIN
  id = WHERE(STRMATCH(files,'*'+STRTRIM(in_year,2)+'*',/FOLD_CASE),CNT)
  IF (CNT GE 1) THEN files = files[id] ELSE BEGIN 
    MESSAGE, 'File NOT found! Skipping...', /CONTINUE
    RETURN, -1
  ENDELSE
ENDIF
nFiles = N_ELEMENTS(files)                                            ;Get number of files

gpcp_data = LIST()                                                    ;Initialize array to store all gpcp data
all_dates = []                                                        ;Initialize array to store dates

FOR i = 0, nfiles - 1 DO BEGIN                                        ;Iterate over all files
  compress= STRMATCH(files[i], '*.gz')
  info    = GET_GPCP_HEADER(files[i], COMPRESS=compress)               ;Get header info
  m_range = LONG(STRSPLIT(info.MONTHS, '-', /EXTRACT))                ;Get range of months from info structure
  nMonths = m_range[-1] - m_range[0] + 1                              ;Determine number of months from range
  year    = REPLICATE(LONG(info.YEAR), nMonths)                       ;Create year array based on year and number of months
  months  = m_range[0] + INDGEN(nMonths)                              ;Create month array based on month range
  
  date    = JULDAY(months, 1, year)                                   ;Create julian date from info
  gpcp    = FLTARR(nlon, nlat, nMonths)                               ;Initialize an array to read gpcp data from given year/month into
  
  IF (N_ELEMENTS(in_month) NE 0) THEN BEGIN
    month_id = WHERE(months EQ in_month, m_CNT)
    IF (m_CNT EQ 1) THEN all_dates = [all_dates, date[month_id]] $ 
    ELSE BEGIN
      all_dates = [all_dates, date]
      PRINT, 'Month requested not in file, returning all data!'
    ENDELSE
  ENDIF ELSE BEGIN
    m_CNT = 0
    all_dates = date
  ENDELSE
  
  OPENR, ilun, files[i], /GET_LUN, COMPRESS = compress                ;Open file for reading
    header = BYTARR(144 * 4, /NoZero)                                 ;Array for reading in header
    READU, ilun, header, gpcp                                         ;Read past header and read in data
  FREE_LUN, ilun                                                      ;Close the file
    
  IF (lon_CNT NE 0 AND lat_cnt NE 0) THEN gpcp = gpcp[lon_id,lat_id,*];Filter data based on domain
  IF (m_CNT   NE 0) THEN gpcp = gpcp[*,*,month_id]

  gpcp = GPCP_BYTE_SWAP(gpcp, info, VERBOSE=verbose)                  ; Swap bytes if necessary.
  
  id = WHERE(gpcp EQ FLOAT(info.MISSING_VALUE), CNT)                  ;Replace missing data with NaN characters
  IF (CNT NE 0) THEN gpcp[id] = !VALUES.F_NaN

  gpcp_data.ADD, gpcp                                                 ; Add the gpcp data to the list
ENDFOR

gpcp_data = gpcp_data.ToArray(/No_Copy, /TRANSPOSE)                   ; Convert the list to an array

IF KEYWORD_SET(no_land) THEN BEGIN
  mask = LAND_OCEAN_READ_KPB('land_ocean_masks','land_ocean_mask2','qd')
  mask_lon = mask.X.VALUES & mask_lat = REVERSE(mask.Y.VALUES)
  mask = REVERSE(mask.VALUES, 2)
  x_int = INTERPOL(FINDGEN(1440), mask_lon, lonbins)
  y_int = INTERPOL(FINDGEN(720),  mask_lat, latbins)
  mask  = REBIN(ROUND(INTERPOLATE(mask, x_int, y_int, /GRID)), SIZE(gpcp_data, /DIMENSIONS))
  id = WHERE(mask EQ 1, mask_CNT)
  IF (mask_CNT NE 0) THEN BEGIN
    WHERETOMULTI, mask, id, col, row, frame
    IF (N_ELEMENTS(frame) EQ 0) THEN BEGIN
      gpcp_data[col, row] = !VALUES.F_NaN
    ENDIF ELSE BEGIN
      gpcp_data[col, row, frame] = !VALUES.F_NaN
    ENDELSE
  ENDIF
ENDIF

CALDAT, all_dates, month, day, year                                   ;Convert julian day back to year and month

RETURN, {RAIN  : gpcp_data, $                                         ;Return data
         LON   : lonbins,   $
         LAT   : latbins,   $
         YEAR  : year,      $
         MONTH : month}

END
