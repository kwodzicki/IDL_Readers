PRO BYTE_SWAP_1DD, data, header, VERBOSE = verbose
;+
; Name:
;   BYTE_SWAP_1DD
; Purpose:
;   A procedure to swap bytes if needed in GPCP 1 degree daily data.
; Calling Sequence:
;   BYTE_SWAP_1DD, data, header
; Inputs:
;   data   : 3D array of data, [longitude, latitude, days].
;   header : Header information from the data file. Must be a
;            structure, created by the READ_1DD_HEADER function.
; Outputs:
;   None.
; Keywords:
;   VEROBSE : Increase verbosity, i.e., print that bytes are being
;             swapped.
; Author and History:
;   Kyle R. Wodzicki     Created 14 May 2015
;      NOTE: Adapted from original READ_1DD procedure  
;-
  COMPILE_OPT IDL2, HIDDEN                                            ; Set compile options
  arch = STRLOWCASE( !version.arch )                                  ; Get system architecture type 
  
  arch_test = (arch EQ 'x86')  OR (arch EQ 'alpha') OR $              ; Check if architecture matches any of these
              (arch EQ 'i386') OR (arch EQ 'x86_64')
  system_order = (arch_test EQ 1) ? 'little_endian' : 'big_endian'    ; Set system byte order
  file_order   = STRMATCH( header.CREATION_MACHINE, '*Silicon*') ? $  ; Set file byte order
                'big_endian' : 'little_endian'
;
; ----- If necessary, swap the bytes of the float variables.
;
	IF (system_order NE file_order) THEN BEGIN
	  IF KEYWORD_SET(verbose) THEN $
	    PRINT, 'byte_swap_1DD: warning: swapping bytes...'
	  data = SWAP_ENDIAN( data )
	ENDIF

END

FUNCTION READ_1DD_HEADER, file
;+
; Name:
;   READ_1DD_HEADER
; Purpose:
;   A function to get the header information from a GPCP 1DD data file.
; Calling Sequence:
;   result = READ_1DD_HEADER('file')
; Inputs:
;   fileName : Full path to GPCP file.
; Outputs:
;   Returns a structure containing the GPCP file header.
; Keywords:
;   None.
; Author and History:
;   Kyle R. Wodzicki     Created 13 May 2015
;-
  COMPILE_OPT IDL2, HIDDEN                                            ;Set compile options

  header = BYTARR(360 * 4)                                            ;Array for reading in header
  OPENR, ilun, file, /GET_LUN                                     ;Open file for reading
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

FUNCTION READ_1DD, file, LIMIT = limit, VERBOSE = verbose, HEADER=header
;+
; Name:
;   BYTE_SWAP_1DD
; Purpose:
;   A function to read in GPCP 1 degree daily data.
; Calling Sequence:
;   READ_1DD, data, header
; Inputs:
;   file   : Name, including path, of file to read in.
; Outputs:
;   None.
; Keywords:
;   LIMIT   : Set to return subset of data.
;             [min lat, min lon, max lat, max lon]
;   VEROBSE : Increase verbosity, i.e., print that bytes are being
;             swapped.
; Author and History:
;   Kyle R. Wodzicki     Created 14 May 2015
;      NOTE: Adapted from original READ_1DD procedure  
;-
  COMPILE_OPT IDL2                                                    ; Set compile Options

	header = READ_1DD_HEADER(file)                                      ; Read in the file header information
	nDays  = LONG((STRSPLIT(header.DAYS, '-', /EXTRACT))[-1])           ; Get the total number of days in the file
	data   = FLTARR(360, 180, nDays)                                    ; Create array for data
	tmp    = BYTARR(360 * 4)                                            ; Create dummy array for header
	OPENR, ilun, file, /GET_LUN                                         ; Open file for reading
  READU, ilun, tmp, data                                              ; Read in the header
  FREE_LUN, ilun                                                      ; Close the file

  ;; swap bytes on little endian systems
	BYTE_SWAP_1DD, data, header, VERBOSE = verbose
  
  id = WHERE(data EQ FLOAT(header.MISSING_VALUE), CNT)                ; Find indices of missing data
  IF (CNT NE 0) THEN data[id] = !VALUES.F_NaN                         ; If there is missing data, replace with NaN
  
  lon =      INDGEN(360) +  0.5                                       ; Generater longitude values
  lat = -1 * INDGEN(180) + 89.5                                       ; Generater latitude  values
  
  IF (N_ELEMENTS(limit) NE 0) THEN BEGIN                              ; If limit set, filter data
    id = WHERE(lon GE limit[1] AND lon LE limit[3], CNT)
    IF (CNT NE 0) THEN BEGIN
      data = data[id, *, *]
      lon  = lon[id]
    ENDIF
    id = WHERE(lat GE limit[0] AND lat LE limit[2], CNT)
      IF (CNT NE 0) THEN BEGIN
      data = data[*, id, *]
      lat  = lat[id]
    ENDIF
  ENDIF
  
  RETURN, {HEADER  : header, $
           RR      : data,   $
           LON     : lon, $
           LAT     : lat}
	END