FUNCTION NCDF_FILLVAL, data, TYPE = type
;+
; Return the default netCDF fill value based on type of data
; Keywords:
;   TYPE : If set, assumes the data input contains the IDL type string
COMPILE_OPT IDL2

type = KEYWORD_SET(type) ? STRUPCASE(data) : data.TYPENAME

CASE type OF
  'BYTE'   : RETURN, 0B
  'CHAR'   : RETURN, 0B
  'INT'    : RETURN, -32767S
  'LONG'   : RETURN, -2147483647
  'FLOAT'  : RETURN, 9.96921E+36
  'DOUBLE' : RETURN, 9.96921E+36
  ELSE     : BEGIN
               MESSAGE, 'Unsupported type!', /CONTINUE
               RETURN, !NULL
             END
ENDCASE

END
