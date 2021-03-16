FUNCTION TRMM_FILEINFO, paths
;+
; Name:
;   TRMM_FILEINFO
; Purpose:
;   Function to parse information from TRMM file names.
;   Info includes product, date, swath number
; Inputs:
;   paths (string) : Scalar or string array of file paths to parse info for
; Keywords:
;   None.
; Returns:
;   Array of structures
;-

COMPILE_OPT IDL2

info = {TRMM_FILEINFO, PRODUCT : '', JULDAY : 0.0D0, SWATH : 0UL}
info = REPLICATE(info, N_ELEMENTS(paths))

tmp  = ( STRSPLIT( FILE_BASENAME(paths), '.', /EXTRACT ) ).ToArray()
info.PRODUCT = tmp[*,0]
info.JULDAY  = GREG2JUL(LONG(STRMID(tmp[1],4,2)), LONG(STRMID(tmp[1],6,2)), LONG(STRMID(tmp[1],0,4)) )
info.SWATH   = ULONG(tmp[*,2])

RETURN, info

END
